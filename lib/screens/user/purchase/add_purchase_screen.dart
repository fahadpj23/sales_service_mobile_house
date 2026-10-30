import 'dart:math' show min;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sales_stock/providers/auth_provider.dart';
import '../../../models/purchase.dart';
import 'add_product_screen.dart';
import 'add_supplier_screen.dart';

class AddPurchaseScreen extends StatefulWidget {
  final Function(int)? onNavigateToHistory;

  const AddPurchaseScreen({super.key, this.onNavigateToHistory});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  // ============================================================
  // STOCK CONFIG
  // applianceStock matches AppliancesStockScreen exactly.
  // phoneStock / tvStock are ASSUMED (their save code wasn't available) —
  // change the names / fields in _collectStockOps if yours differ.
  // ============================================================
  static const String _applianceStockCollection = 'applianceStock';
  static const String _phoneStockCollection = 'phoneStock'; // ASSUMED
  static const String _tvStockCollection = 'tvStock'; // ASSUMED
  static const String _applianceCategory = 'Appliances';
  static const String _phoneCategory = 'Phone'; // ASSUMED
  static const String _tvCategory = 'TV'; // ASSUMED
  static const int _maxBatchOps = 480; // Firestore batch limit is 500

  DateTime _selectedDate = DateTime.now();
  String? _selectedSupplierId;
  String? _selectedSupplierName;

  // Purchase Invoice Number
  final TextEditingController _invoiceController = TextEditingController();

  // Cart items
  List<CartItem> _cartItems = [];

  // Single product selection
  String? _selectedProductId;
  String? _selectedProductName;
  String? _selectedProductType;
  String? _selectedProductBrand;
  final TextEditingController _purchaseRateController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  // IMEI / Serial number entry for the selected product
  final TextEditingController _identifierController = TextEditingController();
  final FocusNode _identifierFocusNode = FocusNode();
  List<String> _currentIdentifiers = [];

  // Stock update options

  // Stock always goes to the shop of the logged-in user (no shop picker)
  String? get _stockShopId {
    final id = Provider.of<AuthProvider>(context, listen: false).user?.shopId;
    return (id != null && id.isNotEmpty) ? id : null;
  }

