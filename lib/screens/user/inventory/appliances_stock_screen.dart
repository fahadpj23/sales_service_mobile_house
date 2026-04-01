import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../providers/auth_provider.dart';
import '../sale/gst_accessories_sale_upload.dart';

class AppliancesStockScreen extends StatefulWidget {
  const AppliancesStockScreen({super.key});

  @override
  State<AppliancesStockScreen> createState() => _AppliancesStockScreenState();
}

class _AppliancesStockScreenState extends State<AppliancesStockScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  String _searchQuery = '';
  late TextEditingController _searchController;

  static const String _fixedCategory = 'Appliances';

  String? _selectedBrand;
  String? _selectedProduct;
  String? _newProductName;
  double? _newProductPrice;
  int? _quantity;

  // Dynamic brands from Firestore
  List<String> _brands = [];
  bool _showAddBrandModal = false;
  TextEditingController _newBrandController = TextEditingController();

  final Map<String, List<Map<String, dynamic>>> _productsByBrand = {};
  bool _isLoading = false;
  bool _showAddProductForm = false;
  bool _showAddStockModal = false;

  List<Map<String, dynamic>> _shops = [];
  Map<String, dynamic>? _selectedModelForAction;
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

  // Controllers for action dialogs
  TextEditingController _sellQuantityController = TextEditingController();
  TextEditingController _sellPriceController = TextEditingController();
  TextEditingController _transferQuantityController = TextEditingController();
  TextEditingController _returnQuantityController = TextEditingController();

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
      });
    });
    _loadAllData();
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
    _sellQuantityController.dispose();
    _sellPriceController.dispose();
    _transferQuantityController.dispose();
    _returnQuantityController.dispose();
    _newBrandController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([_loadBrands(), _loadExistingProducts(), _loadShops()]);
  }

  Future<void> _loadBrands() async {
    try {
      setState(() => _isLoading = true);

      final brandsSnapshot = await _firestore
          .collection('applianceBrands')
          .orderBy('brand')
          .get();

      final loadedBrands = <String>[];
      for (var doc in brandsSnapshot.docs) {
        final data = doc.data();
        final brand = data['brand'] as String?;
        if (brand != null && brand.isNotEmpty) {
          loadedBrands.add(brand);
        }
      }

      setState(() {
        _brands = loadedBrands;
      });
    } catch (e) {
      print('Error loading brands: $e');
      _showError('Failed to load brands');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addNewBrand() async {
    final newBrand = _newBrandController.text.trim();
    if (newBrand.isEmpty) {
      _showModalError('Please enter brand name');
      return;
    }

    if (_brands.contains(newBrand)) {
      _showModalError('Brand already exists');
      return;
    }

    try {
      setState(() => _isLoading = true);

      await _firestore.collection('applianceBrands').add({
        'brand': newBrand,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _brands.add(newBrand);
        _brands.sort();
        _showAddBrandModal = false;
        _newBrandController.clear();
        _selectedBrand = newBrand;
        _selectedProduct = null;
        _clearModalMessages();
        _showModalSuccess('Brand "$newBrand" added successfully!');
      });
    } catch (e) {
      _showModalError('Failed to add brand: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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

      final snapshot = await _firestore
          .collection('applianceModels')
          .where('category', isEqualTo: _fixedCategory)
          .get();

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
      final productBrand = (data['productBrand'] as String? ?? '')
          .toLowerCase();
      final serialNumber = (data['serialNumber'] as String? ?? '')
          .toLowerCase();
      final combinedText = '$productName $productBrand';

      final searchWords = query.split(' ').where((w) => w.isNotEmpty).toList();

      bool allWordsFound = true;

      for (final word in searchWords) {
        final variations = <String>[word];

        if (word.contains('/')) {
          variations.add(word.replaceAll('/', ' '));
          variations.add(word.replaceAll('/', ''));
        }

        bool wordFound = false;
        for (final variation in variations) {
          if (combinedText.contains(variation)) {
            wordFound = true;
            break;
          }
        }

        if (!wordFound && serialNumber.contains(word)) {
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
        // Clear quantity when showing add product form
        _quantity = null;
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
      _quantity = null;
    });
  }

  void _handleQuantityChange(String value) {
    final qty = int.tryParse(value);
    setState(() {
      _quantity = qty;
      _clearModalMessages();
    });
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
        'category': _fixedCategory,
        'brand': _selectedBrand!,
        'productName': productName,
        'price': price,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection('applianceModels')
          .add(newProduct);

      if (!_productsByBrand.containsKey(_selectedBrand!)) {
        _productsByBrand[_selectedBrand!] = [];
      }

      final existingProductIndex = _productsByBrand[_selectedBrand!]!
          .indexWhere((p) => p['productName'] == productName);

      if (existingProductIndex == -1) {
        _productsByBrand[_selectedBrand!]!.add({
          'id': docRef.id,
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
        productId = null;
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
              await _firestore
                  .collection('applianceModels')
                  .doc(productId)
                  .update({
                    'price': productPrice,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

              final productIndex = products.indexWhere(
                (p) => p['id'] == productId,
              );
              if (productIndex != -1) {
                products[productIndex]['price'] = productPrice;
              }
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

      final existingStockQuery = await _firestore
          .collection('applianceStock')
          .where('shopId', isEqualTo: shopId)
          .where('category', isEqualTo: _fixedCategory)
          .where('productBrand', isEqualTo: _selectedBrand!.trim())
          .where('productName', isEqualTo: productName)
          .where('status', isEqualTo: 'available')
          .limit(1)
          .get();

      if (existingStockQuery.docs.isNotEmpty) {
        final existingDoc = existingStockQuery.docs.first;
        final existingData = existingDoc.data();
        final currentQuantity = existingData['quantity'] as int? ?? 0;
        final newQuantity = currentQuantity + _quantity!;

        await _firestore
            .collection('applianceStock')
            .doc(existingDoc.id)
            .update({
              'quantity': newQuantity,
              'lastUpdatedAt': FieldValue.serverTimestamp(),
              'lastUpdatedBy': uploadedBy,
              'lastUpdatedById': uploadedById,
              'productPrice': productPrice,
            });

        if (!mounted) return;
        _showSuccess(
          'Added $_quantity to existing stock! New total: $newQuantity',
        );
      } else {
        final stockData = {
          'category': _fixedCategory,
          'productBrand': _selectedBrand!.trim(),
          'productName': productName,
          'productPrice': productPrice,
          'quantity': _quantity,
          'shopId': shopId,
          'shopName': shopName,
          'uploadedBy': uploadedBy,
          'uploadedById': uploadedById,
          'uploadedAt': FieldValue.serverTimestamp(),
          'status': 'available',
          'createdAt': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('applianceStock').add(stockData);

        if (!mounted) return;
        _showSuccess(
          'Successfully added $_quantity new appliance(s) to stock!',
        );
      }

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
      _showAddProductForm = false;
      _showPriceChangeOption = false;
      _originalProductPrice = null;
      _clearModalMessages();
    });

    _productSearchController.clear();
    _priceChangeController.clear();
    _newProductNameController.clear();
    _newProductPriceController.clear();

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
    String modelId,
    Map<String, dynamic> modelData,
  ) async {
    try {
      final currentQuantity = modelData['quantity'] as int? ?? 1;
      int selectedQuantity = 1;
      double sellingPrice =
          (modelData['productPrice'] as num?)?.toDouble() ?? 0;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          int tempQuantity = 1;
          double tempPrice = sellingPrice;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Sell Appliance'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                              'Product: ${modelData['productName']}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Brand: ${modelData['productBrand']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Available Quantity:',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '$currentQuantity units',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: TextEditingController(text: '1')
                          ..selection = TextSelection.collapsed(offset: 1),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity to Sell *',
                          border: OutlineInputBorder(),
                          helperText: 'Enter quantity to sell',
                        ),
                        onChanged: (value) {
                          final qty = int.tryParse(value);
                          if (qty != null &&
                              qty > 0 &&
                              qty <= currentQuantity) {
                            setDialogState(() {
                              tempQuantity = qty;
                            });
                          } else if (qty != null && qty > currentQuantity) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Cannot sell more than available stock ($currentQuantity units)',
                                ),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller:
                            TextEditingController(text: sellingPrice.toString())
                              ..selection = TextSelection.collapsed(
                                offset: sellingPrice.toString().length,
                              ),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Selling Price *',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                          helperText: 'Enter selling price per unit',
                        ),
                        onChanged: (value) {
                          final price = double.tryParse(value);
                          if (price != null && price > 0) {
                            setDialogState(() {
                              tempPrice = price;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₹ ${(tempQuantity * tempPrice).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (tempQuantity > 0 &&
                          tempQuantity <= currentQuantity &&
                          tempPrice > 0) {
                        selectedQuantity = tempQuantity;
                        sellingPrice = tempPrice;
                        Navigator.pop(context, true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter valid quantity and price',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Continue to Bill'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true) {
        setState(() => _selectedModelForAction = null);
        return;
      }

      setState(() {
        _selectedModelForAction = null;
      });

      final productData = {
        'productName': modelData['productName'],
        'productBrand': modelData['productBrand'],
        'productPrice': sellingPrice,
        'quantity': selectedQuantity,
        'modelId': modelId,
        'sellingPrice': sellingPrice,
        'totalAmount': selectedQuantity * sellingPrice,
        'category': _fixedCategory,
      };

      final gstResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              GSTAccessoriesSaleUpload(productData: productData),
        ),
      );

      if (gstResult == true && mounted) {
        setState(() => _isLoading = true);

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.user;

        if (selectedQuantity == currentQuantity) {
          await _firestore.collection('applianceStock').doc(modelId).update({
            'status': 'sold',
            'soldAt': FieldValue.serverTimestamp(),
            'soldBy': user?.email ?? user?.name ?? 'Unknown',
            'soldById': user?.uid ?? '',
            'sellingPrice': sellingPrice,
            'soldQuantity': selectedQuantity,
            'billGenerated': true,
            'billGeneratedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await _firestore.collection('applianceStock').doc(modelId).update({
            'quantity': currentQuantity - selectedQuantity,
            'lastUpdatedAt': FieldValue.serverTimestamp(),
            'lastUpdatedBy': user?.email ?? user?.name ?? 'Unknown',
          });

          final soldRecord = {
            'category': _fixedCategory,
            'productBrand': modelData['productBrand'],
            'productName': modelData['productName'],
            'productPrice': modelData['productPrice'],
            'quantity': selectedQuantity,
            'sellingPrice': sellingPrice,
            'totalAmount': selectedQuantity * sellingPrice,
            'shopId': modelData['shopId'],
            'shopName': modelData['shopName'],
            'soldBy': user?.email ?? user?.name ?? 'Unknown',
            'soldById': user?.uid ?? '',
            'soldAt': FieldValue.serverTimestamp(),
            'originalStockId': modelId,
            'billGenerated': true,
            'billGeneratedAt': FieldValue.serverTimestamp(),
          };

          await _firestore.collection('applianceSoldRecords').add(soldRecord);
        }

        setState(() => _isLoading = false);
        _showSuccess(
          '$selectedQuantity unit(s) sold and bill generated successfully!',
        );
      }
    } catch (e) {
      print('Error in _markAsSold: $e');
      if (mounted) {
        _showError('Failed to process sale: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _transferToShop(
    String modelId,
    Map<String, dynamic> modelData,
    String newShopId,
    String newShopName,
  ) async {
    try {
      final currentQuantity = modelData['quantity'] as int? ?? 1;
      int transferQuantity = 1;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          int tempQuantity = 1;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Transfer Appliance'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                            'Product: ${modelData['productName']}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Brand: ${modelData['productBrand']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Available Quantity:',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '$currentQuantity units',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: TextEditingController(text: '1')
                        ..selection = TextSelection.collapsed(offset: 1),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity to Transfer *',
                        border: OutlineInputBorder(),
                        helperText: 'Enter quantity to transfer',
                      ),
                      onChanged: (value) {
                        final qty = int.tryParse(value);
                        if (qty != null && qty > 0 && qty <= currentQuantity) {
                          setDialogState(() {
                            tempQuantity = qty;
                          });
                        } else if (qty != null && qty > currentQuantity) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cannot transfer more than available stock ($currentQuantity units)',
                              ),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.store, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Transfer to: $newShopName',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (tempQuantity > 0 && tempQuantity <= currentQuantity) {
                        transferQuantity = tempQuantity;
                        Navigator.pop(context, true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter valid quantity'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Transfer'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true) {
        setState(() => _selectedModelForAction = null);
        return;
      }

      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      final currentShopId = modelData['shopId'] as String? ?? '';
      final currentShopName =
          modelData['shopName'] as String? ?? 'Unknown Shop';

      final existingTargetQuery = await _firestore
          .collection('applianceStock')
          .where('shopId', isEqualTo: newShopId)
          .where('category', isEqualTo: _fixedCategory)
          .where('productBrand', isEqualTo: modelData['productBrand'])
          .where('productName', isEqualTo: modelData['productName'])
          .where('status', isEqualTo: 'available')
          .limit(1)
          .get();

      if (transferQuantity == currentQuantity) {
        await _firestore.collection('applianceStock').doc(modelId).update({
          'shopId': newShopId,
          'shopName': newShopName,
          'transferredBy': user?.email ?? user?.name ?? 'Unknown',
          'transferredById': user?.uid ?? '',
          'transferredAt': FieldValue.serverTimestamp(),
          'previousShopId': currentShopId,
          'previousShopName': currentShopName,
          'quantity': transferQuantity,
        });
      } else {
        await _firestore.collection('applianceStock').doc(modelId).update({
          'quantity': currentQuantity - transferQuantity,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': user?.email ?? user?.name ?? 'Unknown',
        });

        if (existingTargetQuery.docs.isNotEmpty) {
          final targetDoc = existingTargetQuery.docs.first;
          final targetData = targetDoc.data();
          final targetQuantity = targetData['quantity'] as int? ?? 0;

          await _firestore
              .collection('applianceStock')
              .doc(targetDoc.id)
              .update({
                'quantity': targetQuantity + transferQuantity,
                'lastUpdatedAt': FieldValue.serverTimestamp(),
                'lastUpdatedBy': user?.email ?? user?.name ?? 'Unknown',
              });
        } else {
          final newStockData = {
            'category': _fixedCategory,
            'productBrand': modelData['productBrand'],
            'productName': modelData['productName'],
            'productPrice': modelData['productPrice'],
            'quantity': transferQuantity,
            'shopId': newShopId,
            'shopName': newShopName,
            'uploadedBy': user?.email ?? user?.name ?? 'Unknown',
            'uploadedById': user?.uid ?? '',
            'uploadedAt': FieldValue.serverTimestamp(),
            'status': 'available',
            'createdAt': FieldValue.serverTimestamp(),
            'transferredFrom': currentShopId,
            'transferredFromName': currentShopName,
            'transferredAt': FieldValue.serverTimestamp(),
          };
          await _firestore.collection('applianceStock').add(newStockData);
        }
      }

      setState(() {
        _selectedModelForAction = null;
        _isLoading = false;
      });

      _showSuccess(
        '$transferQuantity unit(s) transferred to $newShopName successfully!',
      );
    } catch (e) {
      _showError('Failed to transfer: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _returnModel(
    String modelId,
    Map<String, dynamic> modelData,
  ) async {
    try {
      final currentQuantity = modelData['quantity'] as int? ?? 1;
      int returnQuantity = 1;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          int tempQuantity = 1;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Return Appliance'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                            'Product: ${modelData['productName']}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Brand: ${modelData['productBrand']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Available Quantity:',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '$currentQuantity units',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: TextEditingController(text: '1')
                        ..selection = TextSelection.collapsed(offset: 1),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity to Return *',
                        border: OutlineInputBorder(),
                        helperText: 'Enter quantity to return',
                      ),
                      onChanged: (value) {
                        final qty = int.tryParse(value);
                        if (qty != null && qty > 0 && qty <= currentQuantity) {
                          setDialogState(() {
                            tempQuantity = qty;
                          });
                        } else if (qty != null && qty > currentQuantity) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cannot return more than available stock ($currentQuantity units)',
                              ),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'This will remove the selected quantity from available stock and create a return record.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (tempQuantity > 0 && tempQuantity <= currentQuantity) {
                        returnQuantity = tempQuantity;
                        Navigator.pop(context, true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter valid quantity'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Return'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true) {
        setState(() => _selectedModelForAction = null);
        return;
      }

      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      final returnData = {
        'modelId': modelId,
        'category': _fixedCategory,
        'productBrand': modelData['productBrand'] ?? 'Unknown',
        'productName': modelData['productName'] ?? 'Unknown',
        'productPrice': modelData['productPrice'] ?? 0,
        'quantity': returnQuantity,
        'originalShopId': modelData['shopId'] ?? '',
        'originalShopName': modelData['shopName'] ?? 'Unknown Shop',
        'returnedBy': user?.email ?? user?.name ?? 'Unknown',
        'returnedById': user?.uid ?? '',
        'returnedAt': FieldValue.serverTimestamp(),
        'reason': 'returned_to_inventory',
        'status': 'returned',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('applianceReturns').add(returnData);

      if (returnQuantity == currentQuantity) {
        await _firestore.collection('applianceStock').doc(modelId).delete();
      } else {
        await _firestore.collection('applianceStock').doc(modelId).update({
          'quantity': currentQuantity - returnQuantity,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': user?.email ?? user?.name ?? 'Unknown',
        });
      }

      setState(() {
        _selectedModelForAction = null;
        _isLoading = false;
      });

      _showSuccess('$returnQuantity unit(s) returned successfully!');
    } catch (e) {
      _showError('Failed to return: $e');
      setState(() => _isLoading = false);
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

  Widget _buildBrandDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedBrand,
          decoration: const InputDecoration(
            labelText: 'Select Brand *',
            border: OutlineInputBorder(),
            labelStyle: TextStyle(fontSize: 12),
          ),
          style: const TextStyle(fontSize: 12),
          items: [
            ..._brands.map((brand) {
              return DropdownMenuItem(value: brand, child: Text(brand));
            }),
            const DropdownMenuItem(
              value: 'add_new_brand',
              child: Row(
                children: [
                  Icon(Icons.add, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Add New Brand', style: TextStyle(color: Colors.blue)),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value == 'add_new_brand') {
              setState(() {
                _showAddBrandModal = true;
                _newBrandController.clear();
              });
            } else {
              setState(() {
                _selectedBrand = value;
                _selectedProduct = null;
                _showAddProductForm = false;
                _showPriceChangeOption = false;
                _productSearchController.clear();
                _priceChangeController.clear();
                _clearModalMessages();
                // Reset quantity when brand changes
                _quantity = null;
              });
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty || value == 'add_new_brand') {
              return 'Please select a brand';
            }
            return null;
          },
        ),
        if (_brands.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, size: 14, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'No brands available. Click "Add New Brand" to create one.',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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
      final uniqueProductsMap = <String, Map<String, dynamic>>{};
      for (final product in products) {
        final productName = product['productName'] as String? ?? '';
        if (productName.toLowerCase().contains(searchText)) {
          uniqueProductsMap[productName] = product;
        }
      }
      _filteredProducts = uniqueProductsMap.values.toList();
    } else {
      final uniqueProductsMap = <String, Map<String, dynamic>>{};
      for (final product in products) {
        final productName = product['productName'] as String? ?? '';
        uniqueProductsMap[productName] = product;
      }
      _filteredProducts = uniqueProductsMap.values.toList();
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
                        // Reset quantity when product is cleared
                        _quantity = null;
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
                // Reset quantity when product search changes
                _quantity = null;
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
                // Reset quantity when tapping to change product
                _quantity = null;
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
                      // Reset quantity when changing product
                      _quantity = null;
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

  Widget _buildProductList() {
    if (_selectedBrand == null) return const SizedBox();

    final brandHasNoProducts =
        !_productsByBrand.containsKey(_selectedBrand!) ||
        (_productsByBrand[_selectedBrand!] ?? []).isEmpty;

    final searchHasNoResults =
        _productSearchController.text.isNotEmpty && _filteredProducts.isEmpty;

    final shouldShowAddNew = brandHasNoProducts || searchHasNoResults;

    final uniqueProducts = <Map<String, dynamic>>[];
    final seenNames = <String>{};

    for (final product in _filteredProducts) {
      final name = product['productName'] as String? ?? '';
      if (name.isNotEmpty && !seenNames.contains(name)) {
        seenNames.add(name);
        uniqueProducts.add(product);
      }
    }

    if (uniqueProducts.isEmpty && !shouldShowAddNew) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No products available for this brand',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: uniqueProducts.length + (shouldShowAddNew ? 1 : 0),
      itemBuilder: (context, index) {
        if (shouldShowAddNew && index == uniqueProducts.length) {
          return _buildAddNewProductTile();
        }

        final product = uniqueProducts[index];
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
      key: const ValueKey('add_new_product_tile'),
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

  Widget _buildAddBrandModal() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add New Brand',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newBrandController,
                decoration: const InputDecoration(
                  labelText: 'Brand Name *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _showAddBrandModal = false;
                          _newBrandController.clear();
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _addNewBrand,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
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
                          : const Text('Add Brand'),
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

  Widget _buildAddStockModal() {
    // Determine if product is selected (either existing or in add product form)
    final isProductSelected = _selectedProduct != null || _showAddProductForm;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
          maxWidth: 500,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(15),
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
                      'Add Appliance Stock',
                      style: TextStyle(
                        fontSize: 18,
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
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.category, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Category: $_fixedCategory',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_modalError != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _modalError!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_modalSuccess != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
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
                              fontSize: 11,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildBrandDropdown(),
                const SizedBox(height: 12),

                _buildProductSearchDropdown(),
                const SizedBox(height: 12),

                if (_showPriceChangeOption)
                  TextFormField(
                    controller: _priceChangeController,
                    decoration: const InputDecoration(
                      labelText: 'Price (Optional - Change if needed)',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                      labelStyle: TextStyle(fontSize: 12),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12),
                    onChanged: (_) => _clearModalMessages(),
                  ),

                if (_showAddProductForm) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newProductNameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(fontSize: 12),
                    ),
                    style: const TextStyle(fontSize: 12),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter product name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newProductPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Price *',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                      labelStyle: TextStyle(fontSize: 12),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter price';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price <= 0) {
                        return 'Please enter valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _cancelAddNewProduct,
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
                          onPressed: _saveNewProduct,
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
                                  'Save Product',
                                  style: TextStyle(fontSize: 12),
                                ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Only show quantity field if product is selected
                  if (isProductSelected) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                        border: OutlineInputBorder(),
                        labelStyle: TextStyle(fontSize: 12),
                      ),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 12),
                      onChanged: _handleQuantityChange,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter quantity';
                        }
                        final qty = int.tryParse(value);
                        if (qty == null || qty <= 0) {
                          return 'Please enter valid quantity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Please select a product first to enter quantity',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _closeAddStockModal,
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
                          onPressed: isProductSelected ? _saveStock : null,
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
                                  'Add to Stock',
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
      ),
    );
  }

  Widget _buildActionModal() {
    if (_selectedModelForAction == null) return const SizedBox();

    final model = _selectedModelForAction!;
    final productName = model['productName'] as String? ?? 'Unknown';
    final productBrand = model['productBrand'] as String? ?? 'Unknown';
    final price = model['productPrice'];
    final currentShopId = model['shopId'] as String? ?? '';
    final currentShopName = model['shopName'] as String? ?? 'Unknown Shop';
    final quantity = model['quantity'] as int? ?? 1;
    final modelId = model['id'] as String? ?? '';

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
                        ? 'Sell Appliance'
                        : _selectedAction == 'transfer'
                        ? 'Transfer Appliance'
                        : 'Return Appliance',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() => _selectedModelForAction = null);
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
                    Text(
                      'Category: $_fixedCategory',
                      style: const TextStyle(fontSize: 12),
                    ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Quantity: $quantity unit(s)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current Shop: $currentShopName',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (_selectedAction == 'sell') ...[
                const Text(
                  'Enter selling details:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _sellQuantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity to Sell *',
                    border: OutlineInputBorder(),
                    helperText: 'Enter quantity to sell',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sellPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Selling Price *',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                    helperText: 'Enter selling price per unit',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _sellQuantityController.clear();
                          _sellPriceController.clear();
                          setState(() => _selectedModelForAction = null);
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
                                final qtyText = _sellQuantityController.text;
                                final qty = int.tryParse(qtyText);
                                final priceText = _sellPriceController.text;
                                final salePrice = double.tryParse(priceText);

                                if (qty == null || qty <= 0) {
                                  _showError('Please enter valid quantity');
                                  return;
                                }
                                if (qty > quantity) {
                                  _showError(
                                    'Cannot sell more than available stock ($quantity units)',
                                  );
                                  return;
                                }
                                if (salePrice == null || salePrice <= 0) {
                                  _showError(
                                    'Please enter valid selling price',
                                  );
                                  return;
                                }

                                setState(() => _selectedModelForAction = null);

                                final productData = {
                                  'productName': productName,
                                  'productBrand': productBrand,
                                  'productPrice': salePrice,
                                  'quantity': qty,
                                  'modelId': modelId,
                                  'sellingPrice': salePrice,
                                  'totalAmount': qty * salePrice,
                                  'category': _fixedCategory,
                                };

                                final gstResult = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        GSTAccessoriesSaleUpload(
                                          productData: productData,
                                        ),
                                  ),
                                );

                                if (gstResult == true && mounted) {
                                  setState(() => _isLoading = true);
                                  final authProvider =
                                      Provider.of<AuthProvider>(
                                        context,
                                        listen: false,
                                      );
                                  final user = authProvider.user;

                                  if (qty == quantity) {
                                    await _firestore
                                        .collection('applianceStock')
                                        .doc(modelId)
                                        .update({
                                          'status': 'sold',
                                          'soldAt':
                                              FieldValue.serverTimestamp(),
                                          'soldBy':
                                              user?.email ??
                                              user?.name ??
                                              'Unknown',
                                          'soldById': user?.uid ?? '',
                                          'sellingPrice': salePrice,
                                          'soldQuantity': qty,
                                          'billGenerated': true,
                                          'billGeneratedAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                  } else {
                                    await _firestore
                                        .collection('applianceStock')
                                        .doc(modelId)
                                        .update({
                                          'quantity': quantity - qty,
                                          'lastUpdatedAt':
                                              FieldValue.serverTimestamp(),
                                          'lastUpdatedBy':
                                              user?.email ??
                                              user?.name ??
                                              'Unknown',
                                        });

                                    final soldRecord = {
                                      'category': _fixedCategory,
                                      'productBrand': productBrand,
                                      'productName': productName,
                                      'productPrice': price,
                                      'quantity': qty,
                                      'sellingPrice': salePrice,
                                      'totalAmount': qty * salePrice,
                                      'shopId': currentShopId,
                                      'shopName': currentShopName,
                                      'soldBy':
                                          user?.email ??
                                          user?.name ??
                                          'Unknown',
                                      'soldById': user?.uid ?? '',
                                      'soldAt': FieldValue.serverTimestamp(),
                                      'originalStockId': modelId,
                                      'billGenerated': true,
                                      'billGeneratedAt':
                                          FieldValue.serverTimestamp(),
                                    };

                                    await _firestore
                                        .collection('applianceSoldRecords')
                                        .add(soldRecord);
                                  }

                                  setState(() => _isLoading = false);
                                  _showSuccess(
                                    '$qty unit(s) sold and bill generated successfully!',
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
                                'Generate Bill',
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
                  Column(
                    children: [
                      TextFormField(
                        controller: _transferQuantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity to Transfer *',
                          border: OutlineInputBorder(),
                          helperText: 'Enter quantity to transfer',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
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
                                color: Colors.green,
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
                                      final qtyText =
                                          _transferQuantityController.text;
                                      final qty = int.tryParse(qtyText);
                                      if (qty == null || qty <= 0) {
                                        _showError(
                                          'Please enter valid quantity',
                                        );
                                        return;
                                      }
                                      if (qty > quantity) {
                                        _showError(
                                          'Cannot transfer more than available stock ($quantity units)',
                                        );
                                        return;
                                      }
                                      await _transferToShop(
                                        modelId,
                                        model,
                                        shop['id'] as String? ?? '',
                                        shop['name'] as String? ??
                                            'Unknown Shop',
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
                    ],
                  ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                _transferQuantityController.clear();
                                setState(() => _selectedModelForAction = null);
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
                  'Enter return details:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available quantity: $quantity unit(s)',
                  style: const TextStyle(fontSize: 11, color: Colors.green),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _returnQuantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity to Return *',
                    border: OutlineInputBorder(),
                    helperText: 'Enter quantity to return',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will remove the selected quantity from available stock and create a return record.',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _returnQuantityController.clear();
                          setState(() => _selectedModelForAction = null);
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
                                final qtyText = _returnQuantityController.text;
                                final qty = int.tryParse(qtyText);
                                if (qty == null || qty <= 0) {
                                  _showError('Please enter valid quantity');
                                  return;
                                }
                                if (qty > quantity) {
                                  _showError(
                                    'Cannot return more than available stock ($quantity units)',
                                  );
                                  return;
                                }
                                _returnModel(modelId, model);
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
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        labelText: 'Search by product name, brand, or serial',
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                  _searchFocusNode.unfocus();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.green.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      style: const TextStyle(fontSize: 13, color: Colors.black),
      onChanged: (value) {
        setState(() => _searchQuery = value);
      },
      onSubmitted: (value) {
        _searchFocusNode.unfocus();
      },
    );
  }

  Widget _buildQuickScanButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        _showError('Scanner feature coming soon for appliances');
      },
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text('Scan'),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      elevation: 4,
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

  Widget _buildModelCard({
    required String productName,
    required String productBrand,
    required int quantity,
    required dynamic price,
    required dynamic uploadedAt,
    dynamic soldAt,
    required String status,
    Map<String, dynamic>? modelData,
    VoidCallback? onSell,
    VoidCallback? onTransfer,
    VoidCallback? onReturn,
  }) {
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

    final transferredBy = modelData?['transferredBy'] as String?;
    final transferredAt = modelData?['transferredAt'];

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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: status == 'available'
                          ? Colors.green
                          : status == 'sold'
                          ? Colors.blue
                          : Colors.grey,
                    ),
                  ),
                ),
                if (status == 'available')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Qty: $quantity',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              productName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Category: $_fixedCategory',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              _formatPrice(price),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              productBrand,
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            if (transferredBy != null && transferredAt != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    size: 12,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Transfer: $transferredBy',
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
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person, size: 10, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Added: ${_formatDate(uploadedAt)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (status == 'sold' && soldAt != null) ...[
              Row(
                children: [
                  const Icon(Icons.sell, size: 10, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Sold: ${_formatDate(soldAt)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (modelData?['soldBy'] != null)
                Row(
                  children: [
                    const Icon(Icons.person, size: 10, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'By: ${modelData?['soldBy']}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
            if (status == 'available' &&
                (onSell != null || onTransfer != null || onReturn != null)) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onSell != null)
                    SizedBox(
                      width: 80,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: onSell,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text('Sell'),
                      ),
                    ),
                  if (onTransfer != null)
                    SizedBox(
                      width: 80,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: onTransfer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text('Transfer'),
                      ),
                    ),
                  if (onReturn != null)
                    SizedBox(
                      width: 80,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: onReturn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text('Return'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReturnedModelCard({
    required String productName,
    required String productBrand,
    required int quantity,
    required dynamic price,
    required dynamic returnedAt,
    required String returnedBy,
    required String reason,
    required String originalShopName,
  }) {
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'RETURNED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Qty: $quantity',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              productName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatPrice(price),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              productBrand,
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.assignment_return,
                  size: 10,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Returned: ${_formatDate(returnedAt)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.person, size: 10, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'By: $returnedBy',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.store, size: 10, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Shop: $originalShopName',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
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

  Widget _buildStockList(String type) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final currentShopId = user?.shopId;

    if (type == 'returned') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('applianceReturns')
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
                      'Error loading returned appliances: ${snapshot.error}',
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
                    'No returned appliances',
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
          int totalModels = 0;
          final Map<String, Map<String, dynamic>> brandStats = {};

          for (final data in filteredReturns) {
            final price =
                _parsePrice(data['productPrice']) *
                (data['quantity'] as int? ?? 1);
            final brand = data['productBrand'] as String? ?? 'Unknown';
            final qty = data['quantity'] as int? ?? 1;

            totalModels += qty;
            totalValue += price;

            if (!brandStats.containsKey(brand)) {
              brandStats[brand] = {'count': 0, 'value': 0.0};
            }

            brandStats[brand]!['count'] = brandStats[brand]!['count'] + qty;
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
                        '$totalModels units',
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
                      'Returned Units: $totalModels',
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
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filteredReturns.length,
                  itemBuilder: (context, index) {
                    final returnData = filteredReturns[index];
                    final productName =
                        returnData['productName'] as String? ?? 'Unknown';
                    final productBrand =
                        returnData['productBrand'] as String? ?? 'Unknown';
                    final quantity = returnData['quantity'] as int? ?? 1;
                    final price = returnData['productPrice'];
                    final returnedAt = returnData['returnedAt'];
                    final returnedBy = returnData['returnedBy'] ?? 'Unknown';
                    final reason =
                        returnData['reason'] ?? 'returned_to_inventory';
                    final originalShopName =
                        returnData['originalShopName'] ?? 'Unknown Shop';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildReturnedModelCard(
                        productName: productName,
                        productBrand: productBrand,
                        quantity: quantity,
                        price: price,
                        returnedAt: returnedAt,
                        returnedBy: returnedBy,
                        reason: reason,
                        originalShopName: originalShopName,
                      ),
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
            .collection('applianceStock')
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
                        ? 'No available appliances'
                        : 'No sold appliances',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  if (type == 'available')
                    ElevatedButton.icon(
                      onPressed: _openAddStockModal,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Add First Appliance',
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
                  Text(
                    'Try different search',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          double totalValue = 0;
          int totalUnits = 0;
          final Map<String, Map<String, dynamic>> brandStats = {};

          for (final data in filteredStocks) {
            final qty = data['quantity'] as int? ?? 1;
            final price = _parsePrice(data['productPrice']) * qty;
            final brand = data['productBrand'] as String? ?? 'Unknown';

            totalUnits += qty;
            totalValue += price;

            if (!brandStats.containsKey(brand)) {
              brandStats[brand] = {'count': 0, 'value': 0.0};
            }

            brandStats[brand]!['count'] = brandStats[brand]!['count'] + qty;
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
                        '$totalUnits units',
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
                      'Total Units: $totalUnits',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      'Items: ${filteredStocks.length}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filteredStocks.length,
                  itemBuilder: (context, index) {
                    final stock = filteredStocks[index];
                    final productName =
                        stock['productName'] as String? ?? 'Unknown';
                    final productBrand =
                        stock['productBrand'] as String? ?? 'Unknown';
                    final quantity = stock['quantity'] as int? ?? 1;
                    final price = stock['productPrice'];
                    final uploadedAt = stock['uploadedAt'];
                    final soldAt = stock['soldAt'];
                    final modelId = stock['id'] as String? ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildModelCard(
                        productName: productName,
                        productBrand: productBrand,
                        quantity: quantity,
                        price: price,
                        uploadedAt: uploadedAt,
                        soldAt: soldAt,
                        status: type,
                        modelData: stock,
                        onSell: type == 'available'
                            ? () {
                                setState(() {
                                  _selectedModelForAction = {
                                    ...stock,
                                    'id': modelId,
                                  };
                                  _selectedAction = 'sell';
                                  _sellQuantityController.text = '1';
                                  _sellPriceController.text =
                                      price?.toString() ?? '';
                                });
                              }
                            : null,
                        onTransfer: type == 'available'
                            ? () {
                                setState(() {
                                  _selectedModelForAction = {
                                    ...stock,
                                    'id': modelId,
                                  };
                                  _selectedAction = 'transfer';
                                  _transferQuantityController.text = '1';
                                });
                              }
                            : null,
                        onReturn: type == 'available'
                            ? () {
                                setState(() {
                                  _selectedModelForAction = {
                                    ...stock,
                                    'id': modelId,
                                  };
                                  _selectedAction = 'return';
                                  _returnQuantityController.text = '1';
                                });
                              }
                            : null,
                      ),
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
                'Appliances Stock',
                style: TextStyle(fontSize: 16),
              ),
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

          if (_showAddStockModal || _selectedModelForAction != null)
            Container(
              color: Colors.black.withOpacity(0.5),
              width: double.infinity,
              height: double.infinity,
            ),

          if (_showAddStockModal) _buildAddStockModal(),
          if (_showAddBrandModal) _buildAddBrandModal(),
          if (_selectedModelForAction != null) _buildActionModal(),
        ],
      ),
    );
  }
}
