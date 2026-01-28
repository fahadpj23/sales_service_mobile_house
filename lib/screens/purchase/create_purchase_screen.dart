import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sales_stock/models/purchase_item.dart';
import 'package:sales_stock/services/firestore_service.dart';
import 'dart:math' as math;

class CreatePurchaseScreen extends StatefulWidget {
  final Map<String, dynamic>? supplier;

  const CreatePurchaseScreen({Key? key, this.supplier}) : super(key: key);

  @override
  State<CreatePurchaseScreen> createState() => _CreatePurchaseScreenState();
}

class _CreatePurchaseScreenState extends State<CreatePurchaseScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Color _primaryGreen = const Color(0xFF2E7D32);
  final Color _lightGreen = const Color(0xFF4CAF50);
  final Color _backgroundColor = const Color(0xFFF5F9F5);
  final Color _red = const Color(0xFFE53935);
  final Color _blue = const Color(0xFF2196F3);
  final Color _orange = const Color(0xFFFF9800);
  final Color _amber = const Color(0xFFFFB300);
  final Color _purple = const Color(0xFF9C27B0);
  final Color _pink = const Color(0xFFE91E63);
  final Color _teal = const Color(0xFF009688);
  final Color _indigo = const Color(0xFF3F51B5);

  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController();
  final _invoiceController = TextEditingController();
  final _notesController = TextEditingController();
  final _productSearchController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  Map<String, dynamic>? _selectedSupplier;
  List<PurchaseItem> _purchaseItems = [];

  double _subtotal = 0.0;
  double _gstAmount = 0.0;
  double _totalAmount = 0.0;
  double _totalDiscount = 0.0;
  double _roundOff = 0.0;
  bool _isSearching = false;
  MobileScannerController? _scannerController;
  bool _isScanning = false;
  int? _currentScanItemIndex;
  int? _currentScanImeiIndex;
  Map<int, bool> _showEditSections = {};
  bool _showPreview = false;
  Map<int, List<String>> _itemImeis = {}; // Track IMEIs per item

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
    _fetchProducts();
    if (widget.supplier != null) {
      _selectedSupplier = widget.supplier;
      _supplierController.text = widget.supplier!['name'] ?? '';
    }
    // Add one empty item initially
    _addNewItem();
  }

  @override
  void dispose() {
    _productSearchController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _fetchSuppliers() async {
    _suppliers = await _firestoreService.getSuppliers();
    setState(() {});
  }

  Future<void> _fetchProducts() async {
    _products = await _firestoreService.getProducts();
    _filteredProducts = List.from(_products);
    setState(() {});
  }

  void _filterProducts(String query) {
    if (query.isEmpty) {
      _filteredProducts = List.from(_products);
    } else {
      final searchQuery = query.toLowerCase().trim();
      final searchWords = searchQuery.split(' ');

      _filteredProducts = _products.where((product) {
        final productName = (product['productName'] ?? '')
            .toString()
            .toLowerCase();
        final brand = (product['brand'] ?? '').toString().toLowerCase();
        final combinedText = '$productName $brand';

        return searchWords.every((word) {
          if (word.isEmpty) return true;
          return combinedText.contains(word);
        });
      }).toList();
    }
    setState(() {});
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryGreen,
              onPrimary: Colors.white,
              onSurface: Colors.grey.shade800,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _primaryGreen),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _calculateTotals() {
    _subtotal = 0.0;
    _totalDiscount = 0.0;
    _gstAmount = 0.0;

    for (var item in _purchaseItems) {
      if (item.quantity != null && item.rate != null) {
        double itemTotal = item.quantity! * item.rate!;

        if (item.discountPercentage != null && item.discountPercentage! > 0) {
          double discountAmount = itemTotal * (item.discountPercentage! / 100);
          itemTotal -= discountAmount;
          _totalDiscount += discountAmount;
        }

        _subtotal += itemTotal;
        item.gstAmount = itemTotal * 0.18;
        _gstAmount += item.gstAmount!;
      }
    }

    _totalAmount = _subtotal + _gstAmount;
    _roundOff = _totalAmount.roundToDouble() - _totalAmount;
    _totalAmount = _totalAmount.roundToDouble();

    setState(() {});
  }

  void _addNewItem() {
    setState(() {
      final newIndex = _purchaseItems.length;
      _purchaseItems.add(PurchaseItem(discountPercentage: 0.0));
      _itemImeis[newIndex] = [];

      // Collapse ALL existing items
      for (var key in _showEditSections.keys) {
        _showEditSections[key] = false;
      }

      // Expand ONLY the new item
      _showEditSections[newIndex] = true;
    });
  }

  void _removeItem(int index) {
    if (_purchaseItems.length > 1) {
      setState(() {
        _purchaseItems.removeAt(index);

        // Create new maps to reindex everything properly
        final newPurchaseItems = <PurchaseItem>[];
        final newShowEditSections = <int, bool>{};
        final newItemImeis = <int, List<String>>{};

        for (int i = 0; i < _purchaseItems.length; i++) {
          newPurchaseItems.add(_purchaseItems[i]);

          if (i < index) {
            newShowEditSections[i] = _showEditSections[i] ?? false;
            newItemImeis[i] = _itemImeis[i] ?? [];
          } else {
            newShowEditSections[i] = _showEditSections[i + 1] ?? false;
            newItemImeis[i] = _itemImeis[i + 1] ?? [];
          }
        }

        _purchaseItems = newPurchaseItems;
        _showEditSections = newShowEditSections;
        _itemImeis = newItemImeis;

        _calculateTotals();
      });
    }
  }

  void _toggleEditSection(int index) {
    setState(() {
      final currentState = _showEditSections[index] ?? false;

      if (!currentState) {
        // If we're expanding this item, collapse all others first
        for (var key in _showEditSections.keys) {
          _showEditSections[key] = false;
        }
      }

      // Toggle the current item
      _showEditSections[index] = !currentState;
    });
  }

  Future<void> _showScannerDialog(int itemIndex, {int? imeiIndex}) async {
    _currentScanItemIndex = itemIndex;
    _currentScanImeiIndex = imeiIndex;
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 1000,
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  imeiIndex != null
                      ? 'Scan Serial ${imeiIndex + 1}'
                      : 'Scan IMEI/Serial Number *',
                  style: TextStyle(color: _pink, fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    _scannerController?.dispose();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            content: Container(
              height: 250,
              width: 250,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final barcode = barcodes.first;
                        if (barcode.rawValue != null) {
                          Navigator.pop(context);
                          _onScanComplete(barcode.rawValue!);
                        }
                      }
                    },
                  ),
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Position barcode within the frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showManualSerialEntry(itemIndex, imeiIndex: imeiIndex);
                },
                child: const Text(
                  'Enter Manually',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () {
                  _scannerController?.toggleTorch();
                },
                child: const Text(
                  'Toggle Flash',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onScanComplete(String scannedValue) {
    if (_currentScanItemIndex != null) {
      // Validate serial number is at least 10 characters
      if (!_isValidSerialNumber(scannedValue)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid Serial. Must be at least 10 characters. Scanned: $scannedValue',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        if (_currentScanImeiIndex != null) {
          // Update specific serial
          if ((_itemImeis[_currentScanItemIndex!]?.length ?? 0) >
              _currentScanImeiIndex!) {
            _itemImeis[_currentScanItemIndex!]![_currentScanImeiIndex!] =
                scannedValue;
          }
        } else {
          // Add new serial
          _itemImeis[_currentScanItemIndex!] ??= [];
          _itemImeis[_currentScanItemIndex!]!.add(scannedValue);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Serial scanned successfully ✓',
            style: TextStyle(fontSize: 12),
          ),
          backgroundColor: _lightGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _currentScanItemIndex = null;
    _currentScanImeiIndex = null;
  }

  bool _isValidSerialNumber(String serial) {
    // Allow both IMEI (15 digits) and Serial Numbers (can be alphanumeric and longer)
    // Minimum length check, you can adjust as needed
    return serial.isNotEmpty && serial.length >= 10;
  }

  Future<void> _showManualSerialEntry(int itemIndex, {int? imeiIndex}) async {
    final serialController = TextEditingController(
      text:
          imeiIndex != null && (_itemImeis[itemIndex]?.length ?? 0) > imeiIndex
          ? _itemImeis[itemIndex]![imeiIndex]
          : '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          imeiIndex != null
              ? 'Edit Serial ${imeiIndex + 1}'
              : 'Enter Serial Number *',
          style: TextStyle(color: _pink, fontSize: 14),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter IMEI or Serial Number for inventory tracking',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: serialController,
              maxLength: 30, // Increased for longer serial numbers
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Enter IMEI/Serial number...',
                hintStyle: const TextStyle(fontSize: 11),
                border: const OutlineInputBorder(),
                counterText: '',
                prefixIcon: Icon(
                  Icons.smartphone,
                  color: _primaryGreen,
                  size: 18,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => serialController.clear(),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: _primaryGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'For mobile phones: IMEI (15 digits). For other products: Serial Number',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (imeiIndex != null)
            TextButton(
              onPressed: () {
                setState(() {
                  if ((_itemImeis[itemIndex]?.length ?? 0) > imeiIndex) {
                    _itemImeis[itemIndex]!.removeAt(imeiIndex);
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Serial removed',
                      style: TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _amber,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: _red),
              child: const Text('Remove', style: TextStyle(fontSize: 12)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              final serial = serialController.text.trim();
              if (_isValidSerialNumber(serial)) {
                Navigator.pop(context);
                setState(() {
                  if (imeiIndex != null) {
                    // Edit existing serial
                    if ((_itemImeis[itemIndex]?.length ?? 0) > imeiIndex) {
                      _itemImeis[itemIndex]![imeiIndex] = serial;
                    }
                  } else {
                    // Add new serial
                    _itemImeis[itemIndex] ??= [];
                    _itemImeis[itemIndex]!.add(serial);
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Serial saved: ${serial.substring(0, math.min(serial.length, 8))}...',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _lightGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Serial must be at least 10 characters (${serial.length}/10)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              imeiIndex != null ? 'Update Serial' : 'Save Serial',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProductSelection(int itemIndex) async {
    final selectedProduct = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryGreen,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Product',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            _productSearchController.clear();
                            _filterProducts('');
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _productSearchController,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search by product name or brand...',
                          hintStyle: const TextStyle(fontSize: 11),
                          prefixIcon: Icon(
                            Icons.search,
                            color: _primaryGreen,
                            size: 18,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          suffixIcon: _productSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    _productSearchController.clear();
                                    _filterProducts('');
                                    setSheetState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          _filterProducts(value);
                          setSheetState(() {});
                        },
                      ),
                    ),
                  ),

                  // Results or Empty State
                  Expanded(
                    child: _filteredProducts.isEmpty
                        ? _buildEmptyProductState(setSheetState)
                        : _buildProductList(setSheetState),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (selectedProduct != null) {
      _handleProductSelection(itemIndex, selectedProduct);
    } else {
      _productSearchController.clear();
      _filterProducts('');
    }
  }

  Widget _buildEmptyProductState(StateSetter setSheetState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _productSearchController.text.isEmpty
              ? Icons.inventory_2_outlined
              : Icons.search_off,
          size: 60,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 16),
        Text(
          _productSearchController.text.isEmpty
              ? 'No products available'
              : 'Product not found',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _productSearchController.text.isEmpty
              ? 'Add your first product to continue'
              : 'Add "${_productSearchController.text}" as new product',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ElevatedButton.icon(
            onPressed: () async {
              final searchText = _productSearchController.text;
              Navigator.pop(context);
              await _showAddProductDialog(preFilledSearch: searchText);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _productSearchController.text.isEmpty
                  ? _lightGreen
                  : _orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
              'Add New Product',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductList(StateSetter setSheetState) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Found ${_filteredProducts.length} product${_filteredProducts.length != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              TextButton.icon(
                onPressed: () async {
                  final searchText = _productSearchController.text;
                  Navigator.pop(context);
                  await _showAddProductDialog(preFilledSearch: searchText);
                },
                style: TextButton.styleFrom(foregroundColor: _blue),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add New', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _filteredProducts.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = _filteredProducts[index];
              return _buildProductListItem(product, setSheetState);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductListItem(
    Map<String, dynamic> product,
    StateSetter setSheetState,
  ) {
    final hasPurchaseRate =
        product['purchaseRate'] != null &&
        (product['purchaseRate'] is num) &&
        product['purchaseRate'] > 0;
    final productName = product['productName'] ?? 'Unnamed Product';
    final brand = product['brand'] ?? '';
    final hsnCode = product['hsnCode'] ?? '';
    final purchaseRate = product['purchaseRate'] ?? 0.0;
    final price = product['price'] ?? 0.0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: hasPurchaseRate
              ? _lightGreen.withOpacity(0.1)
              : _amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.phone_android,
          size: 20,
          color: hasPurchaseRate ? _lightGreen : _amber,
        ),
      ),
      title: Text(
        productName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (brand.isNotEmpty)
            Text(
              brand,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                '₹${(purchaseRate as num).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _primaryGreen,
                ),
              ),
              const SizedBox(width: 6),
              if (price > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Sell: ₹${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 9,
                      color: _blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _lightGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.add, size: 16, color: Colors.green),
      ),
      onTap: () async {
        if (!hasPurchaseRate) {
          final newRate = await _showSetPurchaseRateDialog(productName);
          if (newRate != null) {
            await _firestoreService.updateProductPurchaseRate(
              product['id'] ?? '',
              newRate,
            );
            product['purchaseRate'] = newRate;
            await _fetchProducts();
            _productSearchController.clear();
            _filterProducts('');
            Navigator.pop(context, product);
          }
        } else {
          _productSearchController.clear();
          _filterProducts('');
          Navigator.pop(context, product);
        }
      },
    );
  }

  void _handleProductSelection(int itemIndex, Map<String, dynamic> product) {
    _productSearchController.clear();
    _filterProducts('');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Don\'t forget to add Serial Numbers for ${product['productName'] ?? 'this product'}',
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: _amber,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    });

    setState(() {
      _purchaseItems[itemIndex].productId = product['id'] ?? '';
      _purchaseItems[itemIndex].productName =
          product['productName'] ?? 'Unnamed Product';
      _purchaseItems[itemIndex].brand = product['brand'];
      _purchaseItems[itemIndex].hsnCode = product['hsnCode'] ?? '';

      final purchaseRate = product['purchaseRate'];
      if (purchaseRate != null && purchaseRate is num && purchaseRate > 0) {
        _purchaseItems[itemIndex].rate = purchaseRate.toDouble();
        _purchaseItems[itemIndex].gstAmount = purchaseRate.toDouble() * 0.18;
      }

      // Collapse all other items and expand only this one
      for (var key in _showEditSections.keys) {
        _showEditSections[key] = false;
      }
      _showEditSections[itemIndex] = true;

      _calculateTotals();
    });
  }

  Future<double?> _showSetPurchaseRateDialog(String productName) async {
    final rateController = TextEditingController();
    double? purchaseRate;

    return await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          purchaseRate = double.tryParse(rateController.text);

          return AlertDialog(
            title: Text(
              'Set Purchase Rate',
              style: TextStyle(color: _primaryGreen, fontSize: 14),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter the purchase rate (cost price):',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: rateController,
                    style: const TextStyle(fontSize: 12),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Purchase Rate',
                      labelStyle: const TextStyle(fontSize: 11),
                      hintText: 'Enter purchase rate...',
                      hintStyle: const TextStyle(fontSize: 11),
                      prefixText: '₹ ',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    autofocus: true,
                    onChanged: (value) => setState(() {}),
                  ),
                  if (purchaseRate != null && purchaseRate! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            _buildPriceCalculationRow(
                              'Cost Price:',
                              '₹${purchaseRate!.toStringAsFixed(2)}',
                            ),
                            _buildPriceCalculationRow(
                              'GST (18%):',
                              '₹${(purchaseRate! * 0.18).toStringAsFixed(2)}',
                            ),
                            const Divider(height: 12),
                            _buildPriceCalculationRow(
                              'Total Cost:',
                              '₹${(purchaseRate! * 1.18).toStringAsFixed(2)}',
                              isBold: true,
                              color: _primaryGreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _productSearchController.clear();
                  _filterProducts('');
                },
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (purchaseRate != null && purchaseRate! > 0) {
                    Navigator.pop(context, purchaseRate);
                    _productSearchController.clear();
                    _filterProducts('');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter a valid purchase rate',
                          style: TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _lightGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'Set Purchase Rate',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPriceCalculationRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: color ?? Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddProductDialog({String preFilledSearch = ''}) async {
    final brandController = TextEditingController();
    final productNameController = TextEditingController();
    final purchaseRateController = TextEditingController();
    final priceController = TextEditingController();
    final hsnController = TextEditingController();

    final List<String> brandList = [
      'Samsung',
      'Apple',
      'OnePlus',
      'Xiaomi',
      'Oppo',
      'Vivo',
      'Realme',
      'Nokia',
      'Motorola',
      'Google',
      'Nothing',
      'Asus',
      'LG',
      'Sony',
      'Huawei',
    ];
    String selectedBrand = '';

    if (preFilledSearch.isNotEmpty) {
      productNameController.text = preFilledSearch;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primaryGreen,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add New Product',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Form
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // Brand Dropdown
                        _buildFormSection(
                          label: 'Brand *',
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedBrand.isNotEmpty
                                    ? selectedBrand
                                    : null,
                                hint: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    'Select Brand',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: _primaryGreen,
                                  size: 18,
                                ),
                                isExpanded: true,
                                items: [
                                  ...brandList.map((brand) {
                                    return DropdownMenuItem(
                                      value: brand,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          brand,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  const DropdownMenuItem(
                                    value: 'other',
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.add, size: 14),
                                          SizedBox(width: 6),
                                          Text(
                                            'Add New Brand',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (String? newValue) {
                                  if (newValue == 'other') {
                                    _showAddBrandDialog().then((newBrand) {
                                      if (newBrand != null &&
                                          newBrand.isNotEmpty) {
                                        setState(() {
                                          brandList.add(newBrand);
                                          selectedBrand = newBrand;
                                        });
                                      }
                                    });
                                  } else {
                                    setState(() {
                                      selectedBrand = newValue ?? '';
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Product Name
                        _buildFormSection(
                          label: 'Product Name *',
                          child: TextField(
                            controller: productNameController,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'e.g., Galaxy S23 5G',
                              hintStyle: const TextStyle(fontSize: 11),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: Icon(
                                Icons.phone_android,
                                color: _primaryGreen,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // HSN Code
                        _buildFormSection(
                          label: 'HSN Code *',
                          child: TextField(
                            controller: hsnController,
                            style: const TextStyle(fontSize: 12),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'e.g., 85171300',
                              hintStyle: const TextStyle(fontSize: 11),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: Icon(
                                Icons.tag,
                                color: _primaryGreen,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _indigo.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: _indigo,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Common HSN for mobiles: 85171300 (18% GST)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _indigo,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Pricing Section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _lightGreen.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pricing Information',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Purchase Rate
                              _buildFormSection(
                                label: 'Purchase Rate (Cost Price) *',
                                child: TextField(
                                  controller: purchaseRateController,
                                  style: const TextStyle(fontSize: 12),
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter purchase rate',
                                    hintStyle: const TextStyle(fontSize: 11),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixText: '₹ ',
                                  ),
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Selling Price
                              _buildFormSection(
                                label: 'Selling Price *',
                                child: TextField(
                                  controller: priceController,
                                  style: const TextStyle(fontSize: 12),
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter selling price',
                                    hintStyle: const TextStyle(fontSize: 11),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixText: '₹ ',
                                  ),
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),

                              // Price Preview
                              if (purchaseRateController.text.isNotEmpty &&
                                  priceController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildPriceRow(
                                          'Cost:',
                                          purchaseRateController.text,
                                        ),
                                        _buildPriceRow(
                                          'Selling:',
                                          priceController.text,
                                        ),
                                        const Divider(height: 10),
                                        _buildPriceRow(
                                          'Margin:',
                                          '₹${(double.tryParse(priceController.text) ?? 0 - (double.tryParse(purchaseRateController.text) ?? 0)).toStringAsFixed(2)} '
                                              '(${(((double.tryParse(priceController.text) ?? 0) - (double.tryParse(purchaseRateController.text) ?? 0)) / (double.tryParse(purchaseRateController.text) ?? 1) * 100).toStringAsFixed(1)}%)',
                                          color: _lightGreen,
                                          isBold: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer Buttons
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_validateProductForm(
                                selectedBrand,
                                productNameController,
                                hsnController,
                                purchaseRateController,
                                priceController,
                              )) {
                                try {
                                  await _saveProduct(
                                    selectedBrand,
                                    productNameController,
                                    hsnController,
                                    purchaseRateController,
                                    priceController,
                                  );
                                  Navigator.pop(context);
                                } catch (e) {
                                  // Error handled in _saveProduct
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Save Product',
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
          );
        },
      ),
    );
  }

  bool _validateProductForm(
    String selectedBrand,
    TextEditingController productNameController,
    TextEditingController hsnController,
    TextEditingController purchaseRateController,
    TextEditingController priceController,
  ) {
    if (selectedBrand.isEmpty) {
      _showErrorSnackbar('Please select a brand');
      return false;
    }
    if (productNameController.text.isEmpty) {
      _showErrorSnackbar('Please enter product name');
      return false;
    }
    if (hsnController.text.isEmpty) {
      _showErrorSnackbar('Please enter HSN code');
      return false;
    }
    if (purchaseRateController.text.isEmpty) {
      _showErrorSnackbar('Please enter purchase rate');
      return false;
    }
    if (priceController.text.isEmpty) {
      _showErrorSnackbar('Please enter selling price');
      return false;
    }

    final purchaseRate = double.tryParse(purchaseRateController.text);
    final price = double.tryParse(priceController.text);

    if (purchaseRate == null || purchaseRate <= 0) {
      _showErrorSnackbar('Please enter a valid purchase rate');
      return false;
    }
    if (price == null || price <= 0) {
      _showErrorSnackbar('Please enter a valid selling price');
      return false;
    }
    if (price <= purchaseRate) {
      _showErrorSnackbar('Selling price must be greater than purchase rate');
      return false;
    }

    return true;
  }

  Future<void> _saveProduct(
    String selectedBrand,
    TextEditingController productNameController,
    TextEditingController hsnController,
    TextEditingController purchaseRateController,
    TextEditingController priceController,
  ) async {
    try {
      final productData = {
        'brand': selectedBrand,
        'productName': productNameController.text.trim(),
        'hsnCode': hsnController.text.trim(),
        'purchaseRate': double.parse(purchaseRateController.text),
        'price': double.parse(priceController.text),
        'stockQuantity': 0,
        'createdAt': DateTime.now(),
      };

      await _firestoreService.addProduct(productData);
      await _fetchProducts();

      _productSearchController.clear();
      _filterProducts('');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Product added successfully',
            style: TextStyle(fontSize: 12),
          ),
          backgroundColor: _lightGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Error adding product: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: _red,
      ),
    );
  }

  Widget _buildFormSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color ?? Colors.grey.shade800,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showAddBrandDialog() async {
    final brandController = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add New Brand',
          style: TextStyle(color: _primaryGreen, fontSize: 14),
        ),
        content: TextField(
          controller: brandController,
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Enter brand name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              final brand = brandController.text.trim();
              if (brand.isNotEmpty) {
                Navigator.pop(context, brand);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Add',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseItemCard(int index) {
    final item = _purchaseItems[index];
    final showEditSection = _showEditSections[index] ?? false;
    final requiredImeiCount = item.quantity?.toInt() ?? 1;
    final currentImeiCount = _itemImeis[index]?.length ?? 0;
    final hasAllImeis = currentImeiCount >= requiredImeiCount;
    final itemImeis = _itemImeis[index] ?? [];

    // Calculate item total
    double itemTotal = 0.0;
    double itemDiscount = 0.0;
    double itemGst = 0.0;
    if (item.quantity != null && item.rate != null) {
      itemTotal = item.quantity! * item.rate!;
      if (item.discountPercentage != null && item.discountPercentage! > 0) {
        itemDiscount = itemTotal * (item.discountPercentage! / 100);
        itemTotal -= itemDiscount;
      }
      itemGst = itemTotal * 0.18;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _lightGreen.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName ?? 'No Product Selected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.productName != null
                              ? Colors.grey.shade800
                              : Colors.grey.shade400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.brand != null)
                        Text(
                          item.brand!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (item.productId != null)
                  IconButton(
                    onPressed: () => _toggleEditSection(index),
                    icon: Icon(
                      showEditSection ? Icons.expand_less : Icons.expand_more,
                      color: _primaryGreen,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_purchaseItems.length > 1)
                  IconButton(
                    onPressed: () => _removeItem(index),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Product Selection
                GestureDetector(
                  onTap: () => _showProductSelection(index),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: item.productId != null
                            ? _lightGreen
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone_android,
                          color: item.productId != null
                              ? _lightGreen
                              : Colors.grey.shade400,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName ?? 'Tap to select product *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: item.productId != null
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),

                // Item Summary (Only shown when product is selected and edit section is collapsed)
                if (item.productId != null && !showEditSection) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Quantity:',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              '${item.quantity ?? 0}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Rate:',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              '₹${item.rate?.toStringAsFixed(2) ?? "0.00"}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (item.discountPercentage != null &&
                            item.discountPercentage! > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Discount:',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                '${item.discountPercentage!.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _orange,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 6),
                        Divider(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Item Total:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              '₹${itemTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Serials:',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: hasAllImeis
                                    ? _lightGreen.withOpacity(0.1)
                                    : _amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$currentImeiCount/$requiredImeiCount',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: hasAllImeis ? _lightGreen : _amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Edit Section (Only shown when toggled)
                if (showEditSection && item.productId != null) ...[
                  const SizedBox(height: 12),

                  // Basic Info Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 3,
                    children: [
                      // Quantity
                      _buildInputField(
                        label: 'Quantity *',
                        value: item.quantity?.toString(),
                        onChanged: (value) {
                          final qty = double.tryParse(value);
                          setState(() {
                            _purchaseItems[index].quantity = qty;
                            final requiredCount = qty?.toInt() ?? 1;
                            _itemImeis[index] ??= [];

                            if (_itemImeis[index]!.length < requiredCount) {
                              _itemImeis[index]!.addAll(
                                List.filled(
                                  requiredCount - _itemImeis[index]!.length,
                                  '',
                                ),
                              );
                            } else if (_itemImeis[index]!.length >
                                requiredCount) {
                              _itemImeis[index] = _itemImeis[index]!.sublist(
                                0,
                                requiredCount,
                              );
                            }
                          });
                          _calculateTotals();
                        },
                        keyboardType: TextInputType.number,
                      ),

                      // Rate
                      _buildInputField(
                        label: 'Rate *',
                        value: item.rate?.toStringAsFixed(2),
                        onChanged: (value) {
                          final rate = double.tryParse(value);
                          setState(() {
                            _purchaseItems[index].rate = rate;
                            if (rate != null) {
                              _purchaseItems[index].gstAmount = rate * 0.18;
                            }
                          });
                          _calculateTotals();
                        },
                        keyboardType: TextInputType.number,
                        prefix: '₹',
                      ),

                      // Discount
                      _buildInputField(
                        label: 'Discount %',
                        value: item.discountPercentage?.toStringAsFixed(1),
                        onChanged: (value) {
                          final discount = double.tryParse(value);
                          setState(() {
                            _purchaseItems[index].discountPercentage =
                                discount ?? 0.0;
                          });
                          _calculateTotals();
                        },
                        keyboardType: TextInputType.number,
                        suffix: '%',
                      ),

                      // HSN Code
                      _buildInputField(
                        label: 'HSN Code',
                        value: item.hsnCode,
                        onChanged: (value) {
                          setState(() {
                            _purchaseItems[index].hsnCode = value;
                          });
                        },
                      ),
                    ],
                  ),

                  // Serial Number Section
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.pink.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.pink.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.smartphone, color: _pink, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Serial/IMEI Numbers *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _pink,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: hasAllImeis ? _lightGreen : _amber,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$currentImeiCount/$requiredImeiCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Required: $requiredImeiCount Serial${requiredImeiCount > 1 ? 's' : ''} (1 per unit)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Serial List
                        if (itemImeis.isNotEmpty)
                          ...List.generate(itemImeis.length, (imeiIndex) {
                            final imei = itemImeis[imeiIndex];
                            final isValid =
                                imei.isNotEmpty && _isValidSerialNumber(imei);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: isValid
                                          ? _lightGreen.withOpacity(0.1)
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${imeiIndex + 1}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: isValid
                                              ? _lightGreen
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _showManualSerialEntry(
                                        index,
                                        imeiIndex: imeiIndex,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isValid
                                              ? _lightGreen.withOpacity(0.05)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: isValid
                                                ? _lightGreen
                                                : Colors.grey.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                imei.isEmpty
                                                    ? 'Tap to enter Serial'
                                                    : imei,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: imei.isEmpty
                                                      ? Colors.grey.shade500
                                                      : Colors.grey.shade800,
                                                  fontWeight: isValid
                                                      ? FontWeight.w500
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              isValid
                                                  ? Icons.check_circle
                                                  : Icons.edit,
                                              size: 14,
                                              color: isValid
                                                  ? _lightGreen
                                                  : _primaryGreen,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    onPressed: () => _showScannerDialog(
                                      index,
                                      imeiIndex: imeiIndex,
                                    ),
                                    icon: Icon(
                                      Icons.qr_code_scanner,
                                      size: 16,
                                      color: _primaryGreen,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          }),

                        // Add Serial Button
                        if (currentImeiCount < requiredImeiCount)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showScannerDialog(index),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _pink.withOpacity(0.1),
                                  foregroundColor: _pink,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                ),
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text(
                                  'Add Serial/IMEI',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ),

                        // Serial Status Message
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            hasAllImeis &&
                                    itemImeis.every(
                                      (imei) => _isValidSerialNumber(imei),
                                    )
                                ? '✅ All Serial Numbers are valid'
                                : '⚠️ ${requiredImeiCount - currentImeiCount} Serial${requiredImeiCount - currentImeiCount > 1 ? 's' : ''} remaining',
                            style: TextStyle(
                              fontSize: 9,
                              color: hasAllImeis ? _lightGreen : _amber,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Item Total Details
                  if (item.rate != null && item.quantity != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _indigo.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _indigo.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Item Total:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  '₹${(item.quantity! * item.rate!).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (item.discountPercentage != null &&
                                item.discountPercentage! > 0)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Discount:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    '-₹${((item.quantity! * item.rate!) * (item.discountPercentage! / 100)).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _orange,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'GST (18%):',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  '₹${itemGst.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _indigo,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Divider(height: 1, color: Colors.grey.shade300),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total with GST:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                Text(
                                  '₹${(itemTotal + itemGst).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    String? value,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade700)),
        const SizedBox(height: 2),
        TextFormField(
          initialValue: value,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 11),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(fontSize: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            prefixText: prefix,
            suffixText: suffix,
            prefixStyle: const TextStyle(fontSize: 11),
            suffixStyle: const TextStyle(fontSize: 11),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isTotal ? _primaryGreen : Colors.grey.shade700,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: isTotal ? _primaryGreen : Colors.grey.shade800,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _primaryGreen,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _lightGreen, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            suffixIcon: suffixIcon,
          ),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _showSupplierSelection() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryGreen,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Supplier',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Supplier List
            Expanded(
              child: _suppliers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.business,
                            size: 50,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No suppliers found',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add suppliers in the suppliers section',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _suppliers.length,
                      itemBuilder: (context, index) {
                        final supplier = _suppliers[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: _lightGreen.withOpacity(0.1),
                            radius: 16,
                            child: Icon(
                              Icons.business,
                              color: _lightGreen,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            supplier['name'] ?? 'Unnamed',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          subtitle: supplier['phone'] != null
                              ? Text(
                                  supplier['phone']!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                )
                              : null,
                          trailing: _selectedSupplier?['id'] == supplier['id']
                              ? Icon(
                                  Icons.check_circle,
                                  color: _lightGreen,
                                  size: 18,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedSupplier = supplier;
                              _supplierController.text = supplier['name'] ?? '';
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),

            // Cancel Button
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePreview() {
    setState(() {
      _showPreview = !_showPreview;
    });
  }

  Widget _buildPreviewDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primaryGreen,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.remove_red_eye,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Purchase Preview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => _togglePreview(),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic Info
                  _buildPreviewSection(
                    icon: Icons.calendar_today,
                    title: 'Purchase Date',
                    content:
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  ),
                  _buildPreviewSection(
                    icon: Icons.business,
                    title: 'Supplier',
                    content: _selectedSupplier?['name'] ?? 'Not selected',
                  ),
                  _buildPreviewSection(
                    icon: Icons.receipt,
                    title: 'Invoice Number',
                    content: _invoiceController.text.isNotEmpty
                        ? _invoiceController.text
                        : 'Not entered',
                  ),

                  const Divider(height: 20),

                  // Items
                  Text(
                    'Items (${_purchaseItems.where((item) => item.productId != null).length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ..._purchaseItems.where((item) => item.productId != null).map((
                    item,
                  ) {
                    final index = _purchaseItems.indexOf(item);
                    final itemImeis = _itemImeis[index] ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          if (item.brand != null)
                            Text(
                              item.brand!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${item.quantity} × ₹${item.rate?.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                '₹${(item.quantity! * item.rate!).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryGreen,
                                ),
                              ),
                            ],
                          ),
                          if (itemImeis.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Serials:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  ...itemImeis.take(3).map((imei) {
                                    return Text(
                                      '• ${imei.substring(0, math.min(imei.length, 8))}...',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey.shade500,
                                      ),
                                    );
                                  }),
                                  if (itemImeis.length > 3)
                                    Text(
                                      '+ ${itemImeis.length - 3} more',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),

                  const Divider(height: 20),

                  // Summary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _lightGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _buildPreviewSummaryRow(
                          'Subtotal:',
                          '₹${_subtotal.toStringAsFixed(2)}',
                        ),
                        if (_totalDiscount > 0)
                          _buildPreviewSummaryRow(
                            'Discount:',
                            '-₹${_totalDiscount.toStringAsFixed(2)}',
                          ),
                        _buildPreviewSummaryRow(
                          'GST (18%):',
                          '₹${_gstAmount.toStringAsFixed(2)}',
                        ),
                        if (_roundOff != 0)
                          _buildPreviewSummaryRow(
                            'Round Off:',
                            _roundOff > 0
                                ? '+₹${_roundOff.abs().toStringAsFixed(2)}'
                                : '-₹${_roundOff.abs().toStringAsFixed(2)}',
                          ),
                        const Divider(height: 10),
                        _buildPreviewSummaryRow(
                          'Total Amount:',
                          '₹${_totalAmount.toStringAsFixed(2)}',
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _togglePreview,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Continue Editing',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _confirmAndSavePurchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _lightGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Confirm & Save',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
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

  Widget _buildPreviewSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _primaryGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isTotal ? _primaryGreen : Colors.grey.shade700,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isTotal ? _primaryGreen : Colors.grey.shade800,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'New Purchase',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            tooltip: 'Change Date',
            onPressed: _selectDate,
          ),
          IconButton(
            icon: Icon(
              _showPreview ? Icons.edit : Icons.remove_red_eye,
              size: 20,
            ),
            tooltip: _showPreview ? 'Edit Purchase' : 'Preview Purchase',
            onPressed: _togglePreview,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Date Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Purchase Date',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _selectDate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _lightGreen.withOpacity(0.1),
                            foregroundColor: _primaryGreen,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: const Text(
                            'Change',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Supplier Selection
                  GestureDetector(
                    onTap: _showSupplierSelection,
                    child: AbsorbPointer(
                      absorbing: true,
                      child: _buildFormField(
                        label: 'Supplier *',
                        controller: _supplierController,
                        readOnly: true,
                        suffixIcon: Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: _primaryGreen,
                        ),
                        validator: (value) {
                          if (_selectedSupplier == null) {
                            return 'Please select a supplier';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Invoice Number
                  _buildFormField(
                    label: 'Invoice Number *',
                    controller: _invoiceController,
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter invoice number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Items Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Purchase Items',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primaryGreen,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addNewItem,
                        style: TextButton.styleFrom(
                          foregroundColor: _lightGreen,
                        ),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text(
                          'Add Item',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Purchase Items List
                  ..._purchaseItems.asMap().entries.map((entry) {
                    return _buildPurchaseItemCard(entry.key);
                  }),

                  // Add Item Button
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addNewItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _lightGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Add New Item',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),

                  // Summary Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Order Summary',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow(
                          'Subtotal:',
                          '₹${_subtotal.toStringAsFixed(2)}',
                        ),
                        if (_totalDiscount > 0)
                          _buildSummaryRow(
                            'Total Discount:',
                            '-₹${_totalDiscount.toStringAsFixed(2)}',
                          ),
                        _buildSummaryRow(
                          'GST (18%):',
                          '₹${_gstAmount.toStringAsFixed(2)}',
                        ),
                        if (_roundOff != 0)
                          _buildSummaryRow(
                            'Round Off:',
                            _roundOff > 0
                                ? '+₹${_roundOff.abs().toStringAsFixed(2)}'
                                : '-₹${_roundOff.abs().toStringAsFixed(2)}',
                          ),
                        const Divider(height: 12),
                        _buildSummaryRow(
                          'Total Amount:',
                          '₹${_totalAmount.toStringAsFixed(2)}',
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  _buildFormField(
                    label: 'Notes',
                    controller: _notesController,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _togglePreview,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Preview',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _savePurchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _lightGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save Purchase',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Preview Overlay
          if (_showPreview)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: _buildPreviewDialog(),
            ),
        ],
      ),
    );
  }

  Future<void> _savePurchase() async {
    // Instead of directly saving, show preview first
    _togglePreview();
  }

  Future<void> _confirmAndSavePurchase() async {
    if (_formKey.currentState!.validate() &&
        _selectedSupplier != null &&
        _purchaseItems.isNotEmpty) {
      // Validate all items
      for (var i = 0; i < _purchaseItems.length; i++) {
        final item = _purchaseItems[i];

        // Basic validation
        if (item.productId == null ||
            item.quantity == null ||
            item.rate == null) {
          _showErrorSnackbar(
            'Please fill all required fields for item ${i + 1}',
          );
          return;
        }

        // Serial validation
        final requiredImeiCount = item.quantity!.toInt();
        final itemImeis = _itemImeis[i] ?? [];
        if (itemImeis.length < requiredImeiCount) {
          _showErrorSnackbar(
            'Item ${i + 1}: Need $requiredImeiCount Serial Numbers, got ${itemImeis.length}',
          );
          return;
        }

        // Validate each serial number
        for (var j = 0; j < requiredImeiCount; j++) {
          final serial = itemImeis[j];
          if (serial.isEmpty || !_isValidSerialNumber(serial)) {
            _showErrorSnackbar(
              'Item ${i + 1}, Serial ${j + 1}: Invalid serial number',
            );
            return;
          }
        }
      }

      try {
        final purchaseData = {
          'supplierId': _selectedSupplier!['id'],
          'supplierName': _selectedSupplier!['name'],
          'invoiceNumber': _invoiceController.text.trim(),
          'purchaseDate': _selectedDate,
          'subtotal': _subtotal,
          'gstAmount': _gstAmount,
          'totalDiscount': _totalDiscount,
          'roundOff': _roundOff,
          'totalAmount': _totalAmount,
          'notes': _notesController.text.trim(),
          'items': _purchaseItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final itemMap = item.toMap();
            itemMap['imeis'] = _itemImeis[index] ?? [];
            return itemMap;
          }).toList(),
        };

        await _firestoreService.createPurchase(purchaseData);

        // Update product information
        for (var i = 0; i < _purchaseItems.length; i++) {
          final item = _purchaseItems[i];
          if (item.productId != null) {
            if (item.rate != null) {
              await _firestoreService.updateProductPurchaseRate(
                item.productId!,
                item.rate!,
              );
            }
            if (item.hsnCode != null && item.hsnCode!.isNotEmpty) {
              await _firestoreService.updateProductHsnCode(
                item.productId!,
                item.hsnCode!,
              );
            }
            // Update stock
            await _firestoreService.updateProductStock(
              item.productId!,
              item.quantity!.toInt(),
            );
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Purchase saved successfully',
              style: TextStyle(fontSize: 12),
            ),
            backgroundColor: _lightGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );

        // Close preview and go back
        _togglePreview();
        Navigator.pop(context, true);
      } catch (e) {
        _showErrorSnackbar('Error saving purchase: $e');
      }
    } else {
      _showErrorSnackbar('Please fill all required fields');
    }
  }
}