  String get _stockShopName {
    final name = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).user?.shopName;
    return (name != null && name.isNotEmpty) ? name : 'Unknown Shop';
  }

  // Purchase bill image
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  Uint8List? _billBytes;
  String? _billFileName;
  bool _isUploading = false;
  double _uploadProgress = 0;
  static const int _maxBillSizeBytes = 10 * 1024 * 1024; // 10 MB

  // Discount fields
  bool _usePercentageDiscount = true;
  final TextEditingController _discountController = TextEditingController();
  double _discountValue = 0;

  // Search controllers for datalist
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _productController = TextEditingController();

  // Rounding amount
  double _roundingAmount = 0;
  bool _isRoundingManual = false;
  final TextEditingController _roundingController = TextEditingController();

  bool _isLoading = false;
  double _productRate = 0;
  double _productSaleRate = 0;
  int _productGst = 18;

  List<QueryDocumentSnapshot> _suppliers = [];
  List<QueryDocumentSnapshot> _products = [];
  List<QueryDocumentSnapshot> _filteredSuppliers = [];
  List<QueryDocumentSnapshot> _filteredProducts = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Focus nodes
  final FocusNode _supplierFocusNode = FocusNode();
  final FocusNode _productFocusNode = FocusNode();

  // ====== Keyboard navigation state ======
  final FocusNode _supplierKeyFocus = FocusNode();
  final FocusNode _productKeyFocus = FocusNode();
  int _supplierHighlightIndex = -1;
  int _productHighlightIndex = -1;

  // Scroll controllers for auto-scrolling to highlighted item
  final ScrollController _supplierScrollController = ScrollController();
  final ScrollController _productScrollController = ScrollController();

  bool _showSupplierSuggestions = false;
  bool _showProductSuggestions = false;

  // ============================================================
  // PRODUCT TYPE HELPERS
  // ============================================================

  /// Decides which stock collection a product type belongs to.
  StockKind _stockKindFor(String productType) {
    final t = productType.toLowerCase();
    if (t.contains('phone') || t.contains('mobile')) return StockKind.phone;
    if (RegExp(r'\btv\b|television').hasMatch(t)) return StockKind.tv;
    if (t.contains('appliance')) return StockKind.appliance;
    return StockKind.none;
  }

  /// Phones use IMEI, everything else uses a serial number.
  bool get _isPhoneProduct =>
      _stockKindFor(_selectedProductType ?? '') == StockKind.phone;

  String get _identifierLabel => _isPhoneProduct ? 'IMEI' : 'Serial Number';
  String get _identifierTypeKey => _isPhoneProduct ? 'IMEI' : 'Serial';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _loadProducts();

    _supplierController.addListener(_filterSuppliers);
    _productController.addListener(_filterProducts);
    _discountController.addListener(_onDiscountChanged);

    _supplierFocusNode.addListener(() {
      if (_supplierFocusNode.hasFocus && _selectedSupplierId == null) {
        setState(() {
          if (_supplierController.text.isEmpty) {
            _filteredSuppliers = _suppliers.take(4).toList();
          } else {
            _filterSuppliers();
          }
          _showSupplierSuggestions = true;
          _supplierHighlightIndex = -1;
        });
      } else if (!_supplierFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_supplierFocusNode.hasFocus) {
            setState(() {
              _showSupplierSuggestions = false;
              _supplierHighlightIndex = -1;
            });
          }
        });
      }
    });

    _productFocusNode.addListener(() {
      if (_productFocusNode.hasFocus && _selectedProductId == null) {
        setState(() {
          if (_productController.text.isNotEmpty) {
            _showProductSuggestions = true;
            _filterProducts();
            _productHighlightIndex = -1;
          }
        });
      } else if (!_productFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_productFocusNode.hasFocus) {
            setState(() {
              _showProductSuggestions = false;
              _productHighlightIndex = -1;
            });
          }
        });
      }
    });

    _roundingController.addListener(_onRoundingChanged);
  }

  // ============================================================
  // KEYBOARD HANDLERS
  // ============================================================

  /// Handles arrow / enter / escape keys for supplier dropdown
  KeyEventResult _handleSupplierKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (!_showSupplierSuggestions) return KeyEventResult.ignored;

    // Total items = suppliers + 1 (Add New Supplier row)
    final int totalItems = _filteredSuppliers.length + 1;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() {
          if (_supplierHighlightIndex < totalItems - 1) {
            _supplierHighlightIndex++;
          } else {
            _supplierHighlightIndex = 0;
          }
        });
        _autoScrollSupplier();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
        setState(() {
          if (_supplierHighlightIndex > 0) {
            _supplierHighlightIndex--;
          } else {
            _supplierHighlightIndex = totalItems - 1;
          }
        });
        _autoScrollSupplier();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.tab:
        if (_supplierHighlightIndex < 0) {
          // No highlight — pick the first one
          if (_filteredSuppliers.isNotEmpty) {
            _selectSupplier(_filteredSuppliers.first);
            return KeyEventResult.handled;
          }
        } else if (_supplierHighlightIndex < _filteredSuppliers.length) {
          // Select highlighted supplier
          _selectSupplier(_filteredSuppliers[_supplierHighlightIndex]);
          return KeyEventResult.handled;
        } else {
          // "Add New Supplier" was highlighted
          _showAddSupplierDialog();
          return KeyEventResult.handled;
        }
        break;

      case LogicalKeyboardKey.escape:
        setState(() {
          _showSupplierSuggestions = false;
          _supplierHighlightIndex = -1;
        });
        _supplierFocusNode.unfocus();
        return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Handles arrow / enter / escape keys for product dropdown
  KeyEventResult _handleProductKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (!_showProductSuggestions) return KeyEventResult.ignored;

    // Total items = products + 1 (Add New Product row)
    final int totalItems = _filteredProducts.length + 1;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() {
          if (_productHighlightIndex < totalItems - 1) {
            _productHighlightIndex++;
          } else {
            _productHighlightIndex = 0;
          }
        });
        _autoScrollProduct();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
        setState(() {
          if (_productHighlightIndex > 0) {
            _productHighlightIndex--;
          } else {
            _productHighlightIndex = totalItems - 1;
          }
        });
        _autoScrollProduct();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.tab:
        if (_productHighlightIndex < 0) {
          if (_filteredProducts.isNotEmpty) {
            _selectProduct(_filteredProducts.first);
            return KeyEventResult.handled;
          }
        } else if (_productHighlightIndex < _filteredProducts.length) {
          _selectProduct(_filteredProducts[_productHighlightIndex]);
          return KeyEventResult.handled;
        } else {
          // "Add New Product" was highlighted
          _showAddProductDialog();
          return KeyEventResult.handled;
        }
        break;

      case LogicalKeyboardKey.escape:
        setState(() {
          _showProductSuggestions = false;
          _productHighlightIndex = -1;
        });
        _productFocusNode.unfocus();
        return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Auto-scroll supplier list to keep highlighted item visible
  void _autoScrollSupplier() {
    if (!_supplierScrollController.hasClients) return;
    if (_supplierHighlightIndex < 0) return;

    const double itemHeight = 60.0;
    final double targetOffset = _supplierHighlightIndex * itemHeight - 100;

    _supplierScrollController.animateTo(
      targetOffset.clamp(
        0.0,
        _supplierScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  /// Auto-scroll product list to keep highlighted item visible
  void _autoScrollProduct() {
    if (!_productScrollController.hasClients) return;
    if (_productHighlightIndex < 0) return;

    const double itemHeight = 60.0;
    final double targetOffset = _productHighlightIndex * itemHeight - 100;

    _productScrollController.animateTo(
      targetOffset.clamp(
        0.0,
        _productScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _onDiscountChanged() {
    if (_discountController.text.isNotEmpty) {
      double? value = double.tryParse(_discountController.text);
      if (value != null && value >= 0) {
        setState(() => _discountValue = value);
      }
    } else {
      setState(() => _discountValue = 0);
    }
  }

  void _onRoundingChanged() {
    if (_isRoundingManual && _roundingController.text.isNotEmpty) {
      double? value = double.tryParse(_roundingController.text);
      if (value != null) {
        setState(() => _roundingAmount = value);
      }
    }
  }

  void _showDialog(String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.red : Colors.green,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.green[700]),
              child: const Text('OK', style: TextStyle(fontSize: 13)),
            ),
          ],
        );
      },
    );
  }

  // ==================== ADD SUPPLIER ====================
  Future<void> _showAddSupplierDialog() async {
    if (mounted) {
      setState(() {
        _showSupplierSuggestions = false;
        _supplierHighlightIndex = -1;
      });
    }

    _supplierFocusNode.unfocus();
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 500,
            height: MediaQuery.of(dialogContext).size.height * 0.85,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_business, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Add New Supplier',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AddSupplierScreen(
                    onNavigateToSupplierList: (index) {
                      Navigator.of(dialogContext).pop(true);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    await _loadSuppliers();
    if (result == true) await _selectSupplierAfterAdd();
  }

  Future<void> _selectSupplierAfterAdd() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('suppliers')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        _selectSupplier(snapshot.docs.first);
        _showDialog('Success', 'Supplier added and selected automatically!');
      }
    } catch (_) {}
  }

  // ==================== ADD PRODUCT ====================
  Future<void> _showAddProductDialog() async {
    if (mounted) {
      setState(() {
        _showProductSuggestions = false;
        _productHighlightIndex = -1;
      });
    }

    _productFocusNode.unfocus();
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 900,
            height: MediaQuery.of(dialogContext).size.height * 0.88,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_business, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Add New Product',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AddProductScreen(
                    onNavigateToProductList: (index) {
                      Navigator.of(dialogContext).pop(true);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    await _loadProducts();
    if (result == true) await _selectProductAfterAdd();
  }

  Future<void> _selectProductAfterAdd() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        _selectProduct(snapshot.docs.first);
        _showDialog('Success', 'Product added and selected automatically!');
      }
    } catch (_) {}
  }

  void _showExistingInvoiceDialog({
    required String invoiceNo,
    required String supplierName,
    DateTime? date,
    required int itemCount,
    required double grandTotal,
    required String purchaseId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[700],
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Duplicate Invoice Found!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invoice #$invoiceNo already exists.',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Invoice Number:', invoiceNo),
                    _buildDetailRow('Supplier:', supplierName),
                    _buildDetailRow(
                      'Date:',
                      date != null
                          ? DateFormat('dd/MM/yyyy').format(date)
                          : 'N/A',
                    ),
                    _buildDetailRow('Items:', itemCount.toString()),
                    _buildDetailRow(
                      'Grand Total:',
                      '₹${grandTotal.toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Change Invoice Number'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToExistingPurchase(purchaseId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('View Existing'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green[700] : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToExistingPurchase(String purchaseId) {
    Navigator.pop(context, {
      'navigateTo': 'purchaseDetails',
      'purchaseId': purchaseId,
    });
  }

  Future<void> _loadSuppliers() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('suppliers').get();
      setState(() {
        _suppliers = snapshot.docs;
        _filteredSuppliers = snapshot.docs;
      });
    } catch (e) {
      _showDialog('Error', 'Error loading suppliers: $e', isError: true);
    }
  }

  Future<void> _loadProducts() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('products').get();
      setState(() {
        _products = snapshot.docs;
        _filteredProducts = snapshot.docs;
      });
    } catch (e) {
      _showDialog('Error', 'Error loading products: $e', isError: true);
    }
  }

  void _filterSuppliers() {
    if (_selectedSupplierId != null) return;

    String query = _supplierController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredSuppliers = _suppliers.take(4).toList();
        _showSupplierSuggestions =
            _supplierFocusNode.hasFocus && _suppliers.isNotEmpty;
      } else {
        _filteredSuppliers = _suppliers.where((supplier) {
          Map<String, dynamic> data = supplier.data() as Map<String, dynamic>;
          String name = (data['supplierName'] ?? '').toString().toLowerCase();
          String phone = (data['phoneNumber'] ?? '').toString().toLowerCase();
          String email = (data['email'] ?? '').toString().toLowerCase();
          return name.contains(query) ||
              phone.contains(query) ||
              email.contains(query);
        }).toList();
        _showSupplierSuggestions = _supplierFocusNode.hasFocus;
      }
      // Reset highlight when search changes
      _supplierHighlightIndex = -1;
    });
  }

  void _filterProducts() {
    if (_selectedProductId != null) return;

    String query = _productController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _products;
        _showProductSuggestions = false;
      } else {
        _filteredProducts = _products.where((product) {
          Map<String, dynamic> data = product.data() as Map<String, dynamic>;
          String name = (data['productName'] ?? '').toString().toLowerCase();
          String category = (data['category'] ?? '').toString().toLowerCase();
          String brand = (data['brand'] ?? '').toString().toLowerCase();
          return name.contains(query) ||
              category.contains(query) ||
              brand.contains(query);
        }).toList();
        _showProductSuggestions = true;
      }
      // Reset highlight when search changes
      _productHighlightIndex = -1;
    });
  }

  void _selectSupplier(QueryDocumentSnapshot supplier) {
    Map<String, dynamic> data = supplier.data() as Map<String, dynamic>;
    setState(() {
      _selectedSupplierId = supplier.id;
      _selectedSupplierName = (data['supplierName'] ?? 'Unknown').toString();
      _supplierController.text = _selectedSupplierName!;
      _showSupplierSuggestions = false;
      _supplierHighlightIndex = -1;
      _filteredSuppliers = _suppliers;
    });
    _supplierFocusNode.unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${_selectedSupplierName!}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _selectProduct(QueryDocumentSnapshot product) {
    Map<String, dynamic> data = product.data() as Map<String, dynamic>;
    setState(() {
      _selectedProductId = product.id;
      _selectedProductName = (data['productName'] ?? 'Unknown').toString();
      _selectedProductType = (data['productType'] ?? data['category'] ?? '')
          .toString();
      _selectedProductBrand = (data['brand'] ?? '').toString();
      _productController.text = _selectedProductName!;
      _productRate = (data['purchaseRate'] ?? 0).toDouble();
      _productSaleRate = (data['saleRate'] ?? 0).toDouble();
      _productGst = (data['gstPercentage'] ?? 18).toInt();
      _purchaseRateController.text = _productRate.toString();
      _quantityController.text = '1';
      _discountController.clear();
      _discountValue = 0;
      _currentIdentifiers = [];
      _identifierController.clear();
      _showProductSuggestions = false;
      _productHighlightIndex = -1;
      _filteredProducts = _products;
    });
    _productFocusNode.unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${_selectedProductName!}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _clearSupplierSelection() {
    setState(() {
      _selectedSupplierId = null;
      _selectedSupplierName = null;
      _supplierController.clear();
      _showSupplierSuggestions = false;
      _supplierHighlightIndex = -1;
      _filteredSuppliers = _suppliers;
    });
    _supplierFocusNode.requestFocus();
  }

  void _clearProductSelection() {
    setState(() {
      _selectedProductId = null;
      _selectedProductName = null;
      _selectedProductType = null;
      _selectedProductBrand = null;
      _productController.clear();
      _purchaseRateController.clear();
      _quantityController.clear();
      _discountController.clear();
      _discountValue = 0;
      _currentIdentifiers = [];
      _identifierController.clear();
      _showProductSuggestions = false;
      _productHighlightIndex = -1;
      _filterProducts();
    });
    _productFocusNode.requestFocus();
  }

  // ============================================================
  // IMEI / SERIAL NUMBER HANDLING
  // ============================================================

  /// All identifiers already used in the cart or in the current entry list
  /// (lower-cased, used for duplicate checks).
  Set<String> _allUsedIdentifiers() {
    final used = <String>{};
    for (final item in _cartItems) {
      used.addAll(item.identifiers.map((e) => e.toLowerCase()));
    }
    used.addAll(_currentIdentifiers.map((e) => e.toLowerCase()));
    return used;
  }

  /// Parses the text field (comma / space separated, so a pasted list works),
  /// validates every value and adds the valid ones.
  /// Returns true when every value was accepted.
  bool _addIdentifiersFromInput() {
    final raw = _identifierController.text.trim();
    if (raw.isEmpty) return true;

    final parts = raw
        .split(RegExp(r'[,;\s]+'))
        .where((s) => s.isNotEmpty)
        .toList();

    final qty = int.tryParse(_quantityController.text.trim()) ?? 0;
    final used = _allUsedIdentifiers();
    final accepted = <String>[];
    final errors = <String>[];

    for (final value in parts) {
      if (qty > 0 && _currentIdentifiers.length + accepted.length >= qty) {
        errors.add('Quantity is $qty — remove one or increase quantity');
        break;
      }
      if (_isPhoneProduct && !RegExp(r'^\d{15}$').hasMatch(value)) {
        errors.add('"$value" is not a valid 15-digit IMEI');
        continue;
      }
      if (used.contains(value.toLowerCase())) {
        errors.add('"$value" is already added');
        continue;
      }
      used.add(value.toLowerCase());
      accepted.add(value);
    }

    setState(() {
      _currentIdentifiers.addAll(accepted);
      _identifierController.clear();
    });

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.join('\n')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
    return true;
  }

  void _removeIdentifier(String value) {
    setState(() => _currentIdentifiers.remove(value));
  }

  // ============================================================
  // PURCHASE BILL (camera / files -> Firebase Storage)
  // ============================================================

  bool get _cameraSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  void _showBillSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              if (_cameraSupported)
                ListTile(
                  leading: Icon(Icons.photo_camera, color: Colors.green[700]),
                  title: const Text('Take photo with camera'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickBillFromCamera();
                  },
                ),
              ListTile(
                leading: Icon(Icons.folder_open, color: Colors.green[700]),
                title: const Text('Choose from files / gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickBillFromFiles();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickBillFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 2000,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      _setBill(
        bytes,
        photo.name.isNotEmpty
            ? photo.name
            : 'bill_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    } catch (e) {
      _showDialog('Error', 'Could not open camera: $e', isError: true);
    }
  }

  Future<void> _pickBillFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _showDialog('Error', 'Could not read the selected file', isError: true);
        return;
      }
      _setBill(bytes, file.name);
    } catch (e) {
      _showDialog('Error', 'Could not pick file: $e', isError: true);
    }
  }

  void _setBill(Uint8List bytes, String fileName) {
    if (bytes.length > _maxBillSizeBytes) {
      _showDialog(
        'File too large',
        'Bill image must be smaller than 10 MB.',
        isError: true,
      );
      return;
    }
    setState(() {
      _billBytes = bytes;
      _billFileName = fileName;
    });
  }

  void _removeBill() {
    setState(() {
      _billBytes = null;
      _billFileName = null;
    });
  }

  String get _billExtension {
    final name = (_billFileName ?? '').toLowerCase();
    if (name.contains('.')) {
      final ext = name.split('.').last;
      if (ext.isNotEmpty && ext.length <= 5) return ext;
    }
    return 'jpg';
  }

  String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  void _previewBill() {
    if (_billBytes == null) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  child: Image.memory(_billBytes!, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.white70),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Uploads the selected bill and returns its download URL and storage path.
  Future<Map<String, String>> _uploadBill(String invoiceNo) async {
    final ext = _billExtension;
    final safeInvoice = invoiceNo.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final path =
        'purchase_bills/${safeInvoice}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    final ref = _storage.ref().child(path);
    final task = ref.putData(
      _billBytes!,
      SettableMetadata(contentType: _contentTypeFor(ext)),
    );

    final sub = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0 && mounted) {
        setState(
          () =>
              _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes,
        );
      }
    });

    try {
      await task;
    } finally {
      await sub.cancel();
    }

    final url = await ref.getDownloadURL();
    return {'url': url, 'path': path};
  }

  // ============================================================
  // CART
  // ============================================================

  void _addToCartWithDiscount() {
    if (_selectedProductId == null) {
      _showDialog('Error', 'Please select a product', isError: true);
      return;
    }
    if (_quantityController.text.trim().isEmpty) {
      _showDialog('Error', 'Please enter quantity', isError: true);
      return;
    }
    int quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      _showDialog('Error', 'Please enter valid quantity', isError: true);
      return;
    }
    double rate = double.tryParse(_purchaseRateController.text.trim()) ?? 0;
    if (rate <= 0) {
      _showDialog('Error', 'Please enter valid purchase rate', isError: true);
      return;
    }

    // If something is typed in the IMEI/serial box but not yet added, add it now.
    if (!_addIdentifiersFromInput()) return;

    final List<String> identifiers = List<String>.from(_currentIdentifiers);
    if (identifiers.isNotEmpty && identifiers.length != quantity) {
      _showDialog(
        'Error',
        'Quantity is $quantity but ${identifiers.length} '
            '$_identifierLabel${identifiers.length == 1 ? '' : 's'} entered. '
            'Enter exactly $quantity, or remove them all to skip.',
        isError: true,
      );
      return;
    }

    // Phones can only go into stock with an IMEI for every unit
    if (_isPhoneProduct && identifiers.length != quantity) {
      _showDialog(
        'IMEI required',
        'Enter an IMEI for each of the $quantity phone(s). '
            'Phones are added to stock automatically.',
        isError: true,
      );
      return;
    }

    double discountAmount = 0;
    if (_discountValue > 0) {
      discountAmount = _usePercentageDiscount
          ? rate * (_discountValue / 100)
          : _discountValue;
    }

    double finalRate = rate - discountAmount;
    if (finalRate < 0) {
      _showDialog(
        'Error',
        'Discount cannot exceed the purchase rate',
        isError: true,
      );
      return;
    }

    int existingIndex = _cartItems.indexWhere(
      (item) => item.productId == _selectedProductId,
    );

    if (existingIndex != -1) {
      final existing = _cartItems[existingIndex];
      if (existing.identifiers.isNotEmpty != identifiers.isNotEmpty) {
        _showDialog(
          'Error',
          existing.identifiers.isNotEmpty
              ? 'This product is already in the cart with $_identifierLabel numbers. '
                    'Enter them for the new units too.'
              : 'This product is already in the cart without $_identifierLabel numbers. '
                    'Remove it from the cart first, or add these units without them.',
          isError: true,
        );
        return;
      }
      setState(() {
        existing.quantity += quantity;
        existing.rate = finalRate;
        existing.discount = discountAmount;
        existing.discountType = _usePercentageDiscount
            ? 'percentage'
            : 'amount';
        existing.total = finalRate * existing.quantity;
        existing.originalRate = rate;
        existing.identifiers.addAll(identifiers);
      });
    } else {
      setState(() {
        _cartItems.add(
          CartItem(
            productId: _selectedProductId!,
            productName: _selectedProductName!,
            rate: finalRate,
            quantity: quantity,
            total: finalRate * quantity,
            gstPercentage: _productGst,
            discount: discountAmount,
            discountType: _usePercentageDiscount ? 'percentage' : 'amount',
            originalRate: rate,
            productType: _selectedProductType ?? '',
            brand: _selectedProductBrand ?? '',
            saleRate: _productSaleRate,
            identifiers: identifiers,
            identifierType: _identifierTypeKey,
          ),
        );
      });
    }

    setState(() {
      _selectedProductId = null;
      _selectedProductName = null;
      _selectedProductType = null;
      _selectedProductBrand = null;
      _purchaseRateController.clear();
      _quantityController.clear();
      _discountController.clear();
      _discountValue = 0;
      _productRate = 0;
      _productSaleRate = 0;
      _productGst = 18;
      _currentIdentifiers = [];
      _identifierController.clear();
      _productController.clear();
      _showProductSuggestions = false;
      _filteredProducts = _products;
    });

    _resetRounding();
  }

  void _removeFromCart(int index) {
    setState(() => _cartItems.removeAt(index));
    _resetRounding();
  }

  void _updateCartItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeFromCart(index);
      return;
    }
    setState(() {
      _cartItems[index].quantity = newQuantity;
      _cartItems[index].total = _cartItems[index].rate * newQuantity;
    });
    _resetRounding();
  }

  double _getSubtotal() => _cartItems.fold(0, (sum, item) => sum + item.total);

  double _getTotalGST() => _cartItems.fold(
    0,
    (sum, item) => sum + (item.total * item.gstPercentage / 100),
  );

  void _calculateRounding() {
    if (_isRoundingManual) return;
    double grandTotal = _getGrandTotalBeforeRounding();
    double decimalPart = grandTotal % 1;
    int targetTotal = decimalPart <= 0.50
        ? grandTotal.floor()
        : grandTotal.ceil();
    _roundingAmount = targetTotal - grandTotal;
    if (_roundingAmount.abs() < 0.001) _roundingAmount = 0;
    _roundingController.text = _roundingAmount.toStringAsFixed(2);
  }

  double _getGrandTotalBeforeRounding() => _getSubtotal() + _getTotalGST();

  double _getGrandTotal() => _getGrandTotalBeforeRounding() + _roundingAmount;

  void _resetRounding() {
    setState(() {
      _isRoundingManual = false;
      _roundingAmount = 0;
      _roundingController.clear();
    });
    _calculateRounding();
  }

  void _toggleRoundingMode() {
    setState(() {
      _isRoundingManual = !_isRoundingManual;
      if (!_isRoundingManual) {
        _roundingController.clear();
        _calculateRounding();
      } else {
        _roundingController.text = _roundingAmount.toStringAsFixed(2);
      }
    });
  }

  void _applyManualRounding() {
    double? value = double.tryParse(_roundingController.text);
    if (value != null) {
      setState(() {
        _roundingAmount = value;
        _isRoundingManual = true;
      });
    }
  }

  // ============================================================
  // STOCK UPDATE
  // ============================================================

  /// Units in the cart grouped by stock kind (for the summary line).
  Map<StockKind, int> _cartStockUnitCounts() {
    final counts = <StockKind, int>{};
    for (final item in _cartItems) {
      final kind = _stockKindFor(item.productType);
      counts[kind] = (counts[kind] ?? 0) + item.quantity;
    }
    return counts;
  }

  /// Checks everything the stock update needs BEFORE anything is written.
  /// Returns an error message, or null when all is fine.
  Future<String?> _validateStockBeforeSave() async {
    if (_stockShopId == null || _stockShopId!.isEmpty) {
      return 'Your account is not linked to a shop, so stock cannot be added. '
          'Please log in with a shop account.';
    }

    final phoneImeis = <String>[];
    int stockOps = 1; // the purchase document itself

    for (final item in _cartItems) {
      switch (_stockKindFor(item.productType)) {
        case StockKind.phone:
          if (item.identifiers.length != item.quantity) {
            return '${item.productName}: enter an IMEI for each of the '
                '${item.quantity} unit(s) to add it to stock.';
          }
          phoneImeis.addAll(item.identifiers);
          stockOps += item.quantity;
          break;
        case StockKind.tv:
          stockOps += item.quantity;
          break;
        case StockKind.appliance:
          stockOps += 1;
          break;
        case StockKind.none:
          break;
      }
    }

    if (stockOps > _maxBatchOps) {
      return 'Too many stock units in one purchase (max $_maxBatchOps). '
          'Please split it into two purchases.';
    }

    // IMEI must be unique across phone stock
    for (var i = 0; i < phoneImeis.length; i += 30) {
      final chunk = phoneImeis.sublist(i, min(i + 30, phoneImeis.length));
      final snap = await _firestore
          .collection(_phoneStockCollection)
          .where('imei', whereIn: chunk)
          .get();
      if (snap.docs.isNotEmpty) {
        final dups = snap.docs
            .map((d) => (d.data()['imei'] ?? '').toString())
            .toSet()
            .join(', ');
        return 'These IMEI numbers are already in phone stock: $dups';
      }
    }

    return null;
  }

  Map<String, dynamic> _baseStockFields({
    required String category,
    required CartItem item,
    required int quantity,
    required String purchaseId,
    required String invoiceNo,
    required String uploadedBy,
    required String uploadedById,
  }) {
    final price = item.saleRate > 0 ? item.saleRate : item.rate;
    return {
      'category': category,
      'productBrand': item.brand.trim(),
      'productName': item.productName,
      'productPrice': price,
      'purchaseRate': item.rate,
      'quantity': quantity,
      'shopId': _stockShopId,
      'shopName': _stockShopName,
      'uploadedBy': uploadedBy,
      'uploadedById': uploadedById,
      'uploadedAt': FieldValue.serverTimestamp(),
      'status': 'available',
      'createdAt': FieldValue.serverTimestamp(),
      'purchaseId': purchaseId,
      'purchaseInvoiceNo': invoiceNo,
    };
  }

  /// Builds the stock writes for every cart item and adds them to [ops].
  /// [summary] receives the number of units added per stock kind.
  Future<void> _collectStockOps({
    required String purchaseId,
    required String invoiceNo,
    required List<void Function(WriteBatch)> ops,
    required Map<StockKind, int> summary,
  }) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final String uploadedBy = user?.email ?? user?.name ?? 'Unknown User';
    final String uploadedById = user?.uid ?? '';

    for (final item in _cartItems) {
      final kind = _stockKindFor(item.productType);

      switch (kind) {
        // ---- PHONES: one stock document per IMEI ----
        case StockKind.phone:
          for (var i = 0; i < item.quantity; i++) {
            final ref = _firestore.collection(_phoneStockCollection).doc();
            final data = {
              ..._baseStockFields(
                category: _phoneCategory,
                item: item,
                quantity: 1,
                purchaseId: purchaseId,
                invoiceNo: invoiceNo,
                uploadedBy: uploadedBy,
                uploadedById: uploadedById,
              ),
              'imei': item.identifiers[i],
            };
            ops.add((b) => b.set(ref, data));
          }
          summary[kind] = (summary[kind] ?? 0) + item.quantity;
          break;

        // ---- TVs: one stock document per serial number ----
        case StockKind.tv:
          for (var i = 0; i < item.quantity; i++) {
            final ref = _firestore.collection(_tvStockCollection).doc();
            final data = {
              ..._baseStockFields(
                category: _tvCategory,
                item: item,
                quantity: 1,
                purchaseId: purchaseId,
                invoiceNo: invoiceNo,
                uploadedBy: uploadedBy,
                uploadedById: uploadedById,
              ),
              'serialNumber': i < item.identifiers.length
                  ? item.identifiers[i]
                  : '',
            };
            ops.add((b) => b.set(ref, data));
          }
          summary[kind] = (summary[kind] ?? 0) + item.quantity;
          break;

        // ---- APPLIANCES: same logic as AppliancesStockScreen._saveStock ----
        // one 'available' document per shop + brand + product, quantity added up
        case StockKind.appliance:
          final existing = await _firestore
              .collection(_applianceStockCollection)
              .where('shopId', isEqualTo: _stockShopId)
              .where('category', isEqualTo: _applianceCategory)
              .where('productBrand', isEqualTo: item.brand.trim())
              .where('productName', isEqualTo: item.productName)
              .where('status', isEqualTo: 'available')
              .limit(1)
              .get();

          if (existing.docs.isNotEmpty) {
            final docRef = existing.docs.first.reference;
            final price = item.saleRate > 0 ? item.saleRate : item.rate;
            ops.add(
              (b) => b.update(docRef, {
                'quantity': FieldValue.increment(item.quantity),
                'lastUpdatedAt': FieldValue.serverTimestamp(),
                'lastUpdatedBy': uploadedBy,
                'lastUpdatedById': uploadedById,
                'productPrice': price,
                'lastPurchaseId': purchaseId,
              }),
            );
          } else {
            final ref = _firestore.collection(_applianceStockCollection).doc();
            final data = _baseStockFields(
              category: _applianceCategory,
              item: item,
              quantity: item.quantity,
              purchaseId: purchaseId,
              invoiceNo: invoiceNo,
              uploadedBy: uploadedBy,
              uploadedById: uploadedById,
            );
            ops.add((b) => b.set(ref, data));
          }
          summary[kind] = (summary[kind] ?? 0) + item.quantity;
          break;

        case StockKind.none:
          break; // accessories etc. are not stocked
      }
    }
  }

  String _stockSummaryMessage(Map<StockKind, int> summary) {
    final parts = <String>[];
    if ((summary[StockKind.phone] ?? 0) > 0) {
      parts.add('${summary[StockKind.phone]} phone(s)');
    }
    if ((summary[StockKind.tv] ?? 0) > 0) {
      parts.add('${summary[StockKind.tv]} TV(s)');
    }
    if ((summary[StockKind.appliance] ?? 0) > 0) {
      parts.add('${summary[StockKind.appliance]} appliance(s)');
    }
    if (parts.isEmpty) return '';
    return ' Stock updated: ${parts.join(', ')}.';
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _savePurchase() async {
    if (_invoiceController.text.trim().isEmpty) {
      _showDialog(
        'Validation Error',
        'Please enter an invoice number',
        isError: true,
      );
      return;
    }
    if (_selectedSupplierId == null || _selectedSupplierId!.isEmpty) {
      _showDialog(
        'Validation Error',
        'Please select a supplier',
        isError: true,
      );
      return;
    }
    if (_cartItems.isEmpty) {
      _showDialog(
        'Validation Error',
        'Please add at least one product to cart',
        isError: true,
      );
      return;
    }

    try {
      QuerySnapshot existingInvoice = await _firestore
          .collection('purchases')
          .where('invoiceNo', isEqualTo: _invoiceController.text.trim())
          .get();

      if (existingInvoice.docs.isNotEmpty) {
        var existingDoc = existingInvoice.docs.first;
        var existingData = existingDoc.data() as Map<String, dynamic>;
        var existingDate = existingData['date'] != null
            ? (existingData['date'] as Timestamp).toDate()
            : null;
        var items = existingData['items'] ?? [];
        var grandTotal = (existingData['grandTotal'] ?? 0.0).toDouble();
        var supplierName = existingData['supplierName'] ?? 'Unknown';

        _showExistingInvoiceDialog(
          invoiceNo: _invoiceController.text.trim(),
          supplierName: supplierName,
          date: existingDate,
          itemCount: items.length,
          grandTotal: grandTotal,
          purchaseId: existingDoc.id,
        );
        return;
      }
    } catch (e) {
      print('Error checking duplicate invoice: $e');
    }

    setState(() => _isLoading = true);

    String? uploadedBillPath;

    try {
      // Validate the stock update first, so nothing is uploaded or written
      // if something is wrong.
      final stockError = await _validateStockBeforeSave();
      if (stockError != null) {
        _showDialog('Stock Error', stockError, isError: true);
        return;
      }

      _calculateRounding();

      final invoiceNo = _invoiceController.text.trim();
      final purchaseRef = _firestore.collection('purchases').doc();

      // Collect the stock writes (appliance lookups happen here)
      final ops = <void Function(WriteBatch)>[];
      final stockSummary = <StockKind, int>{};
      await _collectStockOps(
        purchaseId: purchaseRef.id,
        invoiceNo: invoiceNo,
        ops: ops,
        summary: stockSummary,
      );

      // Upload the bill image first (if one was chosen)
      String? billUrl;
      if (_billBytes != null) {
        setState(() {
          _isUploading = true;
          _uploadProgress = 0;
        });
        final uploaded = await _uploadBill(invoiceNo);
        billUrl = uploaded['url'];
        uploadedBillPath = uploaded['path'];
        if (mounted) setState(() => _isUploading = false);
      }

      // Build item maps (PurchaseItem fields + IMEI / serial numbers)
      final List<Map<String, dynamic>> itemMaps = _cartItems.map((item) {
        final base = PurchaseItem(
          productId: item.productId,
          productName: item.productName,
          rate: item.rate,
          quantity: item.quantity,
          total: item.total,
          gstPercentage: item.gstPercentage,
        ).toMap();

        return <String, dynamic>{
          ...base,
          'productType': item.productType,
          'brand': item.brand,
          'identifierType': item.identifierType,
          'imeiOrSerialNumbers': item.identifiers,
        };
      }).toList();

      Map<String, dynamic> purchaseData = {
        'supplierId': _selectedSupplierId,
        'supplierName': _selectedSupplierName ?? 'Unknown',
        'invoiceNo': invoiceNo,
        'date': Timestamp.fromDate(_selectedDate),
        'items': itemMaps,
        'totalAmount': _getSubtotal(),
        'gstAmount': _getTotalGST(),
        'roundingAmount': _roundingAmount,
        'isRoundingManual': _isRoundingManual,
        'grandTotal': _getGrandTotal(),
        'purchaseBillUrl': billUrl,
        'purchaseBillPath': uploadedBillPath,
        'addedToStock': true,
        'stockShopId': _stockShopId,
        'stockShopName': _stockShopName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Purchase + stock are written together in ONE batch (all or nothing)
      final batch = _firestore.batch();
      batch.set(purchaseRef, purchaseData);
      for (final op in ops) {
        op(batch);
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Purchase added successfully!${_stockSummaryMessage(stockSummary)}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _selectedSupplierId = null;
        _selectedSupplierName = null;
        _cartItems.clear();
        _selectedProductId = null;
        _selectedProductName = null;
        _selectedProductType = null;
        _selectedProductBrand = null;
        _quantityController.clear();
        _purchaseRateController.clear();
        _selectedDate = DateTime.now();
        _productRate = 0;
        _productSaleRate = 0;
        _productGst = 18;
        _roundingAmount = 0;
        _isRoundingManual = false;
        _roundingController.clear();
        _invoiceController.clear();
        _supplierController.clear();
        _productController.clear();
        _discountController.clear();
        _discountValue = 0;
        _currentIdentifiers = [];
        _identifierController.clear();
        _billBytes = null;
        _billFileName = null;
        _uploadProgress = 0;
        _filteredSuppliers = _suppliers;
        _filteredProducts = _products;
        _showSupplierSuggestions = false;
        _showProductSuggestions = false;
        _supplierHighlightIndex = -1;
        _productHighlightIndex = -1;
      });

      if (widget.onNavigateToHistory != null) {
        widget.onNavigateToHistory!(4);
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      // If the bill was uploaded but nothing was saved, remove the orphan file
      if (uploadedBillPath != null) {
        try {
          await _storage.ref().child(uploadedBillPath).delete();
        } catch (_) {}
      }
      if (mounted) {
        _showDialog(
          'Error',
          'Error saving purchase: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  /// Goes back to the previous screen (asks first if there is unsaved work).
  Future<void> _goBack() async {
    final hasChanges =
        _cartItems.isNotEmpty || _invoiceController.text.trim().isNotEmpty;
    if (hasChanges) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Leave this screen?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'This purchase has not been saved. Your entries will be lost.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Stay'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 800;
        return Scaffold(
          backgroundColor: Colors.grey[50],
          // Back button is shown when this screen was opened from another screen
          appBar: Navigator.of(context).canPop()
              ? AppBar(
                  title: const Text(
                    'Add Purchase',
                    style: TextStyle(fontSize: 16),
                  ),
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                    onPressed: _goBack,
                  ),
                )
              : null,
          body: Container(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  if (isMobile) _buildMobileLayout() else _buildDesktopLayout(),
                  const SizedBox(height: 16),
                  _buildStockOptionsSection(),
                  const SizedBox(height: 16),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _buildFormSection()),
        const SizedBox(width: 16),
        Expanded(flex: 1, child: _buildCartSection()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildFormSection(),
        const SizedBox(height: 16),
        _buildCartSection(),
      ],
    );
  }

  // ==================== STOCK OPTIONS ====================
  Widget _buildStockOptionsSection() {
    final counts = _cartStockUnitCounts();
    final parts = <String>[];
    if ((counts[StockKind.phone] ?? 0) > 0) {
      parts.add('Phones: ${counts[StockKind.phone]}');
    }
    if ((counts[StockKind.tv] ?? 0) > 0) {
      parts.add('TVs: ${counts[StockKind.tv]}');
    }
    if ((counts[StockKind.appliance] ?? 0) > 0) {
      parts.add('Appliances: ${counts[StockKind.appliance]}');
    }
    if ((counts[StockKind.none] ?? 0) > 0) {
      parts.add('Not stocked: ${counts[StockKind.none]}');
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, size: 18, color: Colors.green[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Purchased items are added to stock automatically',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        parts.isEmpty
                            ? 'Phones, TVs and appliances are added to their stock'
                            : parts.join('  •  '),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _stockShopId != null
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _stockShopId != null
                          ? Icons.store
                          : Icons.warning_amber_rounded,
                      size: 16,
                      color: _stockShopId != null
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _stockShopId != null
                            ? 'Stock will be added to your shop: $_stockShopName'
                            : 'Your account is not linked to a shop, so stock cannot be added.',
                        style: TextStyle(
                          fontSize: 11,
                          color: _stockShopId != null
                              ? Colors.green[800]
                              : Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice Number *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            _buildInvoiceNumberField(),
            const SizedBox(height: 12),
            Text(
              'Purchase Date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            _buildDateSelector(),
            const SizedBox(height: 12),
            Text(
              'Supplier *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            _buildSupplierDatalist(),
            const SizedBox(height: 12),
            Text(
              'Purchase Bill (optional)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            _buildBillSection(),
            const SizedBox(height: 14),
            Text(
              'Add Products',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            _buildProductSelectorWithSearch(),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceNumberField() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long, color: Colors.green[700], size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _invoiceController,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Enter invoice number',
                hintStyle: TextStyle(fontSize: 12),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null && picked != _selectedDate) {
          setState(() => _selectedDate = picked);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.green[700], size: 18),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd/MM/yyyy').format(_selectedDate),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PURCHASE BILL SECTION ====================
  Widget _buildBillSection() {
    if (_billBytes == null) {
      return InkWell(
        onTap: _showBillSourceSheet,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.upload_file, color: Colors.green[700], size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _cameraSupported
                      ? 'Upload bill image (camera or files)'
                      : 'Upload bill image from files',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              Icon(Icons.add_a_photo, size: 18, color: Colors.grey[600]),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _previewBill,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                _billBytes!,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _billFileName ?? 'bill',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${(_billBytes!.length / 1024).toStringAsFixed(0)} KB • uploads when you complete the purchase',
                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Preview',
            icon: Icon(Icons.visibility, size: 18, color: Colors.green[700]),
            onPressed: _previewBill,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            tooltip: 'Replace',
            icon: Icon(Icons.swap_horiz, size: 18, color: Colors.blue[700]),
            onPressed: _showBillSourceSheet,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            onPressed: _removeBill,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  // ==================== SUPPLIER DATALIST WITH KEYBOARD NAV ====================
  Widget _buildSupplierDatalist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedSupplierId != null
                  ? Colors.green
                  : Colors.grey[300]!,
              width: _selectedSupplierId != null ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _selectedSupplierId != null
                    ? Icons.check_circle
                    : Icons.business,
                color: _selectedSupplierId != null
                    ? Colors.green
                    : Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Focus(
                  onKeyEvent: _handleSupplierKey,
                  child: TextField(
                    controller: _supplierController,
                    focusNode: _supplierFocusNode,
                    style: const TextStyle(fontSize: 13),
                    readOnly: _selectedSupplierId != null,
                    decoration: InputDecoration(
                      hintText: _selectedSupplierId != null
                          ? 'Supplier selected ✓'
                          : 'Tap or type (↑↓ to navigate, Enter to select)',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: _selectedSupplierId != null
                            ? Colors.green
                            : Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      suffixIcon: _selectedSupplierId != null
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red,
                              ),
                              onPressed: _clearSupplierSelection,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : (_supplierController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: _clearSupplierSelection,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                : Icon(
                                    Icons.arrow_drop_down,
                                    size: 20,
                                    color: Colors.grey[600],
                                  )),
                    ),
                    onChanged: (value) {
                      if (value.isEmpty && _selectedSupplierId != null) {
                        _clearSupplierSelection();
                      }
                      if (_selectedSupplierId == null) {
                        _filterSuppliers();
                      }
                    },
                    onTap: () {
                      if (_selectedSupplierId == null) {
                        setState(() {
                          if (_supplierController.text.isEmpty) {
                            _filteredSuppliers = _suppliers.take(4).toList();
                          }
                          _showSupplierSuggestions = _suppliers.isNotEmpty;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showSupplierSuggestions && _selectedSupplierId == null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 260),
            child: _filteredSuppliers.isEmpty
                ? _buildAddNewSupplierRow()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: ListView.builder(
                          controller: _supplierScrollController,
                          shrinkWrap: true,
                          itemCount: _filteredSuppliers.length,
                          itemBuilder: (context, index) {
                            final supplier = _filteredSuppliers[index];
                            final data =
                                supplier.data() as Map<String, dynamic>;
                            final name = (data['supplierName'] ?? 'Unknown')
                                .toString();
                            final phone = data['phoneNumber']?.toString() ?? '';
                            final email = data['email']?.toString() ?? '';
                            final isHighlighted =
                                index == _supplierHighlightIndex;

                            return GestureDetector(
                              onTap: () => _selectSupplier(supplier),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                color: isHighlighted
                                    ? Colors.green[50]
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.business,
                                      size: 20,
                                      color: Colors.green[700],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (phone.isNotEmpty ||
                                              email.isNotEmpty)
                                            Text(
                                              [phone, email]
                                                  .where((s) => s.isNotEmpty)
                                                  .join(' • '),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isHighlighted)
                                      Icon(
                                        Icons.keyboard_return,
                                        size: 16,
                                        color: Colors.green[700],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      _buildAddNewSupplierRow(),
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _buildAddNewSupplierRow() {
    final isHighlighted = _supplierHighlightIndex == _filteredSuppliers.length;
    return GestureDetector(
      onTap: () async {
        setState(() {
          _showSupplierSuggestions = false;
          _supplierHighlightIndex = -1;
        });
        await Future.delayed(const Duration(milliseconds: 30));
        if (!mounted) return;
        await _showAddSupplierDialog();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: isHighlighted ? Colors.green[50] : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, size: 20, color: Colors.green[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _filteredSuppliers.isEmpty
                    ? 'No supplier found. Add New Supplier'
                    : 'Add New Supplier',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isHighlighted)
              Icon(Icons.keyboard_return, size: 16, color: Colors.green[700]),
          ],
        ),
      ),
    );
  }

  // ==================== IMEI / SERIAL SECTION ====================
  Widget _buildIdentifierSection() {
    final qty = int.tryParse(_quantityController.text.trim()) ?? 0;
    final count = _currentIdentifiers.length;
    final bool countMatches = qty > 0 && count == qty;
    final bool requiredForStock = _isPhoneProduct;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isPhoneProduct ? Icons.smartphone : Icons.qr_code_2,
                size: 14,
                color: Colors.grey[700],
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  requiredForStock
                      ? '$_identifierLabel (required to add to stock)'
                      : '$_identifierLabel (optional)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: countMatches ? Colors.green[100] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count / $qty',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: countMatches ? Colors.green[800] : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextField(
                    controller: _identifierController,
                    focusNode: _identifierFocusNode,
                    style: const TextStyle(fontSize: 12),
                    inputFormatters: [
                      // Turn pasted new lines into spaces so lists paste correctly
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) => newValue.copyWith(
                          text: newValue.text.replaceAll(
                            RegExp(r'[\r\n]+'),
                            ' ',
                          ),
                        ),
                      ),
                    ],
                    decoration: InputDecoration(
                      hintText: _isPhoneProduct
                          ? 'Enter 15-digit IMEI (separate several with comma/space)'
                          : 'Enter serial number (separate several with comma/space)',
                      hintStyle: const TextStyle(fontSize: 11),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onSubmitted: (_) {
                      _addIdentifiersFromInput();
                      _identifierFocusNode.requestFocus();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: () {
                  _addIdentifiersFromInput();
                  _identifierFocusNode.requestFocus();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(40, 34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Add', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (_currentIdentifiers.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: _currentIdentifiers
                  .map(
                    (id) => Chip(
                      label: Text(id, style: const TextStyle(fontSize: 11)),
                      onDeleted: () => _removeIdentifier(id),
                      deleteIconColor: Colors.red,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.white,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== PRODUCT SELECTOR WITH KEYBOARD NAV ====================
  Widget _buildProductSelectorWithSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedProductId != null
                  ? Colors.green
                  : Colors.grey[300]!,
              width: _selectedProductId != null ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _selectedProductId != null ? Icons.check_circle : Icons.search,
                color: _selectedProductId != null
                    ? Colors.green
                    : Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Focus(
                  onKeyEvent: _handleProductKey,
                  child: TextField(
                    controller: _productController,
                    focusNode: _productFocusNode,
                    style: const TextStyle(fontSize: 13),
                    readOnly: _selectedProductId != null,
                    decoration: InputDecoration(
                      hintText: _selectedProductId != null
                          ? 'Product selected ✓'
                          : 'Search product (↑↓ nav, Enter select)',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: _selectedProductId != null
                            ? Colors.green
                            : Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      suffixIcon: _selectedProductId != null
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red,
                              ),
                              onPressed: _clearProductSelection,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : (_productController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: _clearProductSelection,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                : null),
                    ),
                    onChanged: (value) {
                      if (value.isEmpty && _selectedProductId != null) {
                        _clearProductSelection();
                      }
                      if (_selectedProductId == null) {
                        _filterProducts();
                        setState(() {
                          _showProductSuggestions = value.isNotEmpty;
                        });
                      }
                    },
                    onTap: () {
                      if (_selectedProductId == null &&
                          _productController.text.isNotEmpty) {
                        setState(() {
                          _showProductSuggestions = true;
                          _filterProducts();
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_productController.text.isNotEmpty &&
            _selectedProductId == null &&
            _showProductSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: _filteredProducts.isEmpty
                ? _buildAddNewProductRow()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: ListView.builder(
                          controller: _productScrollController,
                          shrinkWrap: true,
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            final data = product.data() as Map<String, dynamic>;
                            final name = (data['productName'] ?? 'Unknown')
                                .toString();
                            final category = data['category']?.toString() ?? '';
                            final isHighlighted =
                                index == _productHighlightIndex;

                            return GestureDetector(
                              onTap: () => _selectProduct(product),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                color: isHighlighted
                                    ? Colors.green[50]
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.shopping_bag,
                                      size: 20,
                                      color: Colors.green[700],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (category.isNotEmpty)
                                            Text(
                                              category,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isHighlighted)
                                      Icon(
                                        Icons.keyboard_return,
                                        size: 16,
                                        color: Colors.green[700],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      _buildAddNewProductRow(),
                    ],
                  ),
          ),
        if (_selectedProductId != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchase Rate *',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextFormField(
                            controller: _purchaseRateController,
                            style: const TextStyle(fontSize: 13),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                              isDense: true,
                              prefixText: '₹ ',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quantity *',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextFormField(
                            controller: _quantityController,
                            style: const TextStyle(fontSize: 13),
                            keyboardType: TextInputType.number,
                            // Rebuild so the IMEI/serial counter (x / qty) updates
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: '1',
                              hintStyle: TextStyle(fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildIdentifierSection(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.discount, size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Discount (0% default)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildDiscountToggleButton('%', true),
                              _buildDiscountToggleButton('₹', false),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: TextFormField(
                              controller: _discountController,
                              style: const TextStyle(fontSize: 12),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: _usePercentageDiscount ? '0' : '0.00',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                isDense: true,
                                suffixText: _usePercentageDiscount ? '%' : '',
                              ),
                              onChanged: (_) => _onDiscountChanged(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: _addToCartWithDiscount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            minimumSize: const Size(40, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Icon(Icons.add, size: 18),
                        ),
                      ],
                    ),
                    if (_discountValue > 0 &&
                        _purchaseRateController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _buildDiscountPreview(),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAddNewProductRow() {
    final isHighlighted = _productHighlightIndex == _filteredProducts.length;
    return GestureDetector(
      onTap: () async {
        setState(() {
          _showProductSuggestions = false;
          _productHighlightIndex = -1;
        });
        await Future.delayed(const Duration(milliseconds: 30));
        if (!mounted) return;
        await _showAddProductDialog();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: isHighlighted ? Colors.green[50] : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, size: 20, color: Colors.green[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _filteredProducts.isEmpty
                    ? 'No product found. Add New Product'
                    : 'Add New Product',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isHighlighted)
              Icon(Icons.keyboard_return, size: 16, color: Colors.green[700]),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountToggleButton(String label, bool isPercentage) {
    bool isActive = isPercentage == _usePercentageDiscount;
    return GestureDetector(
      onTap: () {
        setState(() {
          _usePercentageDiscount = isPercentage;
          _discountValue = 0;
          _discountController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue[700] : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountPreview() {
    double purchaseRate = double.tryParse(_purchaseRateController.text) ?? 0;
    double discountAmount = _usePercentageDiscount
        ? purchaseRate * (_discountValue / 100)
        : _discountValue;
    double finalRate = purchaseRate - discountAmount;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _usePercentageDiscount
                ? '${_discountValue}% = ₹${discountAmount.toStringAsFixed(2)} off'
                : '₹${_discountValue.toStringAsFixed(2)} discount',
            style: TextStyle(
              fontSize: 10,
              color: Colors.green[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Final: ₹${finalRate.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSection() {
    _calculateRounding();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.green[700], size: 18),
                const SizedBox(width: 8),
                Text(
                  'Cart (${_cartItems.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const Spacer(),
                if (_cartItems.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() => _cartItems.clear());
                      _resetRounding();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                    ),
                    child: const Text(
                      'Clear All',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          if (_cartItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  Icon(Icons.shopping_cart, size: 50, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Empty',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) =>
                        _buildCartItemCard(_cartItems[index], index),
                  ),
                ),
                const Divider(height: 1),
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildCartSummaryRow('Subtotal:', _getSubtotal()),
                      _buildCartSummaryRow('GST:', _getTotalGST()),
                      _buildRoundingSection(),
                      const Divider(height: 1),
                      _buildCartSummaryRow(
                        'Grand Total:',
                        _getGrandTotal(),
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRoundingSection() {
    _calculateRounding();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('Rounding:', style: TextStyle(fontSize: 12)),
              if (_isRoundingManual)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Manual',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              if (_isRoundingManual)
                Container(
                  width: 80,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  child: TextFormField(
                    controller: _roundingController,
                    style: const TextStyle(fontSize: 12),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      isDense: true,
                    ),
                  ),
                )
              else
                Text(
                  _roundingAmount.toStringAsFixed(2),
                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                ),
              IconButton(
                onPressed: _toggleRoundingMode,
                icon: Icon(
                  _isRoundingManual ? Icons.auto_awesome : Icons.edit,
                  size: 16,
                  color: _isRoundingManual
                      ? Colors.blue[700]
                      : Colors.grey[600],
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(CartItem item, int index) {
    // When IMEI / serial numbers are attached, the quantity is tied to them,
    // so +/- is hidden (remove the item and re-add to change it).
    final bool hasIdentifiers = item.identifiers.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.shopping_bag,
                color: Colors.green[700],
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '₹${item.rate.toStringAsFixed(2)} x ${item.quantity}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  if (hasIdentifiers)
                    Tooltip(
                      message: item.identifiers.join('\n'),
                      child: Text(
                        '${item.identifierType}: ${item.identifiers.join(', ')}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${item.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Row(
                  children: [
                    if (!hasIdentifiers)
                      IconButton(
                        onPressed: () =>
                            _updateCartItemQuantity(index, item.quantity - 1),
                        icon: const Icon(Icons.remove, size: 14),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    Text(
                      item.quantity.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!hasIdentifiers)
                      IconButton(
                        onPressed: () =>
                            _updateCartItemQuantity(index, item.quantity + 1),
                        icon: const Icon(Icons.add, size: 14),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    IconButton(
                      onPressed: () => _removeFromCart(index),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        if (_isUploading) ...[
          LinearProgressIndicator(
            value: _uploadProgress > 0 ? _uploadProgress : null,
            color: Colors.green[700],
            backgroundColor: Colors.green[100],
          ),
          const SizedBox(height: 4),
          Text(
            'Uploading bill… ${(_uploadProgress * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading || _cartItems.isEmpty ? null : _savePurchase,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Complete Purchase',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartSummaryRow(
    String label,
    double value, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 13 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isBold ? 13 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.green[700] : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _purchaseRateController.dispose();
    _quantityController.dispose();
    _identifierController.dispose();
    _identifierFocusNode.dispose();
    _supplierController.dispose();
    _productController.dispose();
    _roundingController.dispose();
    _discountController.dispose();
    _supplierFocusNode.dispose();
    _productFocusNode.dispose();
    _supplierKeyFocus.dispose();
    _productKeyFocus.dispose();
    _supplierScrollController.dispose();
    _productScrollController.dispose();
    super.dispose();
  }
}

/// Which stock collection a purchased product goes into.
enum StockKind { phone, tv, appliance, none }

class CartItem {
  String productId;
  String productName;
  double rate;
  int quantity;
  double total;
  int gstPercentage;
  double discount;
  String discountType;
  double originalRate;
  String productType;
  String brand;
  double saleRate;
  List<String> identifiers; // IMEI numbers or serial numbers, one per unit
  String identifierType; // 'IMEI' or 'Serial'

  CartItem({
    required this.productId,
    required this.productName,
    required this.rate,
    required this.quantity,
    required this.total,
    required this.gstPercentage,
    this.discount = 0,
    this.discountType = 'none',
    this.originalRate = 0,
    this.productType = '',
    this.brand = '',
    this.saleRate = 0,
    List<String>? identifiers,
    this.identifierType = '',
  }) : identifiers = identifiers ?? <String>[];
}
