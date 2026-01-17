import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

  // For existing stock view
  String _searchQuery = '';
  late TextEditingController _searchController;

  // For adding stock (modal)
  String? _selectedBrand;
  String? _selectedProduct;
  String? _newProductName;
  double? _newProductPrice;
  int? _quantity;
  List<String> _imeiNumbers = [];
  List<TextEditingController> _imeiControllers = [];

  List<String> _brands = [
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
  Map<String, List<Map<String, dynamic>>> _productsByBrand = {};
  bool _isLoading = false;
  bool _showAddProductForm = false;
  bool _showAddStockModal = false;

  // For shops data
  List<Map<String, dynamic>> _shops = [];

  // For actions on phone
  Map<String, dynamic>? _selectedPhoneForAction;
  String _selectedAction = 'sell';

  // For product search in dropdown
  late TextEditingController _productSearchController;
  List<Map<String, dynamic>> _filteredProducts = [];

  // For price change
  double? _originalProductPrice;
  bool _showPriceChangeOption = false;
  late TextEditingController _priceChangeController;

  // For modal error display
  String? _modalError;
  String? _modalSuccess;

  // For tabs
  late TabController _tabController;
  int _currentTabIndex = 0;
  final List<String> _tabTitles = ['Available', 'Sold', 'Returned'];

  // For search focus
  final FocusNode _searchFocusNode = FocusNode();

  // For IMEI Scanner
  bool _showScanner = false;
  MobileScannerController? _scannerController;
  String? _lastScannedImei;
  int? _currentImeiFieldIndex;

  @override
  void initState() {
    super.initState();
    // Initialize controllers in initState
    _searchController = TextEditingController();
    _productSearchController = TextEditingController();
    _priceChangeController = TextEditingController();

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    _loadExistingProducts();
    _loadShops();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocusNode.dispose();
    _scannerController?.dispose();

    // Dispose all controllers
    _disposeAllControllers();
    super.dispose();
  }

  void _disposeAllControllers() {
    _searchController.dispose();
    _productSearchController.dispose();
    _priceChangeController.dispose();
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
          final data = doc.data() as Map<String, dynamic>;
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
        final data = doc.data() as Map<String, dynamic>;
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
      });
    } else {
      setState(() {
        _selectedProduct = value;
        _showAddProductForm = false;
        _productSearchController.clear();
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

    if (_newProductName == null || _newProductName!.trim().isEmpty) {
      _showModalError('Please enter product name');
      return;
    }

    if (_newProductPrice == null || _newProductPrice! <= 0) {
      _showModalError('Please enter valid price');
      return;
    }

    try {
      setState(() => _isLoading = true);

      final newProduct = {
        'brand': _selectedBrand!,
        'productName': _newProductName!.trim(),
        'price': _newProductPrice!,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('phones').add(newProduct);

      if (!_productsByBrand.containsKey(_selectedBrand!)) {
        _productsByBrand[_selectedBrand!] = [];
      }

      final existingProductIndex = _productsByBrand[_selectedBrand!]!
          .indexWhere((p) => p['productName'] == _newProductName!.trim());

      if (existingProductIndex == -1) {
        _productsByBrand[_selectedBrand!]!.add({
          'id': 'temp',
          'productName': _newProductName!.trim(),
          'price': _newProductPrice!,
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
        _selectedProduct = _newProductName!.trim();
        _newProductName = null;
        _newProductPrice = null;
        _clearModalMessages();
        _showModalSuccess('Product added successfully!');
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
        if (_newProductName == null || _newProductName!.trim().isEmpty) {
          _showModalError('Please enter product name');
          return;
        }
        if (_newProductPrice == null || _newProductPrice! <= 0) {
          _showModalError('Please enter valid price');
          return;
        }

        productName = _newProductName!.trim();
        productPrice = _newProductPrice!;

        await _saveNewProduct();
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
        if (imei.length < 15) {
          _showModalError('IMEI ${i + 1} must be at least 15 digits');
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
          user.shopName?.trim() ?? user.name?.trim() ?? 'Unknown Shop';
      final uploadedBy =
          user.email?.trim() ?? user.name?.trim() ?? 'Unknown User';
      final uploadedById = user.uid;

      try {
        for (String imei in _imeiNumbers) {
          final existingQuery = await _firestore
              .collection('phoneStock')
              .where('imei', isEqualTo: imei)
              .limit(1)
              .get();

          if (existingQuery.docs.isNotEmpty) {
            _showModalError('IMEI $imei already exists in stock database');
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

      await _firestore.collection('phoneStock').doc(phoneId).update({
        'shopId': newShopId,
        'shopName': newShopName,
        'transferredBy': user?.email ?? user?.name ?? 'Unknown',
        'transferredById': user?.uid ?? '',
        'transferredAt': FieldValue.serverTimestamp(),
        'previousShopId': phoneData['shopId'],
        'previousShopName': phoneData['shopName'],
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
        'productBrand': phoneData['productBrand'],
        'productName': phoneData['productName'],
        'productPrice': phoneData['productPrice'],
        'imei': phoneData['imei'],
        'originalShopId': phoneData['shopId'],
        'originalShopName': phoneData['shopName'],
        'returnedBy': user?.email ?? user?.name ?? 'Unknown',
        'returnedById': user?.uid ?? '',
        'returnedAt': FieldValue.serverTimestamp(),
        'reason': 'returned_to_inventory',
        'status': 'returned', // Add status field for filtering
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

  void _openScannerForImei(int index) {
    setState(() {
      _currentImeiFieldIndex = index;
      _showScanner = true;
      _scannerController = MobileScannerController();
      _lastScannedImei = null;
    });
  }

  void _closeScanner() {
    setState(() {
      _showScanner = false;
      _currentImeiFieldIndex = null;
      _scannerController?.dispose();
      _scannerController = null;
    });
  }

  void _handleBarcodeScan(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String scannedData = barcodes.first.rawValue ?? '';

      if (RegExp(r'^\d{15,16}$').hasMatch(scannedData)) {
        if (_currentImeiFieldIndex != null &&
            _currentImeiFieldIndex! < _imeiNumbers.length) {
          setState(() {
            _imeiNumbers[_currentImeiFieldIndex!] = scannedData;
            _imeiControllers[_currentImeiFieldIndex!].text = scannedData;
            _lastScannedImei = scannedData;
          });

          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _closeScanner();
            }
          });
        }
      } else {
        setState(() {
          _lastScannedImei = 'Invalid IMEI format: $scannedData';
        });
      }
    }
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
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          style: const TextStyle(fontSize: 12, color: Colors.black),
          onChanged: (value) {
            setState(() {
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

        Container(
          constraints: const BoxConstraints(maxHeight: 120),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildProductList(),
        ),
      ],
    );
  }

  Widget _buildAddStockModal() {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Add Phone Stock',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: _closeAddStockModal,
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: _selectedBrand,
                          dropdownColor: Colors.white,
                          decoration: const InputDecoration(
                            labelText: 'Select Brand *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.branding_watermark,
                              size: 18,
                            ),
                            labelStyle: TextStyle(fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                          items: _brands.map<DropdownMenuItem<String>>((brand) {
                            return DropdownMenuItem<String>(
                              value: brand,
                              child: Text(
                                brand,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBrand = value;
                              _selectedProduct = null;
                              _showAddProductForm = false;
                              _showPriceChangeOption = false;
                              _newProductName = null;
                              _newProductPrice = null;
                              _productSearchController.clear();
                              _priceChangeController.clear();
                              _clearModalMessages();
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a brand';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        if (_selectedBrand != null) ...[
                          _buildProductSearchDropdown(),
                          const SizedBox(height: 12),

                          if (_showAddProductForm) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'New Product Details',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.green,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.arrow_back,
                                          size: 16,
                                        ),
                                        onPressed: _cancelAddNewProduct,
                                        tooltip: 'Back to product selection',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'Product Name *',
                                      border: OutlineInputBorder(),
                                      labelStyle: TextStyle(fontSize: 12),
                                      hintText: 'e.g., iPhone 15 Pro Max 256GB',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _newProductName = value;
                                        _clearModalMessages();
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter product name';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 10),

                                  TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'Price *',
                                      border: OutlineInputBorder(),
                                      labelStyle: TextStyle(fontSize: 12),
                                      prefixText: '₹ ',
                                      hintText: 'e.g., 129999',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        _newProductPrice = double.tryParse(
                                          value,
                                        );
                                        _clearModalMessages();
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter price';
                                      }
                                      final price = double.tryParse(value);
                                      if (price == null || price <= 0) {
                                        return 'Please enter valid price';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          if (_showPriceChangeOption &&
                              _originalProductPrice != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Price Change Option',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Original Price: ${_formatPrice(_originalProductPrice)}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _priceChangeController,
                                    decoration: const InputDecoration(
                                      labelText: 'New Price (optional)',
                                      border: OutlineInputBorder(),
                                      labelStyle: TextStyle(fontSize: 12),
                                      prefixText: '₹ ',
                                      hintText: 'Enter new price',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      _clearModalMessages();
                                    },
                                    validator: (value) {
                                      if (value != null && value.isNotEmpty) {
                                        final price = double.tryParse(value);
                                        if (price == null || price <= 0) {
                                          return 'Please enter valid price';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Note: Changing price will update this product\'s price for all future stock entries.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],

                        if (_selectedProduct != null ||
                            _showAddProductForm) ...[
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Quantity *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.numbers, size: 18),
                              labelStyle: TextStyle(fontSize: 12),
                              hintText: 'Enter number of units',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              _handleQuantityChange(value);
                              _clearModalMessages();
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter quantity';
                              }
                              final qty = int.tryParse(value);
                              if (qty == null || qty <= 0) {
                                return 'Please enter valid quantity (min: 1)';
                              }
                              if (qty > 50) {
                                return 'Maximum 50 units at a time';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),
                        ],

                        if (_quantity != null && _quantity! > 0) ...[
                          const Text(
                            'Enter IMEI Numbers: *',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Each IMEI must be 15-16 digits (${_quantity} required)',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 10),

                          SizedBox(
                            height: _quantity! <= 3 ? _quantity! * 70.0 : 210.0,
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _quantity!,
                              itemBuilder: (context, index) {
                                if (index >= _imeiControllers.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: TextFormField(
                                      decoration: InputDecoration(
                                        labelText: 'IMEI ${index + 1} *',
                                        border: const OutlineInputBorder(),
                                        prefixIcon: const Icon(
                                          Icons.confirmation_number,
                                          size: 18,
                                        ),
                                        labelStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                      onChanged: (value) {
                                        if (index < _imeiNumbers.length) {
                                          setState(() {
                                            _imeiNumbers[index] = value;
                                            _clearModalMessages();
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter IMEI';
                                        }
                                        final trimmedValue = value.trim();
                                        if (trimmedValue.length < 15) {
                                          return 'IMEI must be at least 15 digits';
                                        }
                                        return null;
                                      },
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _imeiControllers[index],
                                          decoration: InputDecoration(
                                            labelText: 'IMEI ${index + 1} *',
                                            border: const OutlineInputBorder(),
                                            prefixIcon: const Icon(
                                              Icons.confirmation_number,
                                              size: 18,
                                            ),
                                            suffixIcon:
                                                index < _imeiNumbers.length &&
                                                    _imeiNumbers[index]
                                                        .isNotEmpty
                                                ? Icon(
                                                    Icons.check_circle,
                                                    color:
                                                        _imeiNumbers[index]
                                                                .length >=
                                                            15
                                                        ? Colors.green
                                                        : Colors.orange,
                                                    size: 16,
                                                  )
                                                : null,
                                            labelStyle: const TextStyle(
                                              fontSize: 12,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black,
                                          ),
                                          onChanged: (value) {
                                            if (index < _imeiNumbers.length) {
                                              setState(() {
                                                _imeiNumbers[index] = value;
                                                _clearModalMessages();
                                              });
                                            }
                                          },
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
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
                                      IconButton(
                                        icon: const Icon(
                                          Icons.qr_code_scanner,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            _openScannerForImei(index),
                                        tooltip: 'Scan IMEI',
                                        color: Colors.blue,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],

                        if (_modalError != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _modalError!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: _clearModalMessages,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),

                        if (_modalSuccess != null &&
                            !_modalSuccess!.contains('Product added'))
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade100),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _modalSuccess!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: _clearModalMessages,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),

                        Container(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _closeAddStockModal,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
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
                                  onPressed: _isLoading ? null : _saveStock,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
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
                                          'Save Stock',
                                          style: TextStyle(fontSize: 12),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionModal() {
    if (_selectedPhoneForAction == null) return const SizedBox();

    final phone = _selectedPhoneForAction!;
    final productName = phone['productName'] as String? ?? 'Unknown';
    final productBrand = phone['productBrand'] as String? ?? 'Unknown';
    final imei = phone['imei'] as String? ?? 'N/A';
    final price = phone['productPrice'];
    final currentShopId = phone['shopId'] as String?;

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
                                final phoneId = phone['id'] as String;
                                _markAsSold(phoneId, phone);
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
                            shop['name'],
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle:
                              shop['address'] != null &&
                                  (shop['address'] as String).isNotEmpty
                              ? Text(
                                  shop['address'],
                                  style: const TextStyle(fontSize: 10),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: _isLoading
                              ? null
                              : () {
                                  final phoneId = phone['id'] as String;
                                  _transferToShop(
                                    phoneId,
                                    phone,
                                    shop['id'],
                                    shop['name'],
                                  );
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
                                final phoneId = phone['id'] as String;
                                _returnPhone(phoneId, phone);
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

  Widget _buildImeiScannerModal() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scan IMEI Barcode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _closeScanner,
                  ),
                ],
              ),
            ),
            const Divider(),

            Expanded(
              child: Stack(
                children: [
                  if (_scannerController != null)
                    MobileScanner(
                      controller: _scannerController!,
                      onDetect: _handleBarcodeScan,
                    ),

                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: const EdgeInsets.all(40),
                    child: Container(),
                  ),

                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.black.withOpacity(0.7),
                      child: Column(
                        children: [
                          const Text(
                            'Point camera at IMEI barcode',
                            style: TextStyle(fontSize: 14, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          if (_lastScannedImei != null)
                            Text(
                              'Scanned: $_lastScannedImei',
                              style: TextStyle(
                                fontSize: 12,
                                color: _lastScannedImei!.startsWith('Invalid')
                                    ? Colors.red
                                    : Colors.green,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () {
                  _closeScanner();
                },
                icon: const Icon(Icons.keyboard, size: 16),
                label: const Text(
                  'Enter IMEI Manually',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildStockList(String type) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final currentShopId = user?.shopId;

    if (type == 'returned') {
      // FIXED: Show all returned phones without status filter
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('phoneReturns')
            .where('originalShopId', isEqualTo: currentShopId)
            // REMOVED: .where('status', isEqualTo: 'returned')
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

          // Sort returns by returnedAt (most recent first)
          returns.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['returnedAt'];
            final bDate = bData['returnedAt'];

            if (aDate == null || bDate == null) return 0;
            if (aDate is Timestamp && bDate is Timestamp) {
              return bDate.compareTo(aDate); // Descending
            }
            return 0;
          });

          // Filter returns based on search query
          final filteredReturns = returns.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            if (_searchQuery.isNotEmpty) {
              final imei = data['imei'] as String? ?? '';
              final productName = data['productName'] as String? ?? '';
              final productBrand = data['productBrand'] as String? ?? '';

              return imei.toLowerCase().contains(_searchQuery) ||
                  productName.toLowerCase().contains(_searchQuery) ||
                  productBrand.toLowerCase().contains(_searchQuery);
            }

            return true;
          }).toList();

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

          // Calculate statistics for returned tab
          double totalValue = 0;
          int totalPhones = 0;
          final Map<String, Map<String, dynamic>> brandStats = {};

          for (final doc in filteredReturns) {
            final data = doc.data() as Map<String, dynamic>;
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
                    final doc = filteredReturns[index];
                    final returnData = doc.data() as Map<String, dynamic>;
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
      // Show available or sold phones from phoneStock collection
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
                  if (type == 'available')
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

          final filteredStocks = stocks.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            if (_searchQuery.isNotEmpty) {
              final imei = data['imei'] as String? ?? '';
              final productName = data['productName'] as String? ?? '';
              final productBrand = data['productBrand'] as String? ?? '';

              return imei.toLowerCase().contains(_searchQuery) ||
                  productName.toLowerCase().contains(_searchQuery) ||
                  productBrand.toLowerCase().contains(_searchQuery);
            }

            return true;
          }).toList();

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

          for (final doc in filteredStocks) {
            final data = doc.data() as Map<String, dynamic>;
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
                              maxLines: 1,
                              textAlign: TextAlign.center,
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
                        onPressed: () {
                          _showScannerForStockSearch();
                        },
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
                    final doc = filteredStocks[index];
                    final stock = doc.data() as Map<String, dynamic>;
                    final productName =
                        stock['productName'] as String? ?? 'Unknown';
                    final productBrand =
                        stock['productBrand'] as String? ?? 'Unknown';
                    final imei = stock['imei'] as String? ?? 'N/A';
                    final price = stock['productPrice'];
                    final uploadedAt = stock['uploadedAt'];
                    final soldAt = stock['soldAt'];

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
                              setState(() {
                                _selectedPhoneForAction = {
                                  ...stock,
                                  'id': doc.id,
                                };
                                _selectedAction = 'sell';
                              });
                            }
                          : null,
                      onTransfer: type == 'available'
                          ? () {
                              setState(() {
                                _selectedPhoneForAction = {
                                  ...stock,
                                  'id': doc.id,
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
                                  'id': doc.id,
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

  void _showScannerForStockSearch() {
    setState(() {
      _showScanner = true;
      _scannerController = MobileScannerController();
      _lastScannedImei = null;
    });
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
                            Container(
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
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                decoration: InputDecoration(
                                  labelText: 'Search IMEI, Product, Brand',
                                  labelStyle: const TextStyle(fontSize: 13),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 20,
                                  ),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_searchQuery.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                            _searchFocusNode.unfocus();
                                          },
                                        ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.qr_code_scanner,
                                          size: 22,
                                        ),
                                        onPressed: () {
                                          _showScannerForStockSearch();
                                        },
                                        tooltip: 'Scan IMEI',
                                      ),
                                    ],
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                                onChanged: (value) {
                                  setState(
                                    () => _searchQuery = value.toLowerCase(),
                                  );
                                },
                                onSubmitted: (value) {
                                  _searchFocusNode.unfocus();
                                },
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.keyboard_hide, size: 22),
                                onPressed: () {
                                  _searchFocusNode.unfocus();
                                },
                                tooltip: 'Hide keyboard',
                              ),
                          ],
                        ),
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
          ),

          if (_showAddStockModal ||
              _selectedPhoneForAction != null ||
              _showScanner)
            Container(
              color: Colors.black.withOpacity(0.5),
              width: double.infinity,
              height: double.infinity,
            ),

          if (_showAddStockModal) _buildAddStockModal(),

          if (_selectedPhoneForAction != null) _buildActionModal(),

          if (_showScanner) _buildImeiScannerModal(),
        ],
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
    String displayImei = imei;
    if (imei.length > 15) {
      if (imei.length == 15) {
        displayImei =
            '${imei.substring(0, 6)}-${imei.substring(6, 12)}-${imei.substring(12)}';
      } else if (imei.length == 16) {
        displayImei = '${imei.substring(0, 8)}-${imei.substring(8)}';
      }
    }

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
      constraints: BoxConstraints(minHeight: 180),
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
    String displayImei = imei;
    if (imei.length > 15) {
      if (imei.length == 15) {
        displayImei =
            '${imei.substring(0, 6)}-${imei.substring(6, 12)}-${imei.substring(12)}';
      } else if (imei.length == 16) {
        displayImei = '${imei.substring(0, 8)}-${imei.substring(8)}';
      }
    }

    return Container(
      constraints: BoxConstraints(minHeight: 180),
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
}
