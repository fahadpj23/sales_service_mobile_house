import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sales_stock/screens/user/sale/gst_accessories_sale_upload.dart';
import '../../../providers/auth_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class AccessoriesStockScreen extends StatefulWidget {
  const AccessoriesStockScreen({super.key});

  @override
  State<AccessoriesStockScreen> createState() => _AccessoriesStockScreenState();
}

class _AccessoriesStockScreenState extends State<AccessoriesStockScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  String _searchQuery = '';
  late TextEditingController _searchController;

  String? _selectedCategory;
  String? _selectedProduct;
  String? _newProductName;
  double? _newProductPrice;
  int? _quantity;
  String? _barcode;
  String? _supplier;
  DateTime? _purchaseDate;
  double? _purchasePrice;
  String? _location;

  late TextEditingController _productSearchController;
  late TextEditingController _newProductNameController;
  late TextEditingController _newProductPriceController;
  late TextEditingController _barcodeController;
  late TextEditingController _supplierController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _locationController;

  String? _modalError;
  String? _modalSuccess;
  bool _isLoading = false;
  bool _showAddProductForm = false;
  bool _showAddStockModal = false;

  late TabController _tabController;
  int _currentTabIndex = 0;
  final List<String> _tabTitles = ['Available', 'Sold']; // Removed 'Low Stock'

  final List<String> _categories = [
    'Charger',
    'Cable',
    'Case/Cover',
    'Screen Guard',
    'Power Bank',
    'Headphone',
    'Earphone',
    'Smart Watch',
    'Memory Card',
    'USB Drive',
    'Adapter',
    'Battery',
    'Stand',
    'Other',
  ];

  final Map<String, List<Map<String, dynamic>>> _productsByCategory = {};
  final Map<String, int> _minStockLevels = {};

  List<Map<String, dynamic>> _shops = [];
  Map<String, dynamic>? _selectedAccessoryForAction;
  String _selectedAction = 'sell';

  double? _originalProductPrice;
  bool _showPriceChangeOption = false;
  late TextEditingController _priceChangeController;
  late TextEditingController _minStockController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _productSearchController = TextEditingController();
    _priceChangeController = TextEditingController();
    _newProductNameController = TextEditingController();
    _newProductPriceController = TextEditingController();
    _barcodeController = TextEditingController();
    _supplierController = TextEditingController();
    _purchasePriceController = TextEditingController();
    _locationController = TextEditingController();
    _minStockController = TextEditingController();

    _tabController = TabController(length: 2, vsync: this); // Changed to 2 tabs
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });

    _loadExistingProducts();
    _loadShops();
    _loadMinStockLevels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _productSearchController.dispose();
    _priceChangeController.dispose();
    _newProductNameController.dispose();
    _newProductPriceController.dispose();
    _barcodeController.dispose();
    _supplierController.dispose();
    _purchasePriceController.dispose();
    _locationController.dispose();
    _minStockController.dispose();
    super.dispose();
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

      final snapshot = await _firestore.collection('accessories').get();

      _productsByCategory.clear();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String?;
        final productName = data['productName'] as String?;
        final price = data['price'];

        if (category != null && productName != null && price != null) {
          double? priceDouble;
          if (price is int) {
            priceDouble = price.toDouble();
          } else if (price is double) {
            priceDouble = price;
          } else if (price is String) {
            priceDouble = double.tryParse(price);
          }

          if (priceDouble != null) {
            if (!_categories.contains(category)) {
              // Don't add, just use existing categories
            }

            if (!_productsByCategory.containsKey(category)) {
              _productsByCategory[category] = [];
            }

            final existingProductIndex = _productsByCategory[category]!
                .indexWhere((p) => p['productName'] == productName);

            if (existingProductIndex == -1) {
              _productsByCategory[category]!.add({
                'id': doc.id,
                'productName': productName,
                'price': priceDouble,
                'minStock': data['minStock'] ?? 5,
              });
            } else {
              _productsByCategory[category]![existingProductIndex]['price'] =
                  priceDouble;
              _productsByCategory[category]![existingProductIndex]['minStock'] =
                  data['minStock'] ?? 5;
            }
          }
        }
      }

      for (var category in _productsByCategory.keys) {
        _productsByCategory[category]!.sort(
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

  Future<void> _loadMinStockLevels() async {
    try {
      final snapshot = await _firestore.collection('accessorySettings').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final productId = data['productId'] as String?;
        final minStock = data['minStock'] as int? ?? 5;
        if (productId != null) {
          _minStockLevels[productId] = minStock;
        }
      }
    } catch (e) {
      print('Error loading min stock levels: $e');
    }
  }

  Future<void> _saveNewProduct() async {
    if (_selectedCategory == null) {
      _showModalError('Please select a category');
      return;
    }

    final productName = _newProductNameController.text.trim();
    final priceText = _newProductPriceController.text.trim();
    final minStockText = _minStockController.text.trim();

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

    final minStock = int.tryParse(minStockText) ?? 5;

    try {
      setState(() => _isLoading = true);

      final newProduct = {
        'category': _selectedCategory!,
        'productName': productName,
        'price': price,
        'minStock': minStock,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('accessories').add(newProduct);

      if (!_productsByCategory.containsKey(_selectedCategory!)) {
        _productsByCategory[_selectedCategory!] = [];
      }

      final existingProductIndex = _productsByCategory[_selectedCategory!]!
          .indexWhere((p) => p['productName'] == productName);

      if (existingProductIndex == -1) {
        _productsByCategory[_selectedCategory!]!.add({
          'id': docRef.id,
          'productName': productName,
          'price': price,
          'minStock': minStock,
        });

        _productsByCategory[_selectedCategory!]!.sort(
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
        _minStockController.clear();
      });
    } catch (e) {
      _showModalError('Failed to add product: ${e.toString()}');
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
        _minStockController.clear();
      });
    } else {
      setState(() {
        _selectedProduct = value;
        _showAddProductForm = false;
        _productSearchController.text = value ?? '';
        _clearModalMessages();

        if (_selectedCategory != null && value != null) {
          final products = _productsByCategory[_selectedCategory!];
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
      _minStockController.clear();
      _clearModalMessages();
    });
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

      if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        _showModalError('Please select a category');
        return;
      }

      String productName;
      double productPrice;
      String? productId;
      int minStock = 5;

      if (_showAddProductForm) {
        final newProductName = _newProductNameController.text.trim();
        final newPriceText = _newProductPriceController.text.trim();
        final minStockText = _minStockController.text.trim();

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

        minStock = int.tryParse(minStockText) ?? 5;
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

        final products = _productsByCategory[_selectedCategory!];
        if (products == null || products.isEmpty) {
          _showModalError('No products found for selected category');
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
        minStock = product['minStock'] as int? ?? 5;

        if (_showPriceChangeOption && _priceChangeController.text.isNotEmpty) {
          final newPrice = double.tryParse(_priceChangeController.text);
          if (newPrice != null && newPrice > 0) {
            productPrice = newPrice;
            if (productId != null && productId != 'temp') {
              await _firestore.collection('accessories').doc(productId).update({
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

      // Parse purchase price if provided
      double? purchasePrice;
      if (_purchasePriceController.text.isNotEmpty) {
        purchasePrice = double.tryParse(_purchasePriceController.text);
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

      // Check if product already exists in stock to update quantity
      final existingStockQuery = await _firestore
          .collection('accessoryStock')
          .where('shopId', isEqualTo: shopId)
          .where('productId', isEqualTo: productId)
          .where('status', whereIn: ['available', 'low_stock'])
          .limit(1)
          .get();

      if (existingStockQuery.docs.isNotEmpty) {
        // Update existing stock quantity
        final existingDoc = existingStockQuery.docs.first;
        final existingData = existingDoc.data();
        final currentQuantity = existingData['quantity'] as int? ?? 0;

        final newQuantity = currentQuantity + _quantity!;

        await _firestore
            .collection('accessoryStock')
            .doc(existingDoc.id)
            .update({
              'quantity': newQuantity,
              'updatedAt': FieldValue.serverTimestamp(),
              'lastStockAdded': FieldValue.serverTimestamp(),
              'lastAddedBy': uploadedBy,
              'lastAddedById': uploadedById,
              'status': newQuantity < minStock ? 'low_stock' : 'available',
            });

        // Add to stock movement log
        await _firestore.collection('accessoryMovements').add({
          'productId': productId,
          'productName': productName,
          'productCategory': _selectedCategory,
          'movementType': 'add',
          'quantity': _quantity,
          'previousQuantity': currentQuantity,
          'newQuantity': newQuantity,
          'shopId': shopId,
          'shopName': shopName,
          'performedBy': uploadedBy,
          'performedById': uploadedById,
          'timestamp': FieldValue.serverTimestamp(),
          'notes': 'Stock added',
        });
      } else {
        // Create new stock entry
        final stockData = {
          'productCategory': _selectedCategory!.trim(),
          'productName': productName,
          'productId': productId,
          'sellingPrice': productPrice,
          'purchasePrice': purchasePrice,
          'quantity': _quantity,
          'minStockLevel': minStock,
          'barcode': _barcodeController.text.trim().isNotEmpty
              ? _barcodeController.text.trim()
              : null,
          'supplier': _supplierController.text.trim().isNotEmpty
              ? _supplierController.text.trim()
              : null,
          'location': _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          'shopId': shopId,
          'shopName': shopName,
          'uploadedBy': uploadedBy,
          'uploadedById': uploadedById,
          'uploadedAt': FieldValue.serverTimestamp(),
          'status': _quantity! < minStock ? 'low_stock' : 'available',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('accessoryStock').add(stockData);

        // Add to stock movement log
        await _firestore.collection('accessoryMovements').add({
          'productId': productId,
          'productName': productName,
          'productCategory': _selectedCategory,
          'movementType': 'initial',
          'quantity': _quantity,
          'previousQuantity': 0,
          'newQuantity': _quantity,
          'shopId': shopId,
          'shopName': shopName,
          'performedBy': uploadedBy,
          'performedById': uploadedById,
          'timestamp': FieldValue.serverTimestamp(),
          'notes': 'Initial stock',
        });
      }

      if (!mounted) return;

      _showSuccess('Successfully added $_quantity ${productName}(s) to stock!');
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

  // In AccessoriesStockScreen - replace the _sellAccessory method with this:

  Future<void> _sellAccessory(
    String stockId,
    Map<String, dynamic> stockData,
    int quantity,
  ) async {
    try {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      final currentQuantity = stockData['quantity'] as int? ?? 0;

      if (quantity > currentQuantity) {
        _showError('Insufficient quantity. Available: $currentQuantity');
        return;
      }

      if (!mounted) return;

      // Close the action modal first
      setState(() {
        _selectedAccessoryForAction = null;
      });

      // Navigate to GST sale page with product data
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GSTAccessoriesSaleUpload(
            initialProductData: {
              'productId': stockData['productId'],
              'productName': stockData['productName'],
              'productCategory': stockData['productCategory'],
              'stockId': stockId,
              'sellingPrice': stockData['sellingPrice'],
              'purchasePrice': stockData['purchasePrice'],
              'currentQuantity': currentQuantity,
              'quantity': quantity,
              'shopId': stockData['shopId'],
              'shopName': stockData['shopName'],
              'minStockLevel': stockData['minStockLevel'] ?? 5,
              'barcode': stockData['barcode'],
              'supplier': stockData['supplier'],
            },
          ),
        ),
      );

      // If sale was successful, refresh the data
      if (result == true) {
        _showSuccess('Sale completed successfully!');
      }
    } catch (e) {
      _showError('Failed to process sale: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _transferToShop(
    String stockId,
    Map<String, dynamic> stockData,
    String newShopId,
    String newShopName,
    int quantity,
  ) async {
    try {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      final currentQuantity = stockData['quantity'] as int? ?? 0;

      if (quantity > currentQuantity) {
        _showError('Insufficient quantity. Available: $currentQuantity');
        return;
      }

      final currentShopId = stockData['shopId'] as String? ?? '';
      final currentShopName =
          stockData['shopName'] as String? ?? 'Unknown Shop';
      final minStockLevel = stockData['minStockLevel'] as int? ?? 5;

      if (quantity == currentQuantity) {
        // Transfer entire stock
        await _firestore.collection('accessoryStock').doc(stockId).update({
          'shopId': newShopId,
          'shopName': newShopName,
          'transferredBy': user?.email ?? user?.name ?? 'Unknown',
          'transferredById': user?.uid ?? '',
          'transferredAt': FieldValue.serverTimestamp(),
          'previousShopId': currentShopId,
          'previousShopName': currentShopName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Reduce quantity from current shop
        final newCurrentQuantity = currentQuantity - quantity;
        final updateData = {
          'quantity': newCurrentQuantity,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (newCurrentQuantity == 0) {
          updateData['status'] = 'sold_out';
        } else if (newCurrentQuantity < minStockLevel) {
          updateData['status'] = 'low_stock';
        } else {
          updateData['status'] = 'available';
        }

        await _firestore
            .collection('accessoryStock')
            .doc(stockId)
            .update(updateData);

        // Create new stock entry for destination shop
        final newStockData = {
          'productCategory': stockData['productCategory'],
          'productName': stockData['productName'],
          'productId': stockData['productId'],
          'sellingPrice': stockData['sellingPrice'],
          'purchasePrice': stockData['purchasePrice'],
          'quantity': quantity,
          'minStockLevel': minStockLevel,
          'barcode': stockData['barcode'],
          'supplier': stockData['supplier'],
          'location': stockData['location'],
          'shopId': newShopId,
          'shopName': newShopName,
          'uploadedBy': user?.email ?? user?.name ?? 'Unknown',
          'uploadedById': user?.uid ?? '',
          'uploadedAt': FieldValue.serverTimestamp(),
          'status': quantity < minStockLevel ? 'low_stock' : 'available',
          'createdAt': FieldValue.serverTimestamp(),
          'transferredFrom': currentShopId,
          'transferredFromName': currentShopName,
          'transferredBy': user?.email ?? user?.name ?? 'Unknown',
          'transferredById': user?.uid ?? '',
          'transferredAt': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('accessoryStock').add(newStockData);
      }

      // Add transfer record
      await _firestore.collection('accessoryTransfers').add({
        'stockId': stockId,
        'productId': stockData['productId'],
        'productName': stockData['productName'],
        'productCategory': stockData['productCategory'],
        'quantity': quantity,
        'fromShopId': currentShopId,
        'fromShopName': currentShopName,
        'toShopId': newShopId,
        'toShopName': newShopName,
        'transferredBy': user?.email ?? user?.name ?? 'Unknown',
        'transferredById': user?.uid ?? '',
        'transferredAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _selectedAccessoryForAction = null;
      });

      _showSuccess(
        'Transferred $quantity unit(s) to $newShopName successfully!',
      );
    } catch (e) {
      _showError('Failed to transfer: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openScannerForBarcode() async {
    try {
      final status = await Permission.camera.status;
      if (status.isDenied) {
        final result = await Permission.camera.request();
        if (!result.isGranted) {
          _showError('Camera permission required for scanning');
          return;
        }
      }

      // Navigate to scanner
      // You can reuse your ImeiScanner widget or create a barcode scanner
      _showError('Barcode scanner to be implemented');
    } catch (e) {
      _showError('Failed to open scanner: $e');
    }
  }

  void _resetAddStockForm() {
    setState(() {
      _selectedCategory = null;
      _selectedProduct = null;
      _newProductName = null;
      _newProductPrice = null;
      _quantity = null;
      _barcode = null;
      _supplier = null;
      _purchaseDate = null;
      _purchasePrice = null;
      _location = null;
      _showAddProductForm = false;
      _showPriceChangeOption = false;
      _originalProductPrice = null;
      _clearModalMessages();
    });

    _productSearchController.clear();
    _priceChangeController.clear();
    _newProductNameController.clear();
    _newProductPriceController.clear();
    _barcodeController.clear();
    _supplierController.clear();
    _purchasePriceController.clear();
    _locationController.clear();
    _minStockController.clear();

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
    final result = <Map<String, dynamic>>[];

    for (final doc in stocks) {
      final data = doc.data() as Map<String, dynamic>;
      final productName = (data['productName'] as String? ?? '').toLowerCase();
      final productCategory = (data['productCategory'] as String? ?? '')
          .toLowerCase();
      final barcode = (data['barcode'] as String? ?? '').toLowerCase();
      final supplier = (data['supplier'] as String? ?? '').toLowerCase();
      final combinedText = '$productName $productCategory $supplier';

      final searchWords = query.split(' ').where((w) => w.isNotEmpty).toList();

      bool allWordsFound = true;
      for (final word in searchWords) {
        if (!combinedText.contains(word) && !barcode.contains(word)) {
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

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Search by name, category, barcode, supplier',
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blue.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      style: const TextStyle(fontSize: 13, color: Colors.black),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category *',
        border: OutlineInputBorder(),
        labelStyle: TextStyle(fontSize: 12),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        ..._categories.map((category) {
          return DropdownMenuItem(
            value: category,
            child: Text(category, style: const TextStyle(fontSize: 12)),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
          _selectedProduct = null;
          _showAddProductForm = false;
          _productSearchController.clear();
          _clearModalMessages();
        });
      },
      validator: (value) => value == null ? 'Please select category' : null,
    );
  }

  Widget _buildProductSearchDropdown() {
    if (_selectedCategory == null) return const SizedBox();

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

    final products = _productsByCategory[_selectedCategory!] ?? [];
    final searchText = _productSearchController.text.toLowerCase();
    final filteredProducts = searchText.isEmpty
        ? products
        : products.where((p) {
            final name = (p['productName'] as String? ?? '').toLowerCase();
            return name.contains(searchText);
          }).toList();

    final shouldShowAddNew =
        products.isEmpty || (searchText.isNotEmpty && filteredProducts.isEmpty);

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
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: filteredProducts.length + (shouldShowAddNew ? 1 : 0),
              itemBuilder: (context, index) {
                if (shouldShowAddNew && index == filteredProducts.length) {
                  String subtitleText = '';
                  if (products.isEmpty) {
                    subtitleText = 'No products found for this category';
                  } else if (searchText.isNotEmpty &&
                      filteredProducts.isEmpty) {
                    subtitleText = 'No matching products found';
                  }

                  return ListTile(
                    leading: const Icon(
                      Icons.add,
                      color: Colors.green,
                      size: 18,
                    ),
                    title: const Text(
                      'Add New Product...',
                      style: TextStyle(fontSize: 12, color: Colors.black),
                    ),
                    subtitle: subtitleText.isNotEmpty
                        ? Text(
                            subtitleText,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          )
                        : null,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    onTap: () {
                      _handleProductSelection('add_new');
                    },
                  );
                }

                final product = filteredProducts[index];
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
            ),
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

  Widget _buildAddStockModal() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    'Add Accessory Stock',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _closeAddStockModal,
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category dropdown
                      _buildCategoryDropdown(),
                      const SizedBox(height: 16),

                      // Product search/dropdown
                      _buildProductSearchDropdown(),
                      const SizedBox(height: 16),

                      // Show price change option if product selected
                      if (_showPriceChangeOption) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceChangeController,
                                decoration: const InputDecoration(
                                  labelText: 'Selling Price (₹)',
                                  border: OutlineInputBorder(),
                                  labelStyle: TextStyle(fontSize: 12),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 12),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() => _clearModalMessages());
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_originalProductPrice != null)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Original: ${_formatPrice(_originalProductPrice)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Show add product form
                      if (_showAddProductForm) ...[
                        TextFormField(
                          controller: _newProductNameController,
                          decoration: const InputDecoration(
                            labelText: 'Product Name *',
                            border: OutlineInputBorder(),
                            labelStyle: TextStyle(fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter product name';
                            }
                            return null;
                          },
                          onChanged: (value) => _clearModalMessages(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newProductPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Selling Price (₹) *',
                            border: OutlineInputBorder(),
                            labelStyle: TextStyle(fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter price';
                            }
                            final price = double.tryParse(value);
                            if (price == null || price <= 0) {
                              return 'Enter valid price';
                            }
                            return null;
                          },
                          onChanged: (value) => _clearModalMessages(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _minStockController,
                          decoration: const InputDecoration(
                            labelText: 'Minimum Stock Level',
                            border: OutlineInputBorder(),
                            labelStyle: TextStyle(fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(fontSize: 12),
                          keyboardType: TextInputType.number,
                          initialValue: '5',
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Quantity
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Quantity *',
                          border: OutlineInputBorder(),
                          labelStyle: TextStyle(fontSize: 12),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          prefixIcon: Icon(Icons.numbers, size: 18),
                        ),
                        style: const TextStyle(fontSize: 12),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter quantity';
                          }
                          final qty = int.tryParse(value);
                          if (qty == null || qty <= 0) {
                            return 'Enter valid quantity';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          final qty = int.tryParse(value);
                          setState(() {
                            _quantity = qty;
                            _clearModalMessages();
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Optional fields
                      const Text(
                        'Optional Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Barcode with scan option
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _barcodeController,
                              decoration: const InputDecoration(
                                labelText: 'Barcode',
                                border: OutlineInputBorder(),
                                labelStyle: TextStyle(fontSize: 12),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                prefixIcon: Icon(Icons.qr_code, size: 18),
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.blue,
                            ),
                            onPressed: _openScannerForBarcode,
                            tooltip: 'Scan Barcode',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Supplier
                      TextFormField(
                        controller: _supplierController,
                        decoration: const InputDecoration(
                          labelText: 'Supplier',
                          border: OutlineInputBorder(),
                          labelStyle: TextStyle(fontSize: 12),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          prefixIcon: Icon(Icons.business, size: 18),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),

                      // Purchase Price
                      TextFormField(
                        controller: _purchasePriceController,
                        decoration: const InputDecoration(
                          labelText: 'Purchase Price (₹)',
                          border: OutlineInputBorder(),
                          labelStyle: TextStyle(fontSize: 12),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          prefixIcon: Icon(Icons.currency_rupee, size: 18),
                        ),
                        style: const TextStyle(fontSize: 12),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),

                      // Location/Rack
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location/Rack',
                          border: OutlineInputBorder(),
                          labelStyle: TextStyle(fontSize: 12),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          prefixIcon: Icon(Icons.location_on, size: 18),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 20),

                      // Error/Success messages
                      if (_modalError != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error,
                                color: Colors.red.shade700,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _modalError!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_modalSuccess != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade700,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _modalSuccess!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _closeAddStockModal,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveStock,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Stock',
                              style: TextStyle(fontSize: 13),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionModal() {
    if (_selectedAccessoryForAction == null) return const SizedBox();

    final accessory = _selectedAccessoryForAction!;
    final productName = accessory['productName'] as String? ?? 'Unknown';
    final productCategory =
        accessory['productCategory'] as String? ?? 'Unknown';
    final currentQuantity = accessory['quantity'] as int? ?? 0;
    final sellingPrice = accessory['sellingPrice'];
    final stockId = accessory['id'] as String? ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          int sellQuantity = 1;

          return Container(
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
                            ? 'Sell Accessory'
                            : 'Transfer Accessory',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _selectedAccessoryForAction = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Product info
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
                              'Category: $productCategory',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const Spacer(),
                            Text(
                              _formatPrice(sellingPrice),
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
                          'Available: $currentQuantity units',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: currentQuantity < 5
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_selectedAction == 'sell') ...[
                    const Text(
                      'Quantity to sell:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle),
                          onPressed: sellQuantity > 1
                              ? () {
                                  setModalState(() => sellQuantity--);
                                }
                              : null,
                          color: Colors.blue,
                        ),
                        Container(
                          width: 60,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$sellQuantity',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: sellQuantity < currentQuantity
                              ? () {
                                  setModalState(() => sellQuantity++);
                                }
                              : null,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Max: $currentQuantity',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              setState(() {
                                _selectedAccessoryForAction = null;
                              });
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
                                : () async {
                                    if (stockId.isNotEmpty) {
                                      Navigator.of(context).pop();
                                      await _sellAccessory(
                                        stockId,
                                        accessory,
                                        sellQuantity,
                                      );
                                    } else {
                                      _showError('Stock ID not found');
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
                      'Quantity to transfer:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle),
                          onPressed: sellQuantity > 1
                              ? () {
                                  setModalState(() => sellQuantity--);
                                }
                              : null,
                          color: Colors.blue,
                        ),
                        Container(
                          width: 60,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$sellQuantity',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: sellQuantity < currentQuantity
                              ? () {
                                  setModalState(() => sellQuantity++);
                                }
                              : null,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Select shop to transfer to:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Shop list
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _shops
                            .where((s) => s['id'] != accessory['shopId'])
                            .length,
                        itemBuilder: (context, index) {
                          final filteredShops = _shops
                              .where((s) => s['id'] != accessory['shopId'])
                              .toList();
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
                                : () async {
                                    if (stockId.isNotEmpty) {
                                      Navigator.of(context).pop();
                                      await _transferToShop(
                                        stockId,
                                        accessory,
                                        shop['id'] as String? ?? '',
                                        shop['name'] as String? ??
                                            'Unknown Shop',
                                        sellQuantity,
                                      );
                                    } else {
                                      _showError('Stock ID not found');
                                    }
                                  },
                            dense: true,
                            visualDensity: VisualDensity.compact,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              setState(() {
                                _selectedAccessoryForAction = null;
                              });
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
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
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

  Widget _buildAccessoryCard({
    required String productName,
    required String productCategory,
    required int quantity,
    required dynamic sellingPrice,
    required int minStockLevel,
    required dynamic uploadedAt,
    required Map<String, dynamic> stockData,
    String? barcode,
    String? supplier,
    String? location,
  }) {
    final isLowStock = quantity < minStockLevel;
    final isOutOfStock = quantity == 0;

    Color borderColor;
    Color bgColor;
    String statusText;

    if (isOutOfStock) {
      borderColor = Colors.red.shade200;
      bgColor = Colors.red.shade50;
      statusText = 'OUT OF STOCK';
    } else if (isLowStock) {
      borderColor = Colors.orange.shade200;
      bgColor = Colors.orange.shade50;
      statusText = 'LOW STOCK';
    } else {
      borderColor = Colors.green.shade200;
      bgColor = Colors.white;
      statusText = 'AVAILABLE';
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 200),
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
            // Status and stock info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? Colors.red.shade100
                        : isLowStock
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isOutOfStock
                          ? Colors.red
                          : isLowStock
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Qty: $quantity',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Product name
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

            // Price
            Text(
              _formatPrice(sellingPrice),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            // Category
            Text(
              productCategory,
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            // Barcode if available
            if (barcode != null && barcode.isNotEmpty)
              Text(
                'Barcode: $barcode',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            // Supplier if available
            if (supplier != null && supplier.isNotEmpty)
              Text(
                'Supplier: $supplier',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            // Location if available
            if (location != null && location.isNotEmpty)
              Text(
                'Location: $location',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            // Added date
            Text(
              'Added: ${_formatDate(uploadedAt)}',
              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            // Action buttons
            if (!isOutOfStock)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1, color: Colors.grey),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedAccessoryForAction = {
                                  ...stockData,
                                  'id': stockData['id'],
                                };
                                _selectedAction = 'sell';
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Sell'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedAccessoryForAction = {
                                  ...stockData,
                                  'id': stockData['id'],
                                };
                                _selectedAction = 'transfer';
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Transfer'),
                            ),
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

  Widget _buildSoldAccessoryCard({
    required String productName,
    required String productCategory,
    required int quantity,
    required dynamic sellingPrice,
    required dynamic soldAt,
    required String soldBy,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
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
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SOLD',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
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
              _formatPrice(sellingPrice),
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
              productCategory,
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            Text(
              'Qty: $quantity',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            Text(
              'Sold: ${_formatDate(soldAt)}',
              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            Text(
              'By: $soldBy',
              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockList(String type) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final currentShopId = user?.shopId;

    if (type == 'sold') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('accessorySales')
            .where('shopId', isEqualTo: currentShopId)
            .orderBy('soldAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading sales: ${snapshot.error}',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sales = snapshot.data!.docs;

          if (sales.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart, size: 50, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'No sales yet',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Filter by search
          final filteredSales = <Map<String, dynamic>>[];
          for (final doc in sales) {
            final data = doc.data() as Map<String, dynamic>;
            if (_searchQuery.isEmpty) {
              filteredSales.add({...data, 'id': doc.id});
            } else {
              final query = _searchQuery.toLowerCase();
              final productName = (data['productName'] as String? ?? '')
                  .toLowerCase();
              final category = (data['productCategory'] as String? ?? '')
                  .toLowerCase();
              if (productName.contains(query) || category.contains(query)) {
                filteredSales.add({...data, 'id': doc.id});
              }
            }
          }

          double totalSales = 0;
          int totalItems = 0;
          for (final sale in filteredSales) {
            totalSales += (sale['totalAmount'] as double? ?? 0);
            totalItems += (sale['quantity'] as int? ?? 0);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Sales',
                        _formatPrice(totalSales),
                        '$totalItems items',
                        Colors.blue,
                        Icons.shopping_cart_checkout,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        'Transactions',
                        '${filteredSales.length}',
                        'Sales',
                        Colors.purple,
                        Icons.receipt,
                      ),
                    ),
                  ],
                ),
              ),

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
                      'Sales: ${filteredSales.length}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                    childAspectRatio: 1.6,
                  ),
                  itemCount: filteredSales.length,
                  itemBuilder: (context, index) {
                    final sale = filteredSales[index];
                    return _buildSoldAccessoryCard(
                      productName: sale['productName'] as String? ?? 'Unknown',
                      productCategory:
                          sale['productCategory'] as String? ?? 'Unknown',
                      quantity: sale['quantity'] as int? ?? 1,
                      sellingPrice: sale['sellingPrice'] ?? 0,
                      soldAt: sale['soldAt'],
                      soldBy: sale['soldBy'] ?? 'Unknown',
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    } else {
      // For Available Stock - show only items with quantity > 0
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('accessoryStock')
            .where('shopId', isEqualTo: currentShopId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading data: ${snapshot.error}',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    textAlign: TextAlign.center,
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
                  Icon(Icons.inventory, size: 50, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'No accessories in stock',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    onPressed: _openAddStockModal,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Add Accessory',
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

          // Filter and process stocks - only show items with quantity > 0
          final allFilteredStocks = _filterStocksBySearch(stocks);

          // Filter to only show items with quantity > 0
          final availableStocks = <Map<String, dynamic>>[];

          for (final stock in allFilteredStocks) {
            final quantity = stock['quantity'] as int? ?? 0;

            if (quantity > 0) {
              availableStocks.add(stock);
            }
          }

          if (availableStocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory, size: 50, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'No available accessories',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    onPressed: _openAddStockModal,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Add Accessory',
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

          // Calculate statistics
          double totalValue = 0;
          int totalItems = 0;
          final Map<String, int> categoryCount = {};

          for (final data in availableStocks) {
            final price = _parsePrice(data['sellingPrice']);
            final qty = data['quantity'] as int? ?? 0;
            totalValue += price * qty;
            totalItems += qty;

            final category = data['productCategory'] as String? ?? 'Other';
            categoryCount[category] = (categoryCount[category] ?? 0) + 1;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Stock Value',
                        _formatPrice(totalValue),
                        '$totalItems items',
                        Colors.green,
                        Icons.inventory,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        'Categories',
                        '${categoryCount.length}',
                        'Varieties',
                        Colors.purple,
                        Icons.category,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

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
                      'Items: ${availableStocks.length}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      onPressed: _openAddStockModal,
                      tooltip: 'Add Stock',
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
                    childAspectRatio: 1.8,
                  ),
                  itemCount: availableStocks.length,
                  itemBuilder: (context, index) {
                    final stock = availableStocks[index];
                    return _buildAccessoryCard(
                      productName: stock['productName'] as String? ?? 'Unknown',
                      productCategory:
                          stock['productCategory'] as String? ?? 'Unknown',
                      quantity: stock['quantity'] as int? ?? 0,
                      sellingPrice: stock['sellingPrice'] ?? 0,
                      minStockLevel: stock['minStockLevel'] as int? ?? 5,
                      uploadedAt: stock['uploadedAt'],
                      barcode: stock['barcode'] as String?,
                      supplier: stock['supplier'] as String?,
                      location: stock['location'] as String?,
                      stockData: stock,
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

  Widget _buildQuickScanButton() {
    return FloatingActionButton.extended(
      onPressed: _openScannerForBarcode,
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text('Scan'),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      elevation: 4,
    );
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
              title: const Text(
                'Accessories Stock',
                style: TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.blue,
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
                      foregroundColor: Colors.blue,
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
                                labelColor: Colors.blue,
                                unselectedLabelColor: Colors.grey,
                                indicatorColor: Colors.blue,
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
                                            _tabTitles[0], // Available
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
                                            _tabTitles[1], // Sold
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
                          ],
                        ),
                      ),
                    ],
                  ),
            floatingActionButton: _buildQuickScanButton(),
          ),

          if (_showAddStockModal || _selectedAccessoryForAction != null)
            Container(
              color: Colors.black.withOpacity(0.5),
              width: double.infinity,
              height: double.infinity,
            ),

          if (_showAddStockModal) _buildAddStockModal(),

          if (_selectedAccessoryForAction != null) _buildActionModal(),
        ],
      ),
    );
  }
}
