import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sales_stock/screens/user/bill_form.dart';
import 'package:sales_stock/screens/user/stock_check_screen.dart';
import '../../providers/auth_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import './add_stock_modal.dart';

class PhoneStockScreen extends StatefulWidget {
  const PhoneStockScreen({super.key});

  @override
  State<PhoneStockScreen> createState() => _PhoneStockScreenState();
}

class _PhoneStockScreenState extends State<PhoneStockScreen>
    with SingleTickerProviderStateMixin {
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
  ];
  final Map<String, List<Map<String, dynamic>>> _productsByBrand = {};
  bool _isLoading = false;
  bool _showAddProductForm = false;
  bool _showAddStockModal = false;

  List<Map<String, dynamic>> _shops = [];
  Map<String, dynamic>? _selectedPhoneForAction;
  String _selectedAction = 'sell';

  late TextEditingController _productSearchController;
  List<Map<String, dynamic>> _filteredProducts = [];

  double? _originalProductPrice;
  bool _showPriceChangeOption = false;
  late TextEditingController _priceChangeController;

  late TextEditingController _newProductNameController;
  late TextEditingController _newProductPriceController;

  String? _modalError;
  String? _modalSuccess;

  late TabController _tabController;
  int _currentTabIndex = 0;
  final List<String> _tabTitles = ['Available', 'Sold', 'Returned'];

  final FocusNode _searchFocusNode = FocusNode();

  Map<String, dynamic>? _foundInSoldStock;
  bool _showingSoldStockWarning = false;

  List<Map<String, dynamic>> _filterStocksBySearch(
    List<QueryDocumentSnapshot> stocks,
  ) {
    if (_searchQuery.isEmpty) {
      return stocks.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {...data, 'id': doc.id}; // Ensure ID is always included
      }).toList();
    }

    final query = _searchQuery.toLowerCase().trim();
    final result = <Map<String, dynamic>>[];

    for (final doc in stocks) {
      final data = doc.data() as Map<String, dynamic>;
      final productName = (data['productName'] as String? ?? '').toLowerCase();
      final productBrand = (data['productBrand'] as String? ?? '')
          .toLowerCase();
      final imei = (data['imei'] as String? ?? '').toLowerCase();
      final combinedText = '$productName $productBrand';

      final searchWords = query.split(' ').where((w) => w.isNotEmpty).toList();

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

        if (word.toLowerCase().endsWith('gb') && word.length > 2) {
          variations.add(word.toLowerCase().replaceAll('gb', ''));
        }

        bool wordFound = false;
        for (final variation in variations) {
          if (combinedText.contains(variation)) {
            wordFound = true;
            break;
          }
        }

        if (!wordFound && imei.contains(word)) {
          wordFound = true;
        }

        if (!wordFound) {
          allWordsFound = false;
          break;
        }
      }

      if (allWordsFound) {
        result.add({...data, 'id': doc.id});
      }
    }

    return result;
  }

  Future<Map<String, dynamic>?> _checkImeiInSoldStock(String imei) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      final currentShopId = user?.shopId;

      if (currentShopId == null) return null;

      final snapshot = await FirebaseFirestore.instance
          .collection('phoneStock')
          .where('shopId', isEqualTo: currentShopId)
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
      print('Error checking sold stock: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _productSearchController = TextEditingController();
    _priceChangeController = TextEditingController();
    _newProductNameController = TextEditingController();
    _newProductPriceController = TextEditingController();

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
        _foundInSoldStock = null;
        _showingSoldStockWarning = false;
      });
    });
    _loadExistingProducts();
    _loadShops();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocusNode.dispose();
    _disposeAllControllers();
    super.dispose();
  }

  void _disposeAllControllers() {
    _searchController.dispose();
    _productSearchController.dispose();
    _priceChangeController.dispose();
    _newProductNameController.dispose();
    _newProductPriceController.dispose();
    _disposeImeiControllers();
  }

  void _disposeImeiControllers() {
    for (var controller in _imeiControllers) {
      controller.dispose();
    }
    _imeiControllers.clear();
  }

  Future<void> _loadShops() async {
    try {
      final snapshot = await _firestore.collection('Mobile_house_Shops').get();
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
            if (!_brands.contains(brand)) {
              _brands.add(brand);
            }

            if (!_productsByBrand.containsKey(brand)) {
              _productsByBrand[brand] = [];
            }

            final existingProductIndex = _productsByBrand[brand]!.indexWhere(
              (p) => p['productName'] == productName,
            );

            if (existingProductIndex == -1) {
              _productsByBrand[brand]!.add({
                'id': doc.id,
                'productName': productName,
                'price': priceDouble,
              });
            } else {
              _productsByBrand[brand]![existingProductIndex]['price'] =
                  priceDouble;
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

      setState(() {});
    } catch (e) {
      _showError('Failed to load products: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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

      final newProduct = {
        'brand': _selectedBrand!,
        'productName': productName,
        'price': price,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('phones').add(newProduct);

      if (!_productsByBrand.containsKey(_selectedBrand!)) {
        _productsByBrand[_selectedBrand!] = [];
      }

      final existingProductIndex = _productsByBrand[_selectedBrand!]!
          .indexWhere((p) => p['productName'] == productName);

      if (existingProductIndex == -1) {
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveStock() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
      double productPrice;
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
        productPrice = newPrice;
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

        if (_showPriceChangeOption && _priceChangeController.text.isNotEmpty) {
          final newPrice = double.tryParse(_priceChangeController.text);
          if (newPrice != null && newPrice > 0) {
            productPrice = newPrice;
            if (productId != null && productId != 'temp') {
              await _firestore.collection('phones').doc(productId).update({
                'price': productPrice,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } else {
            productPrice = productPriceTemp is int
                ? productPriceTemp.toDouble()
                : productPriceTemp as double;
          }
        } else {
          productPrice = productPriceTemp is int
              ? productPriceTemp.toDouble()
              : productPriceTemp as double;
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

      final uniqueImeis = _imeiNumbers.toSet();
      if (uniqueImeis.length != _imeiNumbers.length) {
        _showModalError('Duplicate IMEI numbers found in this batch');
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        _showModalError('User not authenticated. Please log in again.');
        return;
      }

      final shopId = user.shopId?.trim() ?? 'unknown_shop';
      final shopName =
          user.shopName?.trim() ?? user.name.trim() ?? 'Unknown Shop';
      final uploadedBy =
          user.email.trim() ?? user.name.trim() ?? 'Unknown User';
      final uploadedById = user.uid;

      try {
        for (String imei in _imeiNumbers) {
          final existingQuery = await _firestore
              .collection('phoneStock')
              .where('imei', isEqualTo: imei)
              .limit(1)
              .get();

          if (existingQuery.docs.isNotEmpty) {
            _showModalError(
              'IMEI ${_formatImeiForDisplay(imei)} already exists in stock database',
            );
            return;
          }
        }
      } catch (e) {
        print('IMEI check error: $e');
      }

      final savedCount = _imeiNumbers.length;
      final batch = _firestore.batch();

      for (int i = 0; i < _imeiNumbers.length; i++) {
        final imei = _imeiNumbers[i].trim();

        final stockData = {
          'productBrand': _selectedBrand!.trim(),
          'productName': productName,
          'productPrice': productPrice,
          'imei': imei,
          'shopId': shopId,
          'shopName': shopName,
          'uploadedBy': uploadedBy,
          'uploadedById': uploadedById,
          'uploadedAt': FieldValue.serverTimestamp(),
          'status': 'available',
          'createdAt': FieldValue.serverTimestamp(),
        };

        final docRef = _firestore.collection('phoneStock').doc();
        batch.set(docRef, stockData);
      }

      await batch.commit();

      if (!mounted) return;

      _showSuccess('Successfully added $savedCount phone(s) to stock!');

      _closeAddStockModal();
    } catch (e) {
      print('Save stock error: $e');
      _showModalError('Failed to save stock: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

    if (_formKey.currentState != null) {
      _formKey.currentState!.reset();
    }
  }

  void _openAddStockModal() {
    _resetAddStockForm();
    setState(() {
      _showAddStockModal = true;
    });
  }

  void _closeAddStockModal() {
    setState(() {
      _showAddStockModal = false;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _resetAddStockForm();
      }
    });
  }

  Future<void> _markAsSold(
    String phoneId,
    Map<String, dynamic> phoneData,
  ) async {
    try {
      setState(() => _isLoading = true);

      await _firestore.collection('phoneStock').doc(phoneId).update({
        'status': 'sold',
        'soldAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _selectedPhoneForAction = null;
      });

      _showSuccess('Phone marked as sold successfully!');
    } catch (e) {
      _showError('Failed to mark as sold: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _transferToShop(
    String phoneId,
    Map<String, dynamic> phoneData,
    String newShopId,
    String newShopName,
  ) async {
    try {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      final currentShopId = phoneData['shopId'] as String? ?? '';
      final currentShopName =
          phoneData['shopName'] as String? ?? 'Unknown Shop';

      await _firestore.collection('phoneStock').doc(phoneId).update({
        'shopId': newShopId,
        'shopName': newShopName,
        'transferredBy': user?.email ?? user?.name ?? 'Unknown',
        'transferredById': user?.uid ?? '',
        'transferredAt': FieldValue.serverTimestamp(),
        'previousShopId': currentShopId,
        'previousShopName': currentShopName,
      });

      setState(() {
        _selectedPhoneForAction = null;
      });

      _showSuccess('Phone transferred to $newShopName successfully!');
    } catch (e) {
      _showError('Failed to transfer phone: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _returnPhone(
    String phoneId,
    Map<String, dynamic> phoneData,
  ) async {
    try {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      final returnData = {
        'phoneId': phoneId,
        'productBrand': phoneData['productBrand'] ?? 'Unknown',
        'productName': phoneData['productName'] ?? 'Unknown',
        'productPrice': phoneData['productPrice'] ?? 0,
        'imei': phoneData['imei'] ?? 'N/A',
        'originalShopId': phoneData['shopId'] ?? '',
        'originalShopName': phoneData['shopName'] ?? 'Unknown Shop',
        'returnedBy': user?.email ?? user?.name ?? 'Unknown',
        'returnedById': user?.uid ?? '',
        'returnedAt': FieldValue.serverTimestamp(),
        'reason': 'returned_to_inventory',
        'status': 'returned',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('phoneReturns').add(returnData);

      await _firestore.collection('phoneStock').doc(phoneId).delete();

      setState(() {
        _selectedPhoneForAction = null;
      });

      _showSuccess('Phone returned successfully!');
    } catch (e) {
      _showError('Failed to return phone: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      if (status.isDenied) {
        final result = await Permission.camera.request();
        return result.isGranted;
      }
      return status.isGranted;
    } catch (e) {
      print('Permission error: $e');
      return false;
    }
  }

  Future<void> _openScannerForImeiField(int index) async {
    if (!await _checkCameraPermission()) {
      _showError('Camera permission required for scanning');
      return;
    }

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

    showDialog(
      context: context,
      builder: (context) => OptimizedImeiScanner(
        title: 'Search IMEI',
        description: 'Scan IMEI to search in stock',
        onScanComplete: (imei) async {
          setState(() {
            _searchController.text = imei;
            _searchQuery = imei.toLowerCase();
          });

          // Clear previous sold stock warning
          setState(() {
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

  void _showError(String message) {
    if (!mounted) return;

    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatImeiForDisplay(String imei) {
    if (imei.isEmpty) return '';
    if (imei.length == 15) {
      return '${imei.substring(0, 6)} ${imei.substring(6, 12)} ${imei.substring(12)}';
    } else if (imei.length == 16) {
      return '${imei.substring(0, 8)} ${imei.substring(8)}';
    }
    return imei;
  }

  bool _isValidImei(String imei) {
    if (imei.isEmpty) return false;
    if (imei.length != 15 && imei.length != 16) return false;
    if (!RegExp(r'^[0-9]+$').hasMatch(imei)) return false;
    return true;
  }

  Widget _buildSoldStockWarning() {
    if (_foundInSoldStock == null) {
      return const SizedBox.shrink();
    }

    final soldItem = _foundInSoldStock!;
    final productName = soldItem['productName'] as String? ?? 'Unknown';
    final productBrand = soldItem['productBrand'] as String? ?? 'Unknown';
    final soldAt = soldItem['soldAt'];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
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
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'IMEI Found in Sold Stock',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Brand: $productBrand',
                      style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                    ),
                    if (soldAt != null)
                      Text(
                        'Sold: ${_formatDate(soldAt)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 16),
                onPressed: () {
                  _showSoldItemDetails(soldItem);
                },
                tooltip: 'View details',
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'This IMEI is not available in current stock (it has been sold).',
            style: TextStyle(fontSize: 10, color: Colors.orange.shade600),
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
        final price = soldItem['productPrice'];
        final soldAt = soldItem['soldAt'];
        final uploadedAt = soldItem['uploadedAt'];
        final uploadedBy = soldItem['uploadedBy'] ?? 'Unknown';

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
                _buildDetailItem('Price', _formatPrice(price)),
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
            width: 100,
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

  Widget _buildProductList() {
    final brandHasNoProducts =
        !_productsByBrand.containsKey(_selectedBrand!) ||
        (_productsByBrand[_selectedBrand!] ?? []).isEmpty;

    final searchHasNoResults =
        _productSearchController.text.isNotEmpty && _filteredProducts.isEmpty;

    final shouldShowAddNew = brandHasNoProducts || searchHasNoResults;

    return ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _filteredProducts.length + (shouldShowAddNew ? 1 : 0),
      itemBuilder: (context, index) {
        if (shouldShowAddNew && index == _filteredProducts.length) {
          return _buildAddNewProductTile();
        }

        final product = _filteredProducts[index];
        final productName = product['productName'] as String? ?? '';
        final price = product['price'];
        String priceText = '';

        if (price is double) {
          priceText = '₹${price.toStringAsFixed(0)}';
        } else if (price is int) {
          priceText = '₹$price';
        }

        return ListTile(
          title: Text(
            productName,
            style: const TextStyle(fontSize: 12, color: Colors.black),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            priceText,
            style: const TextStyle(fontSize: 10, color: Colors.green),
          ),
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          onTap: () {
            _handleProductSelection(productName);
          },
          trailing: _selectedProduct == productName
              ? const Icon(Icons.check, color: Colors.green, size: 16)
              : null,
        );
      },
    );
  }

  Widget _buildAddNewProductTile() {
    String subtitleText = '';

    if (!_productsByBrand.containsKey(_selectedBrand!) ||
        (_productsByBrand[_selectedBrand!] ?? []).isEmpty) {
      subtitleText = 'No products found for this brand';
    } else if (_productSearchController.text.isNotEmpty &&
        _filteredProducts.isEmpty) {
      subtitleText = 'No matching products found';
    }

    return ListTile(
      leading: const Icon(Icons.add, color: Colors.green, size: 18),
      title: const Text(
        'Add New Product...',
        style: TextStyle(fontSize: 12, color: Colors.black),
      ),
      subtitle: subtitleText.isNotEmpty
          ? Text(
              subtitleText,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            )
          : null,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onTap: () {
        _handleProductSelection('add_new');
      },
    );
  }

  Widget _buildProductSearchDropdown() {
    if (_selectedBrand == null) return const SizedBox();

    if (_showAddProductForm) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Text(
                  'Adding New Product',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'Enter product details below. Product will be saved to database.',
              style: TextStyle(fontSize: 10, color: Colors.blue),
            ),
          ],
        ),
      );
    }

    final products = _productsByBrand[_selectedBrand!] ?? [];
    final searchText = _productSearchController.text.toLowerCase();

    if (searchText.isNotEmpty) {
      _filteredProducts = products.where((product) {
        final productName = product['productName'] as String? ?? '';
        return productName.toLowerCase().contains(searchText);
      }).toList();
    } else {
      _filteredProducts = List.from(products);
    }

    return Column(
      children: [
        TextField(
          controller: _productSearchController,
          decoration: InputDecoration(
            labelText: 'Search Product',
            labelStyle: const TextStyle(fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _selectedProduct != null && _selectedProduct!.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      setState(() {
                        _selectedProduct = null;
                        _productSearchController.clear();
                        _showPriceChangeOption = false;
                        _originalProductPrice = null;
                        _priceChangeController.clear();
                        _clearModalMessages();
                      });
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            hintText: _selectedProduct ?? 'Search or select product',
          ),
          style: const TextStyle(fontSize: 12, color: Colors.black),
          onChanged: (value) {
            setState(() {
              if (_selectedProduct != null && value != _selectedProduct) {
                _selectedProduct = null;
                _showPriceChangeOption = false;
                _originalProductPrice = null;
                _priceChangeController.clear();
              }
              _clearModalMessages();
            });
          },
          onTap: () {
            if (_selectedProduct != null &&
                _productSearchController.text == _selectedProduct) {
              _productSearchController.clear();
              setState(() {
                _clearModalMessages();
              });
            }
          },
        ),
        const SizedBox(height: 8),

        if (_modalSuccess != null && _modalSuccess!.contains('Product added'))
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _modalSuccess!,
                    style: const TextStyle(fontSize: 11, color: Colors.green),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),

        if (_selectedProduct == null ||
            _productSearchController.text.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildProductList(),
          ),

        if (_selectedProduct != null && _productSearchController.text.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Product:',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedProduct!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_originalProductPrice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Price: ${_formatPrice(_originalProductPrice)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () {
                    setState(() {
                      _selectedProduct = null;
                      _showPriceChangeOption = false;
                      _originalProductPrice = null;
                      _priceChangeController.clear();
                      _productSearchController.clear();
                    });
                  },
                  tooltip: 'Change product',
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildImeiInputField(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: index < _imeiControllers.length
                  ? _imeiControllers[index]
                  : null,
              decoration: InputDecoration(
                labelText: 'IMEI ${index + 1} *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.confirmation_number, size: 18),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index < _imeiNumbers.length &&
                        _imeiNumbers[index].isNotEmpty)
                      Icon(
                        _imeiNumbers[index].length >= 15
                            ? Icons.check_circle
                            : Icons.warning,
                        color: _imeiNumbers[index].length >= 15
                            ? Colors.green
                            : Colors.orange,
                        size: 16,
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      onPressed: () => _openScannerForImeiField(index),
                      tooltip: 'Scan IMEI',
                      color: Colors.blue,
                    ),
                  ],
                ),
                labelStyle: const TextStyle(fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontSize: 12, color: Colors.black),
              onChanged: (value) {
                if (index < _imeiNumbers.length) {
                  setState(() {
                    _imeiNumbers[index] = value;
                    _clearModalMessages();
                  });
                }
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter IMEI';
                }
                final trimmedValue = value.trim();
                if (trimmedValue.length < 15) {
                  return 'IMEI must be at least 15 digits';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.content_copy, size: 18),
                onPressed: () {
                  if (index < _imeiNumbers.length &&
                      _imeiNumbers[index].isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: _imeiNumbers[index]));
                    _showSuccess('IMEI copied to clipboard');
                  }
                },
                tooltip: 'Copy IMEI',
                color: Colors.grey,
              ),
              if (index > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: () {
                    if (index > 0) {
                      final temp = _imeiNumbers[index];
                      _imeiNumbers[index] = _imeiNumbers[index - 1];
                      _imeiNumbers[index - 1] = temp;

                      final tempCtrl = _imeiControllers[index];
                      _imeiControllers[index] = _imeiControllers[index - 1];
                      _imeiControllers[index - 1] = tempCtrl;

                      setState(() {});
                    }
                  },
                  tooltip: 'Move up',
                  color: Colors.blue,
                ),
            ],
          ),
        ],
      ),
    );
  }

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
      onProductSelected: (value) {
        _handleProductSelection(value);
      },
      onCancelAddNewProduct: _cancelAddNewProduct,
      onQuantityChanged: (value) {
        _handleQuantityChange(value);
      },
      onOpenScannerForImeiField: (index) {
        _openScannerForImeiField(index);
      },
      onClearModalMessages: _clearModalMessages,
      onCloseModal: _closeAddStockModal,
      onSaveStock: _saveStock,
      onSaveNewProduct: _saveNewProduct,
    );
  }

  Widget _buildActionModal() {
    if (_selectedPhoneForAction == null) return const SizedBox();

    final phone = _selectedPhoneForAction!;
    final productName = phone['productName'] as String? ?? 'Unknown';
    final productBrand = phone['productBrand'] as String? ?? 'Unknown';
    final imei = phone['imei'] as String? ?? 'N/A';
    final price = phone['productPrice'];
    final currentShopId = phone['shopId'] as String? ?? '';
    final currentShopName = phone['shopName'] as String? ?? 'Unknown Shop';
    final phoneId = phone['id'] as String? ?? '';

    // Filter shops to exclude the current shop
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
                  Text(
                    _selectedAction == 'sell'
                        ? 'Sell Phone'
                        : _selectedAction == 'transfer'
                        ? 'Transfer Phone'
                        : 'Return Phone',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() => _selectedPhoneForAction = null);
                    },
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current Shop: $currentShopName',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (phoneId.isNotEmpty)
                      Text(
                        'Phone ID: ${phoneId.substring(0, 8)}...',
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (_selectedAction == 'sell') ...[
                const Text(
                  'Are you sure you want to mark this phone as sold?',
                  style: TextStyle(fontSize: 12),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _selectedPhoneForAction = null);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (phoneId.isNotEmpty) {
                                  _markAsSold(phoneId, phone);
                                } else {
                                  _showError(
                                    'Phone ID not found. Please try again.',
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Sell',
                                style: TextStyle(fontSize: 12),
                              ),
                      ),
                    ),
                  ],
                ),
              ] else if (_selectedAction == 'transfer') ...[
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
                          subtitle:
                              shop['address'] != null &&
                                  (shop['address'] as String).isNotEmpty
                              ? Text(
                                  shop['address'] as String,
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
                            : () {
                                setState(() => _selectedPhoneForAction = null);
                              },
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
              ] else if (_selectedAction == 'return') ...[
                const Text(
                  'Are you sure you want to return this phone?',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will remove the phone from available stock and create a return record.',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _selectedPhoneForAction = null);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (phoneId.isNotEmpty) {
                                  _returnPhone(phoneId, phone);
                                } else {
                                  _showError(
                                    'Phone ID not found. Please try again.',
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Return',
                                style: TextStyle(fontSize: 12),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

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
          onSubmitted: (value) {
            _searchFocusNode.unfocus();
          },
        ),

        if (_showingSoldStockWarning && _foundInSoldStock != null)
          _buildSoldStockWarning(),
      ],
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
    try {
      if (price == null) return '₹0';
      if (price is int) {
        return '₹${NumberFormat('#,##0').format(price)}';
      }
      if (price is double) {
        return '₹${NumberFormat('#,##0').format(price)}';
      }
      if (price is String) {
        final parsed = double.tryParse(price);
        if (parsed != null) {
          return '₹${NumberFormat('#,##0').format(parsed)}';
        }
      }
      return '₹0';
    } catch (e) {
      return '₹0';
    }
  }

  Widget _buildStockList(String type) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final currentShopId = user?.shopId;

    if (type == 'returned') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('phoneReturns')
            .where('originalShopId', isEqualTo: currentShopId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 32),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Error loading returned phones: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final returns = snapshot.data!.docs;

          if (returns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_return, size: 50, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'No returned phones',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Shop: ${user?.shopName ?? 'Unknown'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          returns.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['returnedAt'];
            final bDate = bData['returnedAt'];

            if (aDate == null || bDate == null) return 0;
            if (aDate is Timestamp && bDate is Timestamp) {
              return bDate.compareTo(aDate);
            }
            return 0;
          });

          final filteredReturns = _filterStocksBySearch(returns);

          if (filteredReturns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 50, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text(
                    'No matching returned items',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try different search',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          double totalValue = 0;
          int totalPhones = 0;
          final Map<String, Map<String, dynamic>> brandStats = {};

          for (final data in filteredReturns) {
            final price = _parsePrice(data['productPrice']);
            final brand = data['productBrand'] as String? ?? 'Unknown';

            totalPhones++;
            totalValue += price;

            if (!brandStats.containsKey(brand)) {
              brandStats[brand] = {'count': 0, 'value': 0.0};
            }

            brandStats[brand]!['count'] = brandStats[brand]!['count'] + 1;
            brandStats[brand]!['value'] = brandStats[brand]!['value'] + price;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Returned Value',
                        _formatPrice(totalValue),
                        '$totalPhones phones',
                        Colors.orange,
                        Icons.assignment_return,
                      ),
                    ),
                    const SizedBox(width: 10),
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

              if (brandStats.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Returned by Brand',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: brandStats.length,
                    itemBuilder: (context, index) {
                      final brand = brandStats.keys.toList()[index];
                      final stats = brandStats[brand]!;
                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              brand,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                              ),
                              maxLines: 1,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${stats['count']}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            Text(
                              _formatPrice(stats['value']),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Divider(),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Returned Phones: ${filteredReturns.length}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      'Shop: ${user?.shopName ?? 'Unknown'}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.1,
                  ),
                  itemCount: filteredReturns.length,
                  itemBuilder: (context, index) {
                    final returnData = filteredReturns[index];
                    final productName =
                        returnData['productName'] as String? ?? 'Unknown';
                    final productBrand =
                        returnData['productBrand'] as String? ?? 'Unknown';
                    final imei = returnData['imei'] as String? ?? 'N/A';
                    final price = returnData['productPrice'];
                    final returnedAt = returnData['returnedAt'];
                    final returnedBy = returnData['returnedBy'] ?? 'Unknown';
                    final reason =
                        returnData['reason'] ?? 'returned_to_inventory';
                    final originalShopName =
                        returnData['originalShopName'] ?? 'Unknown Shop';

                    return _buildReturnedPhoneCard(
                      productName: productName,
                      productBrand: productBrand,
                      imei: imei,
                      price: price,
                      returnedAt: returnedAt,
                      returnedBy: returnedBy,
                      reason: reason,
                      originalShopName: originalShopName,
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    } else {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('phoneStock')
            .where('shopId', isEqualTo: currentShopId)
            .where('status', isEqualTo: type)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 32),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Error loading data: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stocks = snapshot.data!.docs;

          if (stocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type == 'available'
                        ? Icons.inventory_2
                        : Icons.shopping_cart_checkout,
                    size: 50,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    type == 'available'
                        ? 'No available phones'
                        : 'No sold phones',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                  else if (type == 'available')
                    ElevatedButton.icon(
                      onPressed: _openAddStockModal,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Add First Phone',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          stocks.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['uploadedAt'];
            final bDate = bData['uploadedAt'];

            if (aDate == null || bDate == null) return 0;
            if (aDate is Timestamp && bDate is Timestamp) {
              return bDate.compareTo(aDate);
            }
            return 0;
          });

          final filteredStocks = _filterStocksBySearch(stocks);

          if (filteredStocks.isEmpty) {
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

          double totalValue = 0;
          int totalPhones = 0;
          final Map<String, Map<String, dynamic>> brandStats = {};

          for (final data in filteredStocks) {
            final price = _parsePrice(data['productPrice']);
            final brand = data['productBrand'] as String? ?? 'Unknown';

            totalPhones++;
            totalValue += price;

            if (!brandStats.containsKey(brand)) {
              brandStats[brand] = {'count': 0, 'value': 0.0};
            }

            brandStats[brand]!['count'] = brandStats[brand]!['count'] + 1;
            brandStats[brand]!['value'] = brandStats[brand]!['value'] + price;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        type == 'available' ? 'Available Value' : 'Sold Value',
                        _formatPrice(totalValue),
                        '$totalPhones phones',
                        type == 'available' ? Colors.green : Colors.blue,
                        type == 'available'
                            ? Icons.inventory
                            : Icons.shopping_cart_checkout,
                      ),
                    ),
                    const SizedBox(width: 10),
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

              if (brandStats.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Brand-wise Summary',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: brandStats.length,
                    itemBuilder: (context, index) {
                      final brand = brandStats.keys.toList()[index];
                      final stats = brandStats[brand]!;
                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: type == 'available'
                              ? Colors.green.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: type == 'available'
                                ? Colors.green.shade200
                                : Colors.blue.shade200,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              brand,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${stats['count']}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: type == 'available'
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            ),
                            Text(
                              _formatPrice(stats['value']),
                              style: TextStyle(
                                fontSize: 9,
                                color: type == 'available'
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Divider(),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Phones: ${filteredStocks.length}',
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

              const SizedBox(height: 8),

              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 200,
                  ),
                  itemCount: filteredStocks.length,
                  itemBuilder: (context, index) {
                    final stock = filteredStocks[index];
                    final productName =
                        stock['productName'] as String? ?? 'Unknown';
                    final productBrand =
                        stock['productBrand'] as String? ?? 'Unknown';
                    final imei = stock['imei'] as String? ?? 'N/A';
                    final price = stock['productPrice'];
                    final uploadedAt = stock['uploadedAt'];
                    final soldAt = stock['soldAt'];
                    final phoneId = stock['id'] as String? ?? '';

                    return _buildPhoneCard(
                      productName: productName,
                      productBrand: productBrand,
                      imei: imei,
                      price: price,
                      uploadedAt: uploadedAt,
                      soldAt: soldAt,
                      status: type,
                      onSell: type == 'available'
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BillFormScreen(
                                    phoneData: stock,
                                    imei: imei,
                                    phoneId: phoneId,
                                  ),
                                ),
                              ).then((success) {
                                if (success == true) {
                                  setState(() {});
                                }
                              });
                            }
                          : null,
                      onTransfer: type == 'available'
                          ? () {
                              setState(() {
                                _selectedPhoneForAction = {
                                  ...stock,
                                  'id': phoneId,
                                };
                                _selectedAction = 'transfer';
                              });
                            }
                          : null,
                      onReturn: type == 'available'
                          ? () {
                              setState(() {
                                _selectedPhoneForAction = {
                                  ...stock,
                                  'id': phoneId,
                                };
                                _selectedAction = 'return';
                              });
                            }
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    Color color,
    IconData icon,
  ) {
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
        ],
      ),
    );
  }

  Widget _buildPhoneCard({
    required String productName,
    required String productBrand,
    required String imei,
    required dynamic price,
    required dynamic uploadedAt,
    dynamic soldAt,
    required String status,
    VoidCallback? onSell,
    VoidCallback? onTransfer,
    VoidCallback? onReturn,
  }) {
    String displayImei = _formatImeiForDisplay(imei);

    Color borderColor;
    Color bgColor;

    switch (status) {
      case 'available':
        borderColor = Colors.green.shade200;
        bgColor = Colors.white;
        break;
      case 'sold':
        borderColor = Colors.blue.shade200;
        bgColor = Colors.blue.shade50;
        break;
      default:
        borderColor = Colors.grey.shade300;
        bgColor = Colors.white;
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 180),
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
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: status == 'available'
                    ? Colors.green.shade100
                    : status == 'sold'
                    ? Colors.blue.shade100
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: status == 'available'
                      ? Colors.green
                      : status == 'sold'
                      ? Colors.blue
                      : Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 4),

            SizedBox(
              height: 32,
              child: Text(
                productName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              _formatPrice(price),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            Text(
              productBrand,
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            SizedBox(
              height: 24,
              child: Text(
                'IMEI: $displayImei',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black,
                  fontFamily: 'Monospace',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            Text(
              'Added: ${_formatDate(uploadedAt)}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (status == 'sold' && soldAt != null)
              Text(
                'Sold: ${_formatDate(soldAt)}',
                style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            if (status == 'available' &&
                (onSell != null || onTransfer != null || onReturn != null))
              Column(
                children: [
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Colors.grey),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (onSell != null)
                        Expanded(
                          child: SizedBox(
                            height: 28,
                            child: ElevatedButton(
                              onPressed: onSell,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              child: const Text('Sell'),
                            ),
                          ),
                        ),
                      if (onSell != null && onTransfer != null)
                        const SizedBox(width: 4),
                      if (onTransfer != null)
                        Expanded(
                          child: SizedBox(
                            height: 28,
                            child: ElevatedButton(
                              onPressed: onTransfer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              child: const Text('Transfer'),
                            ),
                          ),
                        ),
                      if ((onSell != null || onTransfer != null) &&
                          onReturn != null)
                        const SizedBox(width: 4),
                      if (onReturn != null)
                        Expanded(
                          child: SizedBox(
                            height: 28,
                            child: ElevatedButton(
                              onPressed: onReturn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              child: const Text('Return'),
                            ),
                          ),
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

  Widget _buildReturnedPhoneCard({
    required String productName,
    required String productBrand,
    required String imei,
    required dynamic price,
    required dynamic returnedAt,
    required String returnedBy,
    required String reason,
    required String originalShopName,
  }) {
    String displayImei = _formatImeiForDisplay(imei);

    return Container(
      constraints: const BoxConstraints(minHeight: 180),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

            SizedBox(
              height: 32,
              child: Text(
                productName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              _formatPrice(price),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            Text(
              productBrand,
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            SizedBox(
              height: 24,
              child: Text(
                'IMEI: $displayImei',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black,
                  fontFamily: 'Monospace',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            Text(
              'Returned: ${_formatDate(returnedAt)}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'By: $returnedBy',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Shop: $originalShopName',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Reason: ${reason.replaceAll('_', ' ').toLowerCase()}',
              style: TextStyle(fontSize: 9, color: Colors.orange.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  double _parsePrice(dynamic price) {
    try {
      if (price == null) return 0;
      if (price is int) return price.toDouble();
      if (price is double) return price;
      if (price is String) {
        final parsed = double.tryParse(price);
        return parsed ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final currentShopId = user?.shopId;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('Phone Stock', style: TextStyle(fontSize: 16)),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                Container(
                  height: 40,
                  margin: const EdgeInsets.all(3),
                  alignment: Alignment.center,
                  child: ElevatedButton.icon(
                    onPressed: _openAddStockModal,
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
                : currentShopId == null
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
                        child: Column(
                          children: [
                            SizedBox(
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
                                unselectedLabelStyle: const TextStyle(
                                  fontSize: 12,
                                ),
                                labelPadding: EdgeInsets.zero,
                                tabs: [
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.inventory, size: 18),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _tabTitles[0],
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.shopping_cart_checkout,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _tabTitles[1],
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.assignment_return,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _tabTitles[2],
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

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
                            _buildStockList('returned'),
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
}
