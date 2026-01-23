import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sales_stock/screens/user/stock_check_screen.dart';
import '../../providers/auth_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // For adding stock
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

  @override
  void initState() {
    super.initState();
    // Initialize controllers in initState
    _productSearchController = TextEditingController();
    _priceChangeController = TextEditingController();
    _loadExistingProducts();
  }

  @override
  void dispose() {
    _productSearchController.dispose();
    _priceChangeController.dispose();
    _disposeImeiControllers();
    super.dispose();
  }

  void _disposeImeiControllers() {
    for (var controller in _imeiControllers) {
      controller.dispose();
    }
    _imeiControllers.clear();
  }

  // FIXED: Enhanced Smart Search Logic that handles "vivo y19s 4/64" properly
  bool _isProductMatch(String productName, String searchQuery) {
    if (searchQuery.isEmpty) return true;
    
    final query = searchQuery.toLowerCase().trim();
    final productText = productName.toLowerCase();

    // Split search query into words
    final searchWords = query
        .split(RegExp(r'[\s/]+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // If there's only one word, try to match it in different ways
    if (searchWords.length == 1) {
      final word = searchWords.first;
      
      // Check if word contains digits (like y19s, 4/64, etc.)
      if (RegExp(r'\d').hasMatch(word)) {
        // For model numbers like "y19s"
        if (productText.contains(word)) return true;
        
        // For RAM/storage like "4/64"
        if (word.contains('/')) {
          final parts = word.split('/');
          if (parts.length == 2) {
            final ram = parts[0];
            final storage = parts[1];
            // Check for variations like "4/64", "4 64", "4gb/64gb", etc.
            final ramVariations = ['$ram', '${ram}gb', '$ram gb', '$ram/gb'];
            final storageVariations = ['$storage', '${storage}gb', '$storage gb', '$storage/gb'];
            
            for (final ramVar in ramVariations) {
              for (final storageVar in storageVariations) {
                if (productText.contains(ramVar) && productText.contains(storageVar)) {
                  return true;
                }
              }
            }
          }
        }
        
        // For standalone numbers like "4" or "64"
        if (RegExp(r'^\d+$').hasMatch(word)) {
          // Check if number appears in the product name
          if (productText.contains(word)) {
            // Make sure it's not part of a larger number
            final regex = RegExp(r'\b' + word + r'\b');
            if (regex.hasMatch(productText)) {
              return true;
            }
          }
        }
      }
      
      // For text-only words
      return productText.contains(word);
    }

    // For multiple words, all must be found
    for (final word in searchWords) {
      bool wordFound = false;
      
      // Clean the word (remove special characters)
      final cleanWord = word.replaceAll(RegExp(r'[^a-z0-9]'), '');
      
      if (cleanWord.isEmpty) continue;
      
      // Check different variations
      final variations = <String>[
        cleanWord,
        word,
      ];
      
      // Handle RAM/storage numbers
      if (RegExp(r'^\d+$').hasMatch(cleanWord)) {
        variations.add('${cleanWord}gb');
        variations.add('${cleanWord} gb');
        variations.add('${cleanWord}/');
      }
      
      // Check all variations
      for (final variation in variations) {
        if (variation.isNotEmpty && productText.contains(variation)) {
          wordFound = true;
          break;
        }
      }
      
      // Also check for partial matches for model numbers
      if (!wordFound && cleanWord.length >= 2) {
        // Check if any part of the product text contains this word
        final regex = RegExp(cleanWord, caseSensitive: false);
        if (regex.hasMatch(productText)) {
          wordFound = true;
        }
      }
      
      if (!wordFound) {
        return false;
      }
    }
    
    return true;
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
        _clearMessages();
      });
    } else {
      setState(() {
        _selectedProduct = value;
        _showAddProductForm = false;

        // Set the product name in search controller
        _productSearchController.text = value ?? '';

        _clearMessages();

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
      _clearMessages();
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
        _clearMessages();
      });
    } else if (value.isEmpty) {
      _disposeImeiControllers();
      setState(() {
        _quantity = null;
        _imeiNumbers = [];
        _clearMessages();
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
        _clearMessages();
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
        _clearMessages();
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

      // Enhanced IMEI validation
      for (int i = 0; i < _imeiNumbers.length; i++) {
        final imei = _imeiNumbers[i];
        if (imei.isEmpty) {
          _showModalError('Please enter IMEI number for item ${i + 1}');
          return;
        }

        // Basic validation
        if (imei.length < 15 || imei.length > 16) {
          _showModalError(
            'IMEI ${i + 1} must be 15-16 digits (${imei.length} entered)',
          );
          return;
        }

        // Check if all characters are digits
        if (!RegExp(r'^[0-9]+$').hasMatch(imei)) {
          _showModalError('IMEI ${i + 1} contains non-numeric characters');
          return;
        }
      }

      // Check for duplicates in this batch
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

      // Check for duplicates in database
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

      // Reset form
      _resetForm();

      // Navigate back after success
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      print('Save stock error: $e');
      _showModalError('Failed to save stock: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetForm() {
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
      _clearMessages();
    });

    _productSearchController.clear();
    _priceChangeController.clear();

    _disposeImeiControllers();

    if (_formKey.currentState != null) {
      _formKey.currentState!.reset();
    }
  }

  // IMEI Scanner Methods - Simplified version
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
      builder: (context) => AlertDialog(
        title: Text('Scan IMEI ${index + 1}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Scan barcode for IMEI ${index + 1}'),
              const SizedBox(height: 20),
              Container(
                height: 200,
                color: Colors.black,
                child: Center(
                  child: Icon(
                    Icons.qr_code_scanner,
                    size: 80,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: Scanner functionality requires mobile_scanner package configuration',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // For testing, simulate a scanned IMEI
                  final simulatedImei = '123456789012345';
                  if (index < _imeiNumbers.length) {
                    setState(() {
                      _imeiNumbers[index] = simulatedImei;
                      if (index < _imeiControllers.length) {
                        _imeiControllers[index].text = simulatedImei;
                      }
                    });
                  }
                },
                child: const Text('Simulate Scan (Test)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _clearMessages() {
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

  // IMEI Helper Methods
  String _formatImeiForDisplay(String imei) {
    if (imei.isEmpty) return '';
    if (imei.length == 15) {
      return '${imei.substring(0, 6)} ${imei.substring(6, 12)} ${imei.substring(12)}';
    } else if (imei.length == 16) {
      return '${imei.substring(0, 8)} ${imei.substring(8)}';
    }
    return imei;
  }

  String _formatPrice(dynamic price) {
    try {
      if (price == null) return '₹0';
      if (price is int) {
        return '₹${price.toString()}';
      }
      if (price is double) {
        return '₹${price.toStringAsFixed(0)}';
      }
      return '₹0';
    } catch (e) {
      return '₹0';
    }
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
            maxLines: 2,
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
        );
      );
    }

    // Get products for selected brand
    final products = _productsByBrand[_selectedBrand!] ?? [];
    final searchText = _productSearchController.text;

    // Apply search filter
    if (searchText.isNotEmpty) {
      _filteredProducts = products.where((product) {
        final productName = product['productName'] as String? ?? '';
        // Use the enhanced search logic
        return _isProductMatch(productName, searchText);
      }).toList();
    } else {
      _filteredProducts = List.from(products);
    }

    return Column(
      children: [
        TextField(
          controller: _productSearchController,
          decoration: InputDecoration(
            labelText: 'Search Product (e.g., "y19s", "4/64", "vivo y19s 4/64")',
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
                        _clearMessages();
                      });
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            hintText: _selectedProduct != null
                ? _selectedProduct
                : 'Type to search products...',
          ),
          style: const TextStyle(fontSize: 12, color: Colors.black),
          onChanged: (value) {
            setState(() {
              // If user starts typing, clear the selected product
              if (_selectedProduct != null && value != _selectedProduct) {
                _selectedProduct = null;
                _showPriceChangeOption = false;
                _originalProductPrice = null;
                _priceChangeController.clear();
              }
              _clearMessages();
            });
          },
          onTap: () {
            // When user taps to search, show all products
            if (_selectedProduct != null &&
                _productSearchController.text == _selectedProduct) {
              _productSearchController.clear();
              setState(() {
                _clearMessages();
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

        // Show product dropdown only if no product is selected or user is searching
        if (_selectedProduct == null ||
            _productSearchController.text.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: _buildProductList(),
          ),

        // Show selected product info if a product is selected
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
                      const SizedBox(height: 4),
                      Text(
                        _selectedProduct!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                    _clearMessages();
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

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Phone Stock', style: TextStyle(fontSize: 16)),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          toolbarHeight: 56,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _selectedBrand,
                        dropdownColor: Colors.white,
                        decoration: const InputDecoration(
                          labelText: 'Select Brand *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.branding_watermark, size: 18),
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
                            _clearMessages();
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a brand';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      if (_selectedBrand != null) ...[
                        _buildProductSearchDropdown(),
                        const SizedBox(height: 16),

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
                                      _clearMessages();
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
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
                                      _newProductPrice = double.tryParse(value);
                                      _clearMessages();
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
                          const SizedBox(height: 16),
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
                                    _clearMessages();
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
                          const SizedBox(height: 16),
                        ],
                      ],

                      if (_selectedProduct != null || _showAddProductForm) ...[
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
                            _clearMessages();
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

                        const SizedBox(height: 16),
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

                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _quantity!,
                          itemBuilder: (context, index) {
                            return _buildImeiInputField(index);
                          },
                        ),

                        const SizedBox(height: 16),
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
                                onPressed: _clearMessages,
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
                                onPressed: _clearMessages,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),

                      Container(
                        padding: const EdgeInsets.only(top: 20, bottom: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
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
                                    vertical: 12,
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}