import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sales_stock/screens/user/inventory/imei_scanner.dart';
import 'package:sales_stock/screens/user/inventory/ready_cash_bill_form.dart';
import '../../../providers/auth_provider.dart';
import 'add_stock_modal.dart';

class ReadyCashPhoneStockScreen extends StatefulWidget {
  final bool isAdmin;
  final List<Map<String, dynamic>> shops;

  const ReadyCashPhoneStockScreen({
    super.key,
    this.isAdmin = false,
    this.shops = const [],
  });

  @override
  State<ReadyCashPhoneStockScreen> createState() =>
      _ReadyCashPhoneStockScreenState();
}

class _ReadyCashPhoneStockScreenState extends State<ReadyCashPhoneStockScreen>
    with SingleTickerProviderStateMixin {
  static const String _stockType = 'ready_cash';

  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  String _searchQuery = '';
  late TextEditingController _searchController;

  String? _selectedBrand;
  String? _selectedProduct;
  String? _newProductName;
  double? _newProductPrice;
  int? _quantity;
  List<String> _imeiNumbers = [];
  final List<TextEditingController> _imeiControllers = [];

  final List<String> _brands = [
    'Samsung',
    'Oppo',
    'Vivo',
    'Realme',
    'Xiaomi',
    'Tecno',
    'Apple',
    'Google',
    'OnePlus',
    'nothing',
    'iqoo',
    'motorola',
  ];
  final Map<String, List<Map<String, dynamic>>> _productsByBrand = {};
  bool _isLoading = false;
  bool _showAddProductForm = false;
  bool _showAddStockModal = false;

  List<Map<String, dynamic>> _shops = [];
  Map<String, dynamic>? _selectedPhoneForAction;

  // Admin only
  String? _adminShopFilter;
  Map<String, dynamic>? _adminTargetShop;

  late TextEditingController _productSearchController;

  double? _originalProductPrice;
  bool _showPriceChangeOption = false;
  late TextEditingController _priceChangeController;

  late TextEditingController _newProductNameController;
  late TextEditingController _newProductPriceController;

  String? _modalError;
  String? _modalSuccess;

  late TabController _tabController;
  final List<String> _tabTitles = ['Available', 'Sold', 'Returned'];

  final FocusNode _searchFocusNode = FocusNode();

  Map<String, dynamic>? _foundInSoldStock;
  bool _showingSoldStockWarning = false;

  // ───────────────────────── lifecycle ─────────────────────────

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _productSearchController = TextEditingController();
    _priceChangeController = TextEditingController();
    _newProductNameController = TextEditingController();
    _newProductPriceController = TextEditingController();

    _tabController = TabController(length: widget.isAdmin ? 3 : 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _foundInSoldStock = null;
        _showingSoldStockWarning = false;
      });
    });

    _loadExistingProducts();
    if (widget.shops.isNotEmpty) {
      _shops = List<Map<String, dynamic>>.from(widget.shops);
    } else {
      _loadShops();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _productSearchController.dispose();
    _priceChangeController.dispose();
    _newProductNameController.dispose();
    _newProductPriceController.dispose();
    _disposeImeiControllers();
    super.dispose();
  }

  void _disposeImeiControllers() {
    for (var c in _imeiControllers) {
      c.dispose();
    }
    _imeiControllers.clear();
  }

  // ───────────────────────── helpers ─────────────────────────

  List<QueryDocumentSnapshot> _readyCashOnly(
    List<QueryDocumentSnapshot> docs, {
    bool returned = false,
  }) {
    return docs.where((d) {
      final m = d.data() as Map<String, dynamic>;
      if (returned && m['stockType'] != _stockType) return false;
      if (widget.isAdmin && _adminShopFilter != null) {
        final sid = (m['shopId'] ?? m['originalShopId'])?.toString();
        return sid == _adminShopFilter;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _filterStocksBySearch(
    List<QueryDocumentSnapshot> stocks,
  ) {
    if (_searchQuery.isEmpty) {
      return stocks.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {...data, 'id': doc.id};
      }).toList();
    }

    final query = _searchQuery.toLowerCase().trim();
    final searchWords = query.split(' ').where((w) => w.isNotEmpty).toList();
    final result = <Map<String, dynamic>>[];

    for (final doc in stocks) {
      final data = doc.data() as Map<String, dynamic>;
      final productName = (data['productName'] as String? ?? '').toLowerCase();
      final productBrand = (data['productBrand'] as String? ?? '')
          .toLowerCase();
      final imei = (data['imei'] as String? ?? '').toLowerCase();
      final combinedText = '$productName $productBrand';

      bool allWordsFound = true;

      for (final word in searchWords) {
        final variations = <String>[word];

        if (word.contains('/')) {
          variations.add(word.replaceAll('/', ' '));
          variations.add(word.replaceAll('/', ''));
          variations.add(word.replaceAll('/', 'gb/'));
          variations.add(word.replaceAll('/', '/gb'));
        }
        if (word.endsWith('g') && word.length > 1) {
          variations.add(word.substring(0, word.length - 1));
        }
        if (word.endsWith('gb') && word.length > 2) {
          variations.add(word.replaceAll('gb', ''));
        }

        bool wordFound = variations.any((v) => combinedText.contains(v));
        if (!wordFound && imei.contains(word)) wordFound = true;

        if (!wordFound) {
          allWordsFound = false;
          break;
        }
      }

      if (allWordsFound) result.add({...data, 'id': doc.id});
    }
    return result;
  }

  Future<Map<String, dynamic>?> _checkImeiInSoldStock(String imei) async {
    try {
      final snapshot = await _firestore
          .collection('ReadyCashPhone')
          .where('imei', isEqualTo: imei)
          .where('status', isEqualTo: 'sold')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return {...data, 'id': snapshot.docs.first.id};
      }
      return null;
    } catch (e) {
      debugPrint('Error checking sold stock: $e');
      return null;
    }
  }

  // ───────────────────────── loading ─────────────────────────

  Future<void> _loadShops() async {
    try {
      final snapshot = await _firestore.collection('Mobile_house_Shops').get();
      if (!mounted) return;
      setState(() {
        _shops = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['shopName'] ?? 'Unknown Shop',
            'address': data['address'] ?? '',
            'phone': data['phoneNumber'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      _showError('Error loading shops: $e');
    }
  }

  Future<void> _loadExistingProducts() async {
    try {
      setState(() => _isLoading = true);

      final snapshot = await _firestore.collection('phones').get();
      _productsByBrand.clear();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final brand = data['brand'] as String?;
        final productName = data['productName'] as String?;
        final price = data['price'];

        if (brand != null && productName != null && price != null) {
          double? priceDouble;
          if (price is int) {
            priceDouble = price.toDouble();
          } else if (price is double) {
            priceDouble = price;
          } else if (price is String) {
            priceDouble = double.tryParse(price);
          }

          if (priceDouble != null) {
            if (!_brands.contains(brand)) _brands.add(brand);
            _productsByBrand.putIfAbsent(brand, () => []);

            final idx = _productsByBrand[brand]!.indexWhere(
              (p) => p['productName'] == productName,
            );
            if (idx == -1) {
              _productsByBrand[brand]!.add({
                'id': doc.id,
                'productName': productName,
                'price': priceDouble,
              });
            } else {
              _productsByBrand[brand]![idx]['price'] = priceDouble;
            }
          }
        }
      }

      _brands.sort();
      for (var brand in _productsByBrand.keys) {
        _productsByBrand[brand]!.sort(
          (a, b) => (a['productName'] as String).compareTo(
            b['productName'] as String,
          ),
        );
      }
      if (mounted) setState(() {});
    } catch (e) {
      _showError('Failed to load products: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───────────────────────── add stock ─────────────────────────

  void _handleProductSelection(String? value) {
    if (value == 'add_new') {
      setState(() {
        _showAddProductForm = true;
        _selectedProduct = null;
        _showPriceChangeOption = false;
        _priceChangeController.clear();
        _productSearchController.clear();
        _clearModalMessages();
        _newProductNameController.clear();
        _newProductPriceController.clear();
      });
    } else {
      setState(() {
        _selectedProduct = value;
        _showAddProductForm = false;
        _productSearchController.text = value ?? '';
        _clearModalMessages();

        if (_selectedBrand != null && value != null) {
          final products = _productsByBrand[_selectedBrand!];
          if (products != null) {
            final product = products.firstWhere(
              (p) => p['productName'] == value,
              orElse: () => <String, dynamic>{},
            );
            if (product.isNotEmpty) {
              final price = product['price'];
              _originalProductPrice = price is double
                  ? price
                  : price is int
                  ? price.toDouble()
                  : 0.0;
              _showPriceChangeOption = true;
              _priceChangeController.text =
                  _originalProductPrice?.toStringAsFixed(0) ?? '';
            }
          }
        }
      });
    }
  }

  void _cancelAddNewProduct() {
    setState(() {
      _showAddProductForm = false;
      _newProductName = null;
      _newProductPrice = null;
      _productSearchController.clear();
      _newProductNameController.clear();
      _newProductPriceController.clear();
      _clearModalMessages();
    });
  }

  void _handleQuantityChange(String value) {
    final qty = int.tryParse(value);
    if (qty != null && qty > 0) {
      _disposeImeiControllers();
      setState(() {
        _quantity = qty;
        _imeiNumbers = List.filled(qty, '');
        for (int i = 0; i < qty; i++) {
          _imeiControllers.add(TextEditingController());
        }
        _clearModalMessages();
      });
    } else if (value.isEmpty) {
      _disposeImeiControllers();
      setState(() {
        _quantity = null;
        _imeiNumbers = [];
        _clearModalMessages();
      });
    }
  }

  Future<void> _saveNewProduct() async {
    if (_selectedBrand == null) {
      _showModalError('Please select a brand');
      return;
    }

    final productName = _newProductNameController.text.trim();
    final priceText = _newProductPriceController.text.trim();

    if (productName.isEmpty) {
      _showModalError('Please enter product name');
      return;
    }
    if (priceText.isEmpty) {
      _showModalError('Please enter product price');
      return;
    }
    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      _showModalError('Please enter valid price');
      return;
    }

    try {
      setState(() => _isLoading = true);

      await _firestore.collection('phones').add({
        'brand': _selectedBrand!,
        'productName': productName,
        'price': price,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _productsByBrand.putIfAbsent(_selectedBrand!, () => []);
      final idx = _productsByBrand[_selectedBrand!]!.indexWhere(
        (p) => p['productName'] == productName,
      );
      if (idx == -1) {
        _productsByBrand[_selectedBrand!]!.add({
          'id': 'temp',
          'productName': productName,
          'price': price,
        });
        _productsByBrand[_selectedBrand!]!.sort(
          (a, b) => (a['productName'] as String).compareTo(
            b['productName'] as String,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _showAddProductForm = false;
        _selectedProduct = productName;
        _originalProductPrice = price;
        _clearModalMessages();
        _showModalSuccess('Product "$productName" added successfully!');
        _newProductNameController.clear();
        _newProductPriceController.clear();
      });
    } catch (e) {
      _showModalError('Failed to add product: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveStock() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isLoading = true;
        _clearModalMessages();
      });

      if (_selectedBrand == null || _selectedBrand!.isEmpty) {
        _showModalError('Please select a brand');
        return;
      }

      String productName;
      double totalAmount;
      String? productId;

      if (_showAddProductForm) {
        final newProductName = _newProductNameController.text.trim();
        final newPriceText = _newProductPriceController.text.trim();

        if (newProductName.isEmpty) {
          _showModalError('Please enter product name');
          return;
        }
        if (newPriceText.isEmpty) {
          _showModalError('Please enter product price');
          return;
        }
        final newPrice = double.tryParse(newPriceText);
        if (newPrice == null || newPrice <= 0) {
          _showModalError('Please enter valid price');
          return;
        }

        productName = newProductName;
        totalAmount = newPrice;
        await _saveNewProduct();
        if (_selectedProduct == null) {
          _showModalError('Product not selected after creation');
          return;
        }
      } else {
        if (_selectedProduct == null || _selectedProduct!.isEmpty) {
          _showModalError('Please select a product');
          return;
        }

        final products = _productsByBrand[_selectedBrand!];
        if (products == null || products.isEmpty) {
          _showModalError('No products found for selected brand');
          return;
        }

        final product = products.firstWhere(
          (p) => p['productName'] == _selectedProduct,
          orElse: () => <String, dynamic>{},
        );
        if (product.isEmpty) {
          _showModalError('Selected product not found');
          return;
        }

        productName = product['productName'] as String;
        final productPriceTemp = product['price'];
        productId = product['id'] as String?;

        double basePrice = productPriceTemp is int
            ? productPriceTemp.toDouble()
            : productPriceTemp as double;
        totalAmount = basePrice;

        if (_showPriceChangeOption && _priceChangeController.text.isNotEmpty) {
          final newPrice = double.tryParse(_priceChangeController.text);
          if (newPrice != null && newPrice > 0) {
            totalAmount = newPrice;
            if (productId != null && productId != 'temp') {
              await _firestore.collection('phones').doc(productId).update({
                'price': totalAmount,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }

      if (_quantity == null || _quantity! <= 0) {
        _showModalError('Please enter valid quantity');
        return;
      }
      if (_imeiNumbers.length != _quantity) {
        _showModalError('IMEI numbers count does not match quantity');
        return;
      }

      for (int i = 0; i < _imeiNumbers.length; i++) {
        final imei = _imeiNumbers[i];
        if (imei.isEmpty) {
          _showModalError('Please enter IMEI number for item ${i + 1}');
          return;
        }
        if (imei.length < 15 || imei.length > 16) {
          _showModalError(
            'IMEI ${i + 1} must be 15-16 digits (${imei.length} entered)',
          );
          return;
        }
        if (!RegExp(r'^[0-9]+$').hasMatch(imei)) {
          _showModalError('IMEI ${i + 1} contains non-numeric characters');
          return;
        }
      }

      if (_imeiNumbers.toSet().length != _imeiNumbers.length) {
        _showModalError('Duplicate IMEI numbers found in this batch');
        return;
      }

      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        _showModalError('User not authenticated. Please log in again.');
        return;
      }

      String shopId;
      String shopName;
      if (widget.isAdmin) {
        if (_adminTargetShop == null) {
          _showModalError('Please select a shop');
          return;
        }
        shopId = _adminTargetShop!['id'] as String;
        shopName = _adminTargetShop!['name'] as String? ?? 'Unknown Shop';
      } else {
        shopId = user.shopId?.trim() ?? 'unknown_shop';
        shopName = user.shopName?.trim() ?? user.name.trim();
      }
      final uploadedBy = user.email.trim().isNotEmpty
          ? user.email.trim()
          : user.name.trim();
      final uploadedById = user.uid;

      try {
        for (String imei in _imeiNumbers) {
          final existing = await _firestore
              .collection('ReadyCashPhone')
              .where('imei', isEqualTo: imei)
              .limit(1)
              .get();
          if (existing.docs.isNotEmpty) {
            _showModalError(
              'IMEI ${_formatImeiForDisplay(imei)} already exists in stock database',
            );
            return;
          }
        }
      } catch (e) {
        debugPrint('IMEI check error: $e');
      }

      final savedCount = _imeiNumbers.length;
      final batch = _firestore.batch();

      for (final rawImei in _imeiNumbers) {
        final docRef = _firestore.collection('ReadyCashPhone').doc();
        batch.set(docRef, {
          'productBrand': _selectedBrand!.trim(),
          'productName': productName,
          'totalAmount': totalAmount,
          'imei': rawImei.trim(),
          'shopId': shopId,
          'shopName': shopName,
          'uploadedBy': uploadedBy,
          'uploadedById': uploadedById,
          'uploadedAt': FieldValue.serverTimestamp(),
          'ReadyCashStatus': 'available',
          'status': 'available',
          'shop': shopName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      if (!mounted) return;

      _showSuccess('Successfully added $savedCount phone(s) to stock!');
      _closeAddStockModal();
    } catch (e) {
      debugPrint('Save stock error: $e');
      _showModalError('Failed to save stock: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetAddStockForm() {
    setState(() {
      _selectedBrand = null;
      _selectedProduct = null;
      _newProductName = null;
      _newProductPrice = null;
      _quantity = null;
      _imeiNumbers = [];
      _showAddProductForm = false;
      _showPriceChangeOption = false;
      _originalProductPrice = null;
      _clearModalMessages();
    });

    _productSearchController.clear();
    _priceChangeController.clear();
    _newProductNameController.clear();
    _newProductPriceController.clear();
    _disposeImeiControllers();
    _formKey.currentState?.reset();
  }

  Future<void> _onAddPressed() async {
    if (widget.isAdmin) {
      if (_shops.isEmpty) {
        _showError('Shops not loaded yet. Please try again.');
        return;
      }
      final shop = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text(
            'Add stock to which shop?',
            style: TextStyle(fontSize: 15),
          ),
          children: _shops
              .map(
                (s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, s),
                  child: Row(
                    children: [
                      const Icon(Icons.store, size: 18, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s['name'] as String? ?? 'Unknown Shop',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      );
      if (shop == null) return;
      _adminTargetShop = shop;
    }
    _openAddStockModal();
  }

  void _openAddStockModal() {
    _resetAddStockForm();
    setState(() => _showAddStockModal = true);
  }

  void _closeAddStockModal() {
    setState(() => _showAddStockModal = false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _resetAddStockForm();
    });
  }

  // ───────────────────────── transfer (users only) ─────────────────────────

  Future<void> _transferToShop(
    String phoneId,
    Map<String, dynamic> phoneData,
    String newShopId,
    String newShopName,
  ) async {
    try {
      setState(() => _isLoading = true);

      final user = Provider.of<AuthProvider>(context, listen: false).user;

      await _firestore.collection('ReadyCashPhone').doc(phoneId).update({
        'shopId': newShopId,
        'shopName': newShopName,
        'transferredBy': user?.email ?? user?.name ?? 'Unknown',
        'transferredById': user?.uid ?? '',
        'transferredAt': FieldValue.serverTimestamp(),
        'previousShopId': phoneData['shopId'] as String? ?? '',
        'previousShopName':
            (phoneData['shopName'] ?? phoneData['shop'] ?? 'Unknown Shop')
                .toString(),
      });

      setState(() => _selectedPhoneForAction = null);
      _showSuccess('Phone transferred to $newShopName successfully!');
    } catch (e) {
      _showError('Failed to transfer phone: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───────────────────────── scanner ─────────────────────────

  Future<bool> _checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      if (status.isDenied) {
        final result = await Permission.camera.request();
        return result.isGranted;
      }
      return status.isGranted;
    } catch (e) {
      debugPrint('Permission error: $e');
      return false;
    }
  }

  Future<void> _openScannerForImeiField(int index) async {
    if (!await _checkCameraPermission()) {
      _showError('Camera permission required for scanning');
      return;
    }
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => OptimizedImeiScanner(
        title: 'Scan IMEI ${index + 1}',
        description: 'Scan barcode for IMEI ${index + 1}',
        onScanComplete: (imei) {
          if (index < _imeiNumbers.length) {
            setState(() {
              _imeiNumbers[index] = imei;
              if (index < _imeiControllers.length) {
                _imeiControllers[index].text = imei;
              }
            });
          }
        },
      ),
    );
  }

  Future<void> _openScannerForSearch() async {
    if (!await _checkCameraPermission()) {
      _showError('Camera permission required for scanning');
      return;
    }
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => OptimizedImeiScanner(
        title: 'Search IMEI',
        description: 'Scan IMEI to search in stock',
        onScanComplete: (imei) async {
          setState(() {
            _searchController.text = imei;
            _searchQuery = imei.toLowerCase();
            _foundInSoldStock = null;
            _showingSoldStockWarning = false;
          });

          final soldItem = await _checkImeiInSoldStock(imei);
          if (soldItem != null && mounted) {
            setState(() {
              _foundInSoldStock = soldItem;
              _showingSoldStockWarning = true;
            });
          }
        },
      ),
    );
  }

  // ───────────────────────── messages ─────────────────────────

  void _clearModalMessages() {
    setState(() {
      _modalError = null;
      _modalSuccess = null;
    });
  }

  void _showModalError(String message) {
    if (!mounted) return;
    setState(() {
      _modalError = message;
      _modalSuccess = null;
      _isLoading = false;
    });
  }

  void _showModalSuccess(String message) {
    if (!mounted) return;
    setState(() {
      _modalSuccess = message;
      _modalError = null;
    });
  }

  void _showError(String message) => _snack(message, Colors.red.shade700, 3);
  void _showSuccess(String message) =>
      _snack(message, Colors.green.shade700, 2);

  void _snack(String message, Color color, int seconds) {
    if (!mounted) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: color,
        duration: Duration(seconds: seconds),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ───────────────────────── formatting ─────────────────────────

  String _formatImeiForDisplay(String imei) {
    if (imei.isEmpty) return '';
    if (imei.length == 15) {
      return '${imei.substring(0, 6)} ${imei.substring(6, 12)} ${imei.substring(12)}';
    } else if (imei.length == 16) {
      return '${imei.substring(0, 8)} ${imei.substring(8)}';
    }
    return imei;
  }

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp == null) return 'N/A';
      if (timestamp is Timestamp) {
        return DateFormat('dd MMM yyyy').format(timestamp.toDate());
      }
      return timestamp.toString();
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatPrice(dynamic price) {
    final value = _parsePrice(price);
    return '₹${NumberFormat('#,##0').format(value)}';
  }

  double _parsePrice(dynamic price) {
    if (price == null) return 0;
    if (price is int) return price.toDouble();
    if (price is double) return price;
    if (price is String) return double.tryParse(price) ?? 0;
    return 0;
  }

  /// Sale price.
  double _totalAmount(Map<String, dynamic> d) {
    return _parsePrice(d['totalAmount']);
  }

  /// Amount returned to the customer — cost price for admin.
  double _amountReturnedToCustomer(Map<String, dynamic> d) {
    return _parsePrice(d['amountReturnedToCustomer']);
  }

  // ───────────────────────── shop info ─────────────────────────

  Map<String, String> _currentShopInfo(Map<String, dynamic>? phoneData) {
    final shopId = phoneData?['shopId']?.toString() ?? '';
    final match = _shops.firstWhere(
      (s) => s['id'].toString() == shopId,
      orElse: () => <String, dynamic>{},
    );
    return {
      'name':
          (match['name'] ??
                  phoneData?['shopName'] ??
                  phoneData?['shop'] ??
                  'Unknown Shop')
              .toString(),
      'address': (match['address'] ?? '').toString(),
      'phone': (match['phone'] ?? '').toString(),
    };
  }

  // ───────────────────────── sold warning ─────────────────────────

  Widget _buildSoldStockWarning() {
    if (_foundInSoldStock == null) return const SizedBox.shrink();

    final soldItem = _foundInSoldStock!;
    final productName = soldItem['productName'] as String? ?? 'Unknown';
    final productBrand = soldItem['productBrand'] as String? ?? 'Unknown';
    final soldAt = soldItem['soldAt'] ?? soldItem['updatedAt'];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: Colors.orange.shade700,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'IMEI Found in Sold Stock',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Brand: $productBrand',
                      style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                    ),
                    if (soldAt != null)
                      Text(
                        'Sold: ${_formatDate(soldAt)}',
                        style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 14),
                onPressed: () => _showSoldItemDetails(soldItem),
                tooltip: 'View details',
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSoldItemDetails(Map<String, dynamic> soldItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final productName = soldItem['productName'] as String? ?? 'Unknown';
        final productBrand = soldItem['productBrand'] as String? ?? 'Unknown';
        final imei = soldItem['imei'] as String? ?? 'N/A';
        final soldAmount = _totalAmount(soldItem);
        final amountReturned = _amountReturnedToCustomer(soldItem);
        final soldAt = soldItem['soldAt'] ?? soldItem['updatedAt'];
        final uploadedAt = soldItem['uploadedAt'] ?? soldItem['createdAt'];
        final uploadedBy = soldItem['uploadedBy'] ?? 'Unknown';
        final shopName =
            soldItem['shopName'] ?? soldItem['shop'] ?? 'Unknown Shop';

        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shopping_cart_checkout,
                        color: Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SOLD PHONE DETAILS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This phone was previously sold',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailItem('Product Name', productName),
                _buildDetailItem('Brand', productBrand),
                _buildDetailItem('IMEI', _formatImeiForDisplay(imei)),
                if (widget.isAdmin)
                  _buildDetailItem(
                    'Amount Returned',
                    _formatPrice(amountReturned),
                  ),
                _buildDetailItem('Total Amount', _formatPrice(soldAmount)),
                _buildDetailItem('Shop', shopName.toString()),
                if (uploadedAt != null)
                  _buildDetailItem('Added Date', _formatDate(uploadedAt)),
                if (soldAt != null)
                  _buildDetailItem('Sold Date', _formatDate(soldAt)),
                _buildDetailItem('Uploaded By', uploadedBy.toString()),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.black),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── add stock modal ─────────────────────────

  Widget _buildAddStockModal() {
    return AddStockModal(
      formKey: _formKey,
      selectedBrand: _selectedBrand,
      selectedProduct: _selectedProduct,
      newProductName: _newProductName,
      newProductPrice: _newProductPrice,
      quantity: _quantity,
      imeiNumbers: _imeiNumbers,
      imeiControllers: _imeiControllers,
      brands: _brands,
      productsByBrand: _productsByBrand,
      isLoading: _isLoading,
      showAddProductForm: _showAddProductForm,
      showPriceChangeOption: _showPriceChangeOption,
      originalProductPrice: _originalProductPrice,
      productSearchController: _productSearchController,
      priceChangeController: _priceChangeController,
      searchController: _searchController,
      newProductNameController: _newProductNameController,
      newProductPriceController: _newProductPriceController,
      modalError: _modalError,
      modalSuccess: _modalSuccess,
      onBrandChanged: (value) {
        setState(() {
          _selectedBrand = value;
          _selectedProduct = null;
          _showAddProductForm = false;
          _showPriceChangeOption = false;
          _newProductName = null;
          _newProductPrice = null;
          _productSearchController.clear();
          _priceChangeController.clear();
          _newProductNameController.clear();
          _newProductPriceController.clear();
          _clearModalMessages();
        });
      },
      onProductSelected: (value) => _handleProductSelection(value),
      onCancelAddNewProduct: _cancelAddNewProduct,
      onQuantityChanged: (value) => _handleQuantityChange(value),
      onOpenScannerForImeiField: (index) => _openScannerForImeiField(index),
      onClearModalMessages: _clearModalMessages,
      onCloseModal: _closeAddStockModal,
      onSaveStock: _saveStock,
      onSaveNewProduct: _saveNewProduct,
    );
  }

  // ───────────────────────── transfer modal (users only) ─────────────────────────

  Widget _buildActionModal() {
    if (_selectedPhoneForAction == null) return const SizedBox();

    final phone = _selectedPhoneForAction!;
    final productName = phone['productName'] as String? ?? 'Unknown';
    final productBrand = phone['productBrand'] as String? ?? 'Unknown';
    final imei = phone['imei'] as String? ?? 'N/A';
    final price = _totalAmount(phone);
    final currentShopId = phone['shopId'] as String? ?? '';
    final currentShopName =
        (phone['shopName'] ?? phone['shop'] ?? 'Unknown Shop').toString();
    final phoneId = phone['id'] as String? ?? '';

    final filteredShops = _shops
        .where((shop) => shop['id'] != currentShopId)
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transfer Phone',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () =>
                        setState(() => _selectedPhoneForAction = null),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Brand: $productBrand',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Spacer(),
                        Text(
                          _formatPrice(price),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IMEI: $imei',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current Shop: $currentShopName',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select shop to transfer to:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (filteredShops.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No other shops available for transfer',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredShops.length,
                    itemBuilder: (context, index) {
                      final shop = filteredShops[index];
                      final address = shop['address'] as String? ?? '';
                      return ListTile(
                        leading: const Icon(
                          Icons.store,
                          color: Colors.blue,
                          size: 18,
                        ),
                        title: Text(
                          shop['name'] as String? ?? 'Unknown Shop',
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: address.isNotEmpty
                            ? Text(
                                address,
                                style: const TextStyle(fontSize: 10),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: _isLoading
                            ? null
                            : () {
                                if (phoneId.isNotEmpty) {
                                  _transferToShop(
                                    phoneId,
                                    phone,
                                    shop['id'] as String? ?? '',
                                    shop['name'] as String? ?? 'Unknown Shop',
                                  );
                                } else {
                                  _showError(
                                    'Phone ID not found. Please try again.',
                                  );
                                }
                              },
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () =>
                                setState(() => _selectedPhoneForAction = null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── search / filters ─────────────────────────

  Widget _buildSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            labelText: 'Search by IMEI, model, specs',
            labelStyle: const TextStyle(fontSize: 13),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _foundInSoldStock = null;
                        _showingSoldStockWarning = false;
                      });
                      _searchFocusNode.unfocus();
                    },
                  ),
                Container(width: 1, height: 20, color: Colors.grey.shade300),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, size: 22),
                  onPressed: _openScannerForSearch,
                  tooltip: 'Scan IMEI to search',
                  color: Colors.blue,
                ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _showingSoldStockWarning ? Colors.orange : Colors.blue,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _showingSoldStockWarning ? Colors.orange : Colors.blue,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: const TextStyle(fontSize: 13, color: Colors.black),
          onChanged: (value) async {
            setState(() => _searchQuery = value);

            if (_showingSoldStockWarning) {
              setState(() {
                _foundInSoldStock = null;
                _showingSoldStockWarning = false;
              });
            }

            if (RegExp(r'^[0-9]+$').hasMatch(value) &&
                (value.length == 15 || value.length == 16)) {
              final soldItem = await _checkImeiInSoldStock(value);
              if (soldItem != null && mounted) {
                setState(() {
                  _foundInSoldStock = soldItem;
                  _showingSoldStockWarning = true;
                });
              }
            }
          },
          onSubmitted: (_) => _searchFocusNode.unfocus(),
        ),
        if (_showingSoldStockWarning && _foundInSoldStock != null)
          _buildSoldStockWarning(),
      ],
    );
  }

  Widget _buildAdminShopFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: DropdownButtonFormField<String?>(
        value: _adminShopFilter,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Shop',
          labelStyle: const TextStyle(fontSize: 12),
          prefixIcon: const Icon(Icons.store, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All Shops', style: TextStyle(fontSize: 13)),
          ),
          ..._shops.map(
            (s) => DropdownMenuItem<String?>(
              value: s['id'] as String?,
              child: Text(
                s['name'] as String? ?? 'Unknown Shop',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: (v) => setState(() => _adminShopFilter = v),
      ),
    );
  }

  Widget _buildQuickScanButton() {
    return FloatingActionButton.extended(
      onPressed: _openScannerForSearch,
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text('Scan'),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      elevation: 4,
    );
  }

  // ───────────────────────── stock list ─────────────────────────

  Widget _centerMessage(IconData icon, String title, {String? sub}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 50, color: Colors.grey),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }

  Widget _buildStockList(String type) {
    final user = Provider.of<AuthProvider>(context).user;
    final currentShopId = user?.shopId;
    final isReturned = type == 'returned';
    final isSoldTab = type == 'sold';
    final isAvailableTab = type == 'available';

    final Query query;
    if (isReturned) {
      query = _firestore.collection('phoneReturns');
    } else if (isSoldTab) {
      query = _firestore
          .collection('ReadyCashPhone')
          .where('status', isEqualTo: 'sold');
    } else {
      query = _firestore
          .collection('ReadyCashPhone')
          .where('ReadyCashStatus', isEqualTo: 'available');
    }

    final Color themeColor = isReturned
        ? Colors.orange
        : type == 'available'
        ? Colors.green
        : Colors.blue;

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Error loading data: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = _readyCashOnly(snapshot.data!.docs, returned: isReturned);

        if (docs.isEmpty) {
          if (isReturned) {
            return _centerMessage(
              Icons.assignment_return,
              'No returned phones',
              sub: 'All shops',
            );
          }
          if (type == 'available') {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2, size: 50, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'No available phones',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  if (widget.isAdmin)
                    ElevatedButton.icon(
                      onPressed: _onAddPressed,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Add First Phone',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            );
          }
          return _centerMessage(Icons.shopping_cart_checkout, 'No sold phones');
        }

        final sortField = isReturned
            ? 'returnedAt'
            : isSoldTab
            ? 'soldAt'
            : 'uploadedAt';
        docs.sort((a, b) {
          final aMap = a.data() as Map<String, dynamic>;
          final aDate = aMap[sortField] ?? aMap['createdAt'];
          final bMap = b.data() as Map<String, dynamic>;
          final bDate = bMap[sortField] ?? bMap['createdAt'];
          if (aDate is Timestamp && bDate is Timestamp) {
            return bDate.compareTo(aDate);
          }
          return 0;
        });

        final filtered = _filterStocksBySearch(docs);

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 50, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text(
                  'No matching items',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                if (_showingSoldStockWarning && type == 'available')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'This IMEI was found in sold stock. Check the warning above for details.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade600,
                      ),
                    ),
                  )
                else
                  Text(
                    'Try different search',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          );
        }

        // Totals:
        //   User  -> sum of totalAmount
        //   Admin -> sum of totalAmount + sum of amountReturnedToCustomer
        double totalValue = 0;
        double totalAmountReturned = 0;
        final Map<String, Map<String, dynamic>> brandStats = {};

        for (final data in filtered) {
          final sale = _totalAmount(data);
          totalValue += sale;
          if (widget.isAdmin) {
            totalAmountReturned += _amountReturnedToCustomer(data);
          }
          final brand = data['productBrand'] as String? ?? 'Unknown';
          brandStats.putIfAbsent(brand, () => {'count': 0, 'value': 0.0});
          brandStats[brand]!['count'] = brandStats[brand]!['count'] + 1;
          brandStats[brand]!['value'] = brandStats[brand]!['value'] + sale;
        }

        final statTitle = isReturned
            ? 'Returned Value'
            : type == 'available'
            ? 'Available Value'
            : 'Sold Value';

        final statIcon = isReturned
            ? Icons.assignment_return
            : type == 'available'
            ? Icons.inventory
            : Icons.shopping_cart_checkout;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        statTitle,
                        _formatPrice(totalValue),
                        '${filtered.length} phones',
                        themeColor,
                        statIcon,
                        extra: widget.isAdmin
                            ? 'Amount returned: ${_formatPrice(totalAmountReturned)}'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Brands',
                        '${brandStats.length}',
                        'Varieties',
                        Colors.purple,
                        Icons.category,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isReturned ? 'Returned by Brand' : 'Brand-wise Summary',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: brandStats.length,
                      itemBuilder: (context, index) {
                        final brand = brandStats.keys.toList()[index];
                        final stats = brandStats[brand]!;
                        return Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: themeColor.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                brand,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${stats['count']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: themeColor,
                                ),
                              ),
                              Text(
                                _formatPrice(stats['value']),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: themeColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${isReturned ? 'Returned Phones' : 'Phones'}: ${filtered.length}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (type == 'available')
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        onPressed: _openScannerForSearch,
                        tooltip: 'Scan IMEI to search',
                      ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final stock = filtered[index];

                if (isReturned) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: _buildReturnedPhoneCard(
                      productName: stock['productName'] ?? 'Unknown',
                      productBrand: stock['productBrand'] ?? 'Unknown',
                      imei: stock['imei'] ?? 'N/A',
                      price: _totalAmount(stock),
                      amountReturned: widget.isAdmin
                          ? _amountReturnedToCustomer(stock)
                          : null,
                      returnedAt: stock['returnedAt'],
                      returnedBy: stock['returnedBy'] ?? 'Unknown',
                      originalShopName:
                          stock['originalShopName'] ?? 'Unknown Shop',
                    ),
                  );
                }

                final imei = stock['imei'] as String? ?? 'N/A';
                final phoneId = stock['id'] as String? ?? '';
                final isAvailableCard = type == 'available';

                final isOwnShop =
                    currentShopId != null &&
                    stock['shopId']?.toString() == currentShopId;

                // Sell: user only, own shop, available. Billing uses totalAmount.
                final VoidCallback? onSell =
                    (isAvailableCard && !widget.isAdmin && isOwnShop)
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReadyCashBillFormScreen(
                              phoneData: {
                                ...stock,
                                'totalAmount': _totalAmount(stock),
                              },
                              imei: imei,
                              phoneId: phoneId,
                            ),
                          ),
                        ).then((success) {
                          if (success == true && mounted) setState(() {});
                        });
                      }
                    : null;

                // Transfer: user only, own shop, available.
                final VoidCallback? onTransfer =
                    (isAvailableCard && !widget.isAdmin && isOwnShop)
                    ? () {
                        setState(() {
                          _selectedPhoneForAction = {...stock, 'id': phoneId};
                        });
                      }
                    : null;

                // Pricing:
                //   User  -> totalAmount (labelled Selling Price / Sold Amount)
                //   Admin -> totalAmount (main) + amountReturnedToCustomer (secondary)
                final bool userView = !widget.isAdmin;
                final double shownPrice = _totalAmount(stock);
                final String? shownPriceLabel = userView
                    ? (isSoldTab ? 'Sold Amount' : 'Selling Price')
                    : null;
                final double? shownAmountReturned = widget.isAdmin
                    ? _amountReturnedToCustomer(stock)
                    : null;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: _buildPhoneCard(
                    productName: stock['productName'] as String? ?? 'Unknown',
                    productBrand: stock['productBrand'] as String? ?? 'Unknown',
                    imei: imei,
                    price: shownPrice,
                    priceLabel: shownPriceLabel,
                    amountReturned: shownAmountReturned,
                    uploadedAt: stock['uploadedAt'] ?? stock['createdAt'],
                    soldAt: stock['soldAt'],
                    status: type,
                    phoneData: stock,
                    onSell: onSell,
                    onTransfer: onTransfer,
                  ),
                );
              }, childCount: filtered.length),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    Color color,
    IconData icon, {
    String? extra,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 9, color: color.withOpacity(0.7)),
          ),
          if (extra != null)
            Text(
              extra,
              style: TextStyle(fontSize: 9, color: color.withOpacity(0.7)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: SizedBox(
        height: 26,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            textStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildPhoneCard({
    required String productName,
    required String productBrand,
    required String imei,
    required dynamic price,
    String? priceLabel,
    double? amountReturned,
    required dynamic uploadedAt,
    dynamic soldAt,
    required String status,
    Map<String, dynamic>? phoneData,
    VoidCallback? onSell,
    VoidCallback? onTransfer,
  }) {
    final displayImei = _formatImeiForDisplay(imei);
    final isAvailable = status == 'available';

    final borderColor = isAvailable
        ? Colors.green.shade200
        : status == 'sold'
        ? Colors.blue.shade200
        : Colors.grey.shade300;
    final bgColor = status == 'sold' ? Colors.blue.shade50 : Colors.white;

    final transferredBy = phoneData?['transferredBy'] as String?;
    final transferredAt = phoneData?['transferredAt'];
    final shopInfo = _currentShopInfo(phoneData);

    final buttons = <Widget>[
      if (onSell != null) _actionButton('Sell', Colors.green, onSell),
      if (onTransfer != null)
        _actionButton('Transfer', Colors.blue, onTransfer),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isAvailable
                    ? Colors.green.shade100
                    : Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isAvailable ? Colors.green : Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              productName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    priceLabel != null
                        ? '$priceLabel: ${_formatPrice(price)}'
                        : _formatPrice(price),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    productBrand,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (amountReturned != null && amountReturned > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Amount returned: ${_formatPrice(amountReturned)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 3),
            Text(
              'IMEI: $displayImei',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
                fontFamily: 'Monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (phoneData?['billNumber'] != null) ...[
              const SizedBox(height: 3),
              Text(
                'Bill: ${phoneData!['billNumber']}'
                '${phoneData['customerName'] != null ? '  •  ${phoneData['customerName']}' : ''}',
                style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store, size: 11, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          shopInfo['name']!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (shopInfo['address']!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 10,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            shopInfo['address']!,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (shopInfo['phone']!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 10,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          shopInfo['phone']!,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (transferredBy != null && transferredAt != null) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    size: 10,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Transferred by $transferredBy on ${_formatDate(transferredAt)}',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.orange.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 3),
            Text(
              'Added: ${_formatDate(uploadedAt)}',
              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
            ),
            if (status == 'sold' && soldAt != null)
              Text(
                'Sold: ${_formatDate(soldAt)}',
                style: TextStyle(fontSize: 8, color: Colors.grey[600]),
              ),
            if (isAvailable && buttons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Divider(height: 1, color: Colors.grey),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        for (int i = 0; i < buttons.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          buttons[i],
                        ],
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnedPhoneCard({
    required String productName,
    required String productBrand,
    required String imei,
    required dynamic price,
    double? amountReturned,
    required dynamic returnedAt,
    required String returnedBy,
    required String originalShopName,
  }) {
    final displayImei = _formatImeiForDisplay(imei);

    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'RETURNED',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              productName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatPrice(price),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    productBrand,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (amountReturned != null && amountReturned > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Amount returned: ${_formatPrice(amountReturned)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              'IMEI: $displayImei',
              style: const TextStyle(
                fontSize: 9,
                color: Colors.black54,
                fontFamily: 'Monospace',
              ),
            ),
            const SizedBox(height: 2),
            _smallInfoRow(Icons.store, originalShopName),
            _smallInfoRow(Icons.assignment_return, _formatDate(returnedAt)),
            _smallInfoRow(Icons.person, returnedBy),
          ],
        ),
      ),
    );
  }

  Widget _smallInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 10, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 8, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final currentShopId = user?.shopId;
    final needsShop = !widget.isAdmin && currentShopId == null;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Text(
                widget.isAdmin
                    ? 'Ready Cash Stock (Admin)'
                    : 'Ready Cash Phone Stock',
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (widget.isAdmin)
                  Container(
                    height: 40,
                    margin: const EdgeInsets.all(3),
                    alignment: Alignment.center,
                    child: ElevatedButton.icon(
                      onPressed: _onAddPressed,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
              ],
              centerTitle: true,
              toolbarHeight: 56,
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : needsShop
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 40),
                        SizedBox(height: 12),
                        Text(
                          'Shop not found',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        color: Colors.white,
                        child: SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: TabBar(
                            controller: _tabController,
                            labelColor: Colors.green,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Colors.green,
                            indicatorWeight: 3,
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            unselectedLabelStyle: const TextStyle(fontSize: 12),
                            labelPadding: EdgeInsets.zero,
                            tabs: [
                              _tab(Icons.inventory, _tabTitles[0]),
                              _tab(Icons.shopping_cart_checkout, _tabTitles[1]),
                              if (widget.isAdmin)
                                _tab(Icons.assignment_return, _tabTitles[2]),
                            ],
                          ),
                        ),
                      ),
                      if (widget.isAdmin) _buildAdminShopFilter(),
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.white,
                        child: _buildSearchField(),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildStockList('available'),
                            _buildStockList('sold'),
                            if (widget.isAdmin) _buildStockList('returned'),
                          ],
                        ),
                      ),
                    ],
                  ),
            floatingActionButton: _buildQuickScanButton(),
          ),
          if (_showAddStockModal || _selectedPhoneForAction != null)
            Container(
              color: Colors.black.withOpacity(0.5),
              width: double.infinity,
              height: double.infinity,
            ),
          if (_showAddStockModal) _buildAddStockModal(),
          if (_selectedPhoneForAction != null) _buildActionModal(),
        ],
      ),
    );
  }

  Widget _tab(IconData icon, String title) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text(title, overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
        ],
      ),
    );
  }
}
