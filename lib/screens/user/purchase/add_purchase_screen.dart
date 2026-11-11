import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sales_stock/providers/auth_provider.dart';
import '../../../models/purchase.dart';
import 'add_product_screen.dart';
import 'add_supplier_screen.dart';

/// Result returned by the selection popup (supplier / product).
class _PickerResult {
  final QueryDocumentSnapshot? doc;
  final bool addNew;
  const _PickerResult.pick(this.doc) : addNew = false;
  const _PickerResult.addNew() : doc = null, addNew = true;
}

class AddPurchaseScreen extends StatefulWidget {
  final Function(int)? onNavigateToHistory;

  const AddPurchaseScreen({super.key, this.onNavigateToHistory});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  // ============================================================
  // STOCK CONFIG
  // ============================================================
  static const String _applianceStockCollection = 'applianceStock';
  static const String _phoneStockCollection = 'phoneStock';
  static const String _tvStockCollection = 'tvStock';
  static const String _accessoriesStockCollection = 'accessoriesStock';
  static const String _applianceCategory = 'Appliances';
  static const String _phoneCategory = 'Phone';
  static const String _tvCategory = 'TV';
  static const String _accessoryCategory = 'Accessories';
  static const int _maxBatchOps = 480;

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
  final FocusNode _rateFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();

  // IMEI / Serial number entry for the selected product
  final TextEditingController _identifierController = TextEditingController();
  final FocusNode _identifierFocusNode = FocusNode();
  List<String> _currentIdentifiers = [];

  // Purchase-level option
  bool _addPurchaseToStock = true;

  // Lets the open product-details popup rebuild when screen state changes
  StateSetter? _modalSetState;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    try {
      _modalSetState?.call(() {}); // also rebuild the open popup
    } catch (_) {}
  }

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

  // Discount fields
  bool _usePercentageDiscount = true;
  final TextEditingController _discountController = TextEditingController();
  double _discountValue = 0;

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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // PRODUCT TYPE HELPERS
  // ============================================================

  StockKind _stockKindFor(String productType) {
    final t = productType.toLowerCase();
    if (t.contains('phone') || t.contains('mobile')) return StockKind.phone;
    if (RegExp(r'\btv\b|television').hasMatch(t)) return StockKind.tv;
    if (t.contains('appliance')) return StockKind.appliance;
    if (t.contains('accessor')) return StockKind.accessory;
    return StockKind.none;
  }

  bool get _isPhoneProduct =>
      _stockKindFor(_selectedProductType ?? '') == StockKind.phone;

  String get _identifierLabel => _isPhoneProduct ? 'IMEI' : 'Serial Number';
  String get _identifierTypeKey => _isPhoneProduct ? 'IMEI' : 'Serial';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _loadProducts();

    _discountController.addListener(_onDiscountChanged);
    _roundingController.addListener(_onRoundingChanged);
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

  // ============================================================
  // SELECTION POPUPS (supplier / product)
  // ============================================================

  Future<void> _openSupplierPicker() async {
    FocusScope.of(context).unfocus();
    final res = await _showPickerDialog(
      title: 'Select Supplier',
      icon: Icons.business,
      items: _suppliers,
      titleOf: (d) => (d['supplierName'] ?? 'Unknown').toString(),
      subtitleOf: (d) => [
        d['phoneNumber'],
        d['email'],
      ].where((e) => e != null && e.toString().isNotEmpty).join(' • '),
      searchFields: (d) => [
        (d['supplierName'] ?? '').toString(),
        (d['phoneNumber'] ?? '').toString(),
        (d['email'] ?? '').toString(),
      ],
      addLabel: 'Add New Supplier',
    );
    if (!mounted || res == null) return;
    if (res.addNew) {
      await _showAddSupplierDialog();
    } else if (res.doc != null) {
      _selectSupplier(res.doc!);
    }
  }

  Future<void> _openProductPicker() async {
    FocusScope.of(context).unfocus();
    final res = await _showPickerDialog(
      title: 'Select Product',
      icon: Icons.shopping_bag,
      items: _products,
      titleOf: (d) => (d['productName'] ?? 'Unknown').toString(),
      subtitleOf: (d) => [
        d['brand'],
        d['category'],
      ].where((e) => e != null && e.toString().isNotEmpty).join(' • '),
      searchFields: (d) => [
        (d['productName'] ?? '').toString(),
        (d['category'] ?? '').toString(),
        (d['brand'] ?? '').toString(),
      ],
      addLabel: 'Add New Product',
    );
    if (!mounted || res == null) return;
    if (res.addNew) {
      await _showAddProductDialog();
    } else if (res.doc != null) {
      _selectProduct(res.doc!); // opens the product details popup
    }
  }

  Future<_PickerResult?> _showPickerDialog({
    required String title,
    required IconData icon,
    required List<QueryDocumentSnapshot> items,
    required String Function(Map<String, dynamic>) titleOf,
    required String Function(Map<String, dynamic>) subtitleOf,
    required List<String> Function(Map<String, dynamic>) searchFields,
    required String addLabel,
  }) {
    String query = '';
    int highlight = -1;
    final scrollController = ScrollController();
    const double itemHeight = 56;

    return showDialog<_PickerResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            final q = query.toLowerCase().trim();
            final filtered = q.isEmpty
                ? items
                : items.where((d) {
                    final m = d.data() as Map<String, dynamic>;
                    return searchFields(
                      m,
                    ).any((f) => f.toLowerCase().contains(q));
                  }).toList();

            void pick(int i) {
              Navigator.of(dialogContext).pop(_PickerResult.pick(filtered[i]));
            }

            void move(int delta) {
              if (filtered.isEmpty) return;
              setS(() {
                highlight = (highlight + delta) % filtered.length;
                if (highlight < 0) highlight = filtered.length - 1;
              });
              if (scrollController.hasClients) {
                final target = (highlight * itemHeight - itemHeight * 2).clamp(
                  0.0,
                  scrollController.position.maxScrollExtent,
                );
                scrollController.animateTo(
                  target,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                );
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 460,
                  maxHeight: MediaQuery.of(ctx).size.height * 0.8,
                ),
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                      return KeyEventResult.ignored;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      move(1);
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      move(-1);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: Colors.green[700]),
                            const SizedBox(width: 6),
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  autofocus: true,
                                  style: const TextStyle(fontSize: 13),
                                  textInputAction: TextInputAction.search,
                                  decoration: const InputDecoration(
                                    hintText: 'Search…',
                                    hintStyle: TextStyle(fontSize: 12),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (v) => setS(() {
                                    query = v;
                                    highlight = -1;
                                  }),
                                  onSubmitted: (_) {
                                    if (filtered.isEmpty) return;
                                    pick(highlight >= 0 ? highlight : 0);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: filtered.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Nothing found',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                shrinkWrap: true,
                                itemExtent: itemHeight,
                                itemCount: filtered.length,
                                itemBuilder: (_, index) {
                                  final m =
                                      filtered[index].data()
                                          as Map<String, dynamic>;
                                  final sub = subtitleOf(m);
                                  final isHi = index == highlight;
                                  return InkWell(
                                    onTap: () => pick(index),
                                    child: Container(
                                      color: isHi
                                          ? Colors.green[50]
                                          : Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            icon,
                                            size: 20,
                                            color: Colors.green[700],
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  titleOf(m),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (sub.isNotEmpty)
                                                  Text(
                                                    sub,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (isHi)
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
                      InkWell(
                        onTap: () => Navigator.of(
                          dialogContext,
                        ).pop(const _PickerResult.addNew()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 20,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 12),
                              Text(
                                addLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(scrollController.dispose);
  }

  // ==================== ADD SUPPLIER ====================
  Future<void> _showAddSupplierDialog() async {
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
      if (!mounted) return;
      setState(() => _suppliers = snapshot.docs);
    } catch (e) {
      _showDialog('Error', 'Error loading suppliers: $e', isError: true);
    }
  }

  Future<void> _loadProducts() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('products').get();
      if (!mounted) return;
      setState(() => _products = snapshot.docs);
    } catch (e) {
      _showDialog('Error', 'Error loading products: $e', isError: true);
    }
  }

  void _selectSupplier(QueryDocumentSnapshot supplier) {
    Map<String, dynamic> data = supplier.data() as Map<String, dynamic>;
    setState(() {
      _selectedSupplierId = supplier.id;
      _selectedSupplierName = (data['supplierName'] ?? 'Unknown').toString();
    });

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
      _productRate = (data['purchaseRate'] ?? 0).toDouble();
      _productSaleRate = (data['saleRate'] ?? 0).toDouble();
      _productGst = (data['gstPercentage'] ?? 18).toInt();
      _purchaseRateController.text = _productRate.toString();
      _quantityController.text = '1';
      _discountController.clear();
      _discountValue = 0;
      _currentIdentifiers = [];
      _identifierController.clear();
    });

    _openProductDetailsModal();
  }

  void _clearSupplierSelection() {
    setState(() {
      _selectedSupplierId = null;
      _selectedSupplierName = null;
    });
  }

  void _clearProductSelection() {
    setState(() {
      _selectedProductId = null;
      _selectedProductName = null;
      _selectedProductType = null;
      _selectedProductBrand = null;
      _purchaseRateController.clear();
      _quantityController.clear();
      _discountController.clear();
      _discountValue = 0;
      _currentIdentifiers = [];
      _identifierController.clear();
    });
  }

  // ============================================================
  // PRODUCT DETAILS POPUP
  // ============================================================

  Future<void> _openProductDetailsModal() async {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || _selectedProductId == null) return;
      _quantityFocusNode.requestFocus();
      _quantityController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _quantityController.text.length,
      );
    });

    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            _modalSetState = setModalState;
            final screenHeight = MediaQuery.of(ctx).size.height;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 460,
                  maxHeight: screenHeight * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 18,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Product Details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                          ),
                        ],
                      ),
                      _buildSelectedProductHeader(dialogContext),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildRateField()),
                          const SizedBox(width: 10),
                          Expanded(child: _buildQuantityField()),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_stockKindFor(_selectedProductType ?? '') !=
                          StockKind.none) ...[
                        _buildIdentifierSection(),
                        const SizedBox(height: 10),
                      ],
                      _buildDiscountSection(),
                      const SizedBox(height: 10),
                      _buildLineSummary(),
                      const SizedBox(height: 10),
                      _buildAddToCartButton(dialogContext),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    _modalSetState = null;
    if (!mounted) return;
    if (added != true && _selectedProductId != null) _clearProductSelection();
  }

  // ============================================================
  // IMEI / SERIAL HANDLING
  // ============================================================

  Set<String> _allUsedIdentifiers() {
    final used = <String>{};
    for (final item in _cartItems) {
      used.addAll(item.identifiers.map((e) => e.toLowerCase()));
    }
    used.addAll(_currentIdentifiers.map((e) => e.toLowerCase()));
    return used;
  }

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

  bool get _scannerSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String? _addScannedIdentifier(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Empty code';

    final qty = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (qty > 0 && _currentIdentifiers.length >= qty) {
      return 'Quantity is $qty — all $_identifierLabel numbers are already added';
    }
    if (_isPhoneProduct && !RegExp(r'^\d{15}$').hasMatch(value)) {
      return '"$value" is not a valid 15-digit IMEI';
    }
    if (_allUsedIdentifiers().contains(value.toLowerCase())) {
      return '"$value" is already added';
    }

    setState(() => _currentIdentifiers.add(value));
    return null;
  }

  Future<void> _openIdentifierScanner() async {
    final qty = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (qty <= 0) {
      _showDialog(
        'Quantity needed',
        'Enter the quantity first, then scan the $_identifierLabel numbers.',
        isError: true,
      );
      return;
    }
    if (_currentIdentifiers.length >= qty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'All $qty $_identifierLabel number(s) are already added',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _identifierFocusNode.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _IdentifierScannerPage(
          label: _identifierLabel,
          target: qty,
          currentCount: () => _currentIdentifiers.length,
          onScanned: _addScannedIdentifier,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  // ============================================================
  // CART
  // ============================================================

  bool _addToCartWithDiscount({BuildContext? modalContext}) {
    if (_selectedProductId == null) {
      _showDialog('Error', 'Please select a product', isError: true);
      return false;
    }
    if (_quantityController.text.trim().isEmpty) {
      _showDialog('Error', 'Please enter quantity', isError: true);
      return false;
    }
    int quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      _showDialog('Error', 'Please enter valid quantity', isError: true);
      return false;
    }
    double rate = double.tryParse(_purchaseRateController.text.trim()) ?? 0;
    if (rate <= 0) {
      _showDialog('Error', 'Please enter valid purchase rate', isError: true);
      return false;
    }

    if (!_addIdentifiersFromInput()) return false;

    final List<String> identifiers = List<String>.from(_currentIdentifiers);
    if (identifiers.isNotEmpty && identifiers.length != quantity) {
      _showDialog(
        'Error',
        'Quantity is $quantity but ${identifiers.length} '
            '$_identifierLabel${identifiers.length == 1 ? '' : 's'} entered. '
            'Enter exactly $quantity, or remove them all to skip.',
        isError: true,
      );
      return false;
    }

    if (_isPhoneProduct &&
        _addPurchaseToStock &&
        identifiers.length != quantity) {
      _showDialog(
        'IMEI required',
        'Enter an IMEI for each of the $quantity phone(s), '
            'or turn off "Add to stock" above the Complete Purchase button.',
        isError: true,
      );
      return false;
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
      return false;
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
        return false;
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

    final addedName = _selectedProductName ?? '';

    if (modalContext != null && modalContext.mounted) {
      Navigator.of(modalContext).pop(true);
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
    });

    _resetRounding();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added to cart: $addedName'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );

    return true;
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

  // ============================================================
  // STOCK UPDATE
  // ============================================================

  Future<String?> _validateStockBeforeSave() async {
    if (!_addPurchaseToStock) return null;

    final needsStock = _cartItems.any(
      (i) => _stockKindFor(i.productType) != StockKind.none,
    );

    if (needsStock && (_stockShopId == null || _stockShopId!.isEmpty)) {
      return 'Your account is not linked to a shop, so stock cannot be added. '
          'Please log in with a shop account.';
    }

    final phoneImeis = <String>[];
    int stockOps = 1;

    for (final item in _cartItems) {
      switch (_stockKindFor(item.productType)) {
        case StockKind.phone:
          if (item.identifiers.length != item.quantity) {
            return '${item.productName}: enter an IMEI for each of the '
                '${item.quantity} unit(s), or turn off "Add to stock".';
          }
          phoneImeis.addAll(item.identifiers);
          stockOps += item.quantity;
          break;
        case StockKind.tv:
          stockOps += item.quantity;
          break;
        case StockKind.appliance:
          stockOps += item.quantity;
          break;
        case StockKind.accessory:
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
      'modelName': item.productName,
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

  Future<void> _collectStockOps({
    required String purchaseId,
    required String invoiceNo,
    required List<void Function(WriteBatch)> ops,
    required Map<StockKind, int> summary,
  }) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final String uploadedBy = user?.email ?? user?.name ?? 'Unknown User';
    final String uploadedById = user?.uid ?? '';

    if (!_addPurchaseToStock) return;

    for (final item in _cartItems) {
      final kind = _stockKindFor(item.productType);

      switch (kind) {
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

        case StockKind.appliance:
          for (var i = 0; i < item.quantity; i++) {
            final ref = _firestore.collection(_applianceStockCollection).doc();
            final data = {
              ..._baseStockFields(
                category: _applianceCategory,
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

        case StockKind.accessory:
          final ref = _firestore.collection(_accessoriesStockCollection).doc();
          final data = {
            ..._baseStockFields(
              category: _accessoryCategory,
              item: item,
              quantity: item.quantity,
              purchaseId: purchaseId,
              invoiceNo: invoiceNo,
              uploadedBy: uploadedBy,
              uploadedById: uploadedById,
            ),
          };
          ops.add((b) => b.set(ref, data));
          summary[kind] = (summary[kind] ?? 0) + item.quantity;
          break;

        case StockKind.none:
          break;
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
    if ((summary[StockKind.accessory] ?? 0) > 0) {
      parts.add('${summary[StockKind.accessory]} accessory item(s)');
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
      debugPrint('Error checking duplicate invoice: $e');
    }

    setState(() => _isLoading = true);

    try {
      final stockError = await _validateStockBeforeSave();
      if (stockError != null) {
        _showDialog('Stock Error', stockError, isError: true);
        return;
      }

      _calculateRounding();

      final invoiceNo = _invoiceController.text.trim();
      final purchaseRef = _firestore.collection('purchases').doc();

      final ops = <void Function(WriteBatch)>[];
      final stockSummary = <StockKind, int>{};
      await _collectStockOps(
        purchaseId: purchaseRef.id,
        invoiceNo: invoiceNo,
        ops: ops,
        summary: stockSummary,
      );

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
          'addedToStock':
              _addPurchaseToStock &&
              _stockKindFor(item.productType) != StockKind.none,
        };
      }).toList();

      final bool anyAddedToStock =
          _addPurchaseToStock &&
          _cartItems.any((i) => _stockKindFor(i.productType) != StockKind.none);

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
        'purchaseBillUrl': null, // Removed image upload
        'purchaseBillPath': null, // Removed image upload
        'addedToStock': anyAddedToStock,
        'stockShopId': _stockShopId,
        'stockShopName': _stockShopName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final batch = _firestore.batch();
      batch.set(purchaseRef, purchaseData);
      for (final op in ops) {
        op(batch);
      }
      await batch.commit();

      if (!mounted) return;
      final String stockMsg = _addPurchaseToStock
          ? _stockSummaryMessage(stockSummary)
          : ' Stock was not updated.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase added successfully!$stockMsg'),
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
        _discountController.clear();
        _discountValue = 0;
        _currentIdentifiers = [];
        _identifierController.clear();
        _addPurchaseToStock = true;
      });

      if (widget.onNavigateToHistory != null) {
        widget.onNavigateToHistory!(4);
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
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
        });
      }
    }
  }

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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  if (isMobile) _buildMobileLayout() else _buildDesktopLayout(),
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
            _buildSupplierSelector(),
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
            _buildProductSelector(),
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

  Widget _buildSupplierSelector() {
    final selected = _selectedSupplierId != null;
    return InkWell(
      onTap: _openSupplierPicker,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? Colors.green : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.business,
              color: selected ? Colors.green : Colors.grey[600],
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected
                    ? (_selectedSupplierName ?? '')
                    : 'Tap to select supplier',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: selected ? 13 : 12,
                  color: selected ? Colors.black : Colors.grey[500],
                ),
              ),
            ),
            if (selected)
              InkWell(
                onTap: _clearSupplierSelection,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: Colors.red),
                ),
              )
            else
              Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  int get _enteredQty => int.tryParse(_quantityController.text.trim()) ?? 0;
  double get _enteredRate =>
      double.tryParse(_purchaseRateController.text.trim()) ?? 0;

  double get _enteredDiscountAmount {
    if (_discountValue <= 0) return 0;
    return _usePercentageDiscount
        ? _enteredRate * (_discountValue / 100)
        : _discountValue;
  }

  double get _enteredFinalRate => _enteredRate - _enteredDiscountAmount;

  String? get _addToCartBlocker {
    if (_selectedProductId == null) return 'Select a product';
    if (_enteredRate <= 0) return 'Enter the purchase rate';
    if (_enteredQty <= 0) return 'Enter the quantity';
    if (_enteredFinalRate < 0) return 'Discount is more than the rate';
    final count = _currentIdentifiers.length;
    if (_isPhoneProduct && _addPurchaseToStock && count != _enteredQty) {
      return 'Add $_enteredQty IMEI number(s) — $count added';
    }
    if (count > 0 && count != _enteredQty) {
      return 'Add $_enteredQty $_identifierLabel(s), or remove all — $count added';
    }
    return null;
  }

  void _changeQuantityBy(int delta) {
    final next = (_enteredQty + delta).clamp(1, 9999);
    setState(() {
      _quantityController.text = next.toString();
      _quantityController.selection = TextSelection.collapsed(
        offset: _quantityController.text.length,
      );
    });
  }

  Widget _fieldLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        required ? '$text *' : text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildSelectedProductHeader(BuildContext modalContext) {
    final type = _selectedProductType ?? '';
    final kind = _stockKindFor(type);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              kind == StockKind.phone
                  ? Icons.smartphone
                  : (kind == StockKind.tv
                        ? Icons.tv
                        : (kind == StockKind.accessory
                              ? Icons.headphones
                              : Icons.shopping_bag)),
              size: 20,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _selectedProductName ?? '',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(modalContext).pop(false),
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: const Text('Change', style: TextStyle(fontSize: 10)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[700],
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(40, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Purchase Rate', required: true),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!, width: 1),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: TextField(
            controller: _purchaseRateController,
            focusNode: _rateFocusNode,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _quantityFocusNode.requestFocus(),
            decoration: const InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(fontSize: 11),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              prefixText: '₹ ',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityField() {
    Widget stepBtn(IconData icon, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 30,
        height: 38,
        child: Icon(icon, size: 18, color: Colors.green[700]),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Quantity', required: true),
        Container(
          height: 38,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!, width: 1),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            children: [
              stepBtn(Icons.remove, () => _changeQuantityBy(-1)),
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  focusNode: _quantityFocusNode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (_stockKindFor(_selectedProductType ?? '') !=
                        StockKind.none) {
                      _identifierFocusNode.requestFocus();
                    } else {
                      _rateFocusNode.requestFocus();
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: '1',
                    hintStyle: TextStyle(fontSize: 11),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              stepBtn(Icons.add, () => _changeQuantityBy(1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdentifierSection() {
    final qty = _enteredQty;
    final count = _currentIdentifiers.length;
    final bool countMatches = qty > 0 && count == qty;
    final bool tooMany = qty > 0 && count > qty;
    final bool requiredForStock = _isPhoneProduct && _addPurchaseToStock;
    final double progress = qty > 0 ? (count / qty).clamp(0.0, 1.0) : 0.0;
    final Color statusColor = tooMany
        ? Colors.red.shade700
        : (countMatches ? Colors.green.shade700 : Colors.orange.shade800);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: countMatches ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isPhoneProduct ? Icons.smartphone : Icons.qr_code_2,
                size: 16,
                color: Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  requiredForStock
                      ? '$_identifierLabel numbers (required)'
                      : '$_identifierLabel numbers (optional)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: countMatches ? Colors.green[100] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count / $qty',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.grey[200],
              color: tooMany ? Colors.red : Colors.green[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _identifierController,
                    focusNode: _identifierFocusNode,
                    style: const TextStyle(fontSize: 12),
                    keyboardType: _isPhoneProduct
                        ? TextInputType.number
                        : TextInputType.text,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
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
                          ? 'Type or paste 15-digit IMEI'
                          : 'Type or paste serial number',
                      hintStyle: const TextStyle(fontSize: 11),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (value) {
                      final v = value.trim();
                      if (_isPhoneProduct && RegExp(r'^\d{15}$').hasMatch(v)) {
                        _addIdentifiersFromInput();
                        _identifierFocusNode.requestFocus();
                      } else {
                        setState(() {});
                      }
                    },
                    onSubmitted: (_) {
                      _addIdentifiersFromInput();
                      _identifierFocusNode.requestFocus();
                    },
                  ),
                ),
              ),
              if (_scannerSupported) ...[
                const SizedBox(width: 6),
                SizedBox(
                  height: 38,
                  width: 38,
                  child: IconButton(
                    onPressed: _openIdentifierScanner,
                    tooltip: 'Scan $_identifierLabel',
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.qr_code_scanner,
                      size: 22,
                      color: Colors.blue[700],
                    ),
                    style: IconButton.styleFrom(
                      side: BorderSide(color: Colors.blue[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: _identifierController.text.trim().isEmpty
                      ? null
                      : () {
                          _addIdentifiersFromInput();
                          _identifierFocusNode.requestFocus();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Add', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          if (_currentIdentifiers.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: _currentIdentifiers
                  .map(
                    (id) => Chip(
                      label: Text(id, style: const TextStyle(fontSize: 10)),
                      onDeleted: () => _removeIdentifier(id),
                      deleteIconColor: Colors.red,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.white,
                    ),
                  )
                  .toList(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _currentIdentifiers.clear()),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear all', style: TextStyle(fontSize: 10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscountSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.discount, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 6),
          Text(
            'Discount',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _discountController,
                style: const TextStyle(fontSize: 12),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  hintText: _usePercentageDiscount ? '0' : '0.00',
                  hintStyle: const TextStyle(fontSize: 11),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                  suffixText: _usePercentageDiscount ? '%' : null,
                  prefixText: _usePercentageDiscount ? null : '₹ ',
                ),
                onChanged: (_) => _onDiscountChanged(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
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
    );
  }

  Widget _buildLineSummary() {
    final rate = _enteredRate;
    final qty = _enteredQty;
    if (rate <= 0 || qty <= 0) return const SizedBox.shrink();

    final discount = _enteredDiscountAmount;
    final finalRate = _enteredFinalRate;
    final taxable = finalRate < 0 ? 0.0 : finalRate * qty;
    final gst = taxable * _productGst / 100;
    final total = taxable + gst;

    Widget row(String l, String v, {bool bold = false, Color? color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l,
              style: TextStyle(
                fontSize: bold ? 11 : 10,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: Colors.grey[800],
              ),
            ),
            Text(
              v,
              style: TextStyle(
                fontSize: bold ? 12 : 10,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color ?? Colors.grey[900],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          if (discount > 0) ...[
            row(
              _usePercentageDiscount
                  ? 'Discount ($_discountValue%)'
                  : 'Discount',
              '- ₹${discount.toStringAsFixed(2)} / unit',
              color: Colors.red[700],
            ),
          ],
          row(
            'Rate after discount',
            '₹${(finalRate < 0 ? 0 : finalRate).toStringAsFixed(2)} × $qty',
          ),
          row('Amount', '₹${taxable.toStringAsFixed(2)}'),
          row('GST ($_productGst%)', '₹${gst.toStringAsFixed(2)}'),
          const Divider(height: 10),
          row(
            'Line total',
            '₹${total.toStringAsFixed(2)}',
            bold: true,
            color: Colors.green[800],
          ),
        ],
      ),
    );
  }

  Widget _buildAddToCartButton(BuildContext modalContext) {
    final blocker = _addToCartBlocker;
    final ready = blocker == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            onPressed: () => _addToCartWithDiscount(modalContext: modalContext),
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text(
              'Add to Cart',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ready ? Colors.green[700] : Colors.grey[400],
              foregroundColor: Colors.white,
              elevation: ready ? 2 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (!ready)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 12, color: Colors.orange[800]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    blocker,
                    style: TextStyle(fontSize: 10, color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProductSelector() {
    return InkWell(
      onTap: _openProductPicker,
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
            Icon(Icons.search, color: Colors.grey[600], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tap to select product',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]),
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
        width: 32,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.blue[700] : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey[600],
          ),
        ),
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
                // Display all items without scrolling
                Column(
                  children: List.generate(
                    _cartItems.length,
                    (index) => _buildCartItemCard(_cartItems[index], index),
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

  Widget _buildStockOptionToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _addPurchaseToStock ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _addPurchaseToStock
              ? Colors.green.shade200
              : Colors.orange.shade200,
        ),
      ),
      child: SwitchListTile(
        dense: true,
        value: _addPurchaseToStock,
        activeColor: Colors.green[700],
        onChanged: _isLoading
            ? null
            : (v) => setState(() => _addPurchaseToStock = v),
        secondary: Icon(
          _addPurchaseToStock ? Icons.inventory_2 : Icons.receipt_long,
          color: _addPurchaseToStock ? Colors.green[700] : Colors.orange[800],
        ),
        title: const Text(
          'Add to stock',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _addPurchaseToStock
              ? 'Phones, TVs, appliances and accessories in this purchase will be added to stock'
              : 'Only the purchase is saved — stock will NOT be updated',
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        _buildStockOptionToggle(),
        const SizedBox(height: 10),
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
        SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
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
    _modalSetState = null;
    _invoiceController.dispose();
    _purchaseRateController.dispose();
    _quantityController.dispose();
    _rateFocusNode.dispose();
    _quantityFocusNode.dispose();
    _identifierController.dispose();
    _identifierFocusNode.dispose();
    _roundingController.dispose();
    _discountController.dispose();
    super.dispose();
  }
}

/// Full-screen camera scanner. Stays open and adds every valid code until the
/// required number of IMEI / serial numbers has been scanned.
class _IdentifierScannerPage extends StatefulWidget {
  final String label;
  final int target;
  final int Function() currentCount;
  final String? Function(String value) onScanned;

  const _IdentifierScannerPage({
    required this.label,
    required this.target,
    required this.currentCount,
    required this.onScanned,
  });

  @override
  State<_IdentifierScannerPage> createState() => _IdentifierScannerPageState();
}

class _IdentifierScannerPageState extends State<_IdentifierScannerPage> {
  final MobileScannerController _controller = MobileScannerController();

  String? _message;
  bool _isError = false;
  bool _torchOn = false;
  String _lastValue = '';
  DateTime _lastTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;

      // Ignore the same code being re-read for 2 seconds
      final now = DateTime.now();
      if (value == _lastValue &&
          now.difference(_lastTime) < const Duration(seconds: 2)) {
        continue;
      }
      _lastValue = value;
      _lastTime = now;

      final error = widget.onScanned(value);
      HapticFeedback.mediumImpact();

      if (!mounted) return;
      setState(() {
        _message = error ?? 'Added: $value';
        _isError = error != null;
      });

      // Everything scanned -> close automatically
      if (error == null && widget.currentCount() >= widget.target) {
        Navigator.of(context).pop();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.currentCount();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Scan ${widget.label}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Flashlight',
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _controller.toggleTorch();
              if (mounted) setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(controller: _controller, onDetect: _onDetect),
          ),
          // Aiming frame
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Status panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              color: Colors.black87,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scanned $count / ${widget.target}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _message ??
                        'Point the camera at the ${widget.label} barcode',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _message == null
                          ? Colors.white70
                          : (_isError ? Colors.redAccent : Colors.greenAccent),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which stock collection a purchased product goes into.
enum StockKind { phone, tv, appliance, accessory, none }

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
