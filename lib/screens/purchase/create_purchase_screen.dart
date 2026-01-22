import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sales_stock/models/purchase_item.dart';
import 'package:sales_stock/services/firestore_service.dart';

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
  Map<int, bool> _showEditSections = {};

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
    _purchaseItems.add(PurchaseItem());
    _showEditSections[0] = true; // Show edit section for first item
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

      // Split search query into individual words
      final searchWords = searchQuery.split(' ');

      _filteredProducts = _products.where((product) {
        // Combine all searchable fields
        final productName = (product['productName'] ?? '')
            .toString()
            .toLowerCase();
        final brand = (product['brand'] ?? '').toString().toLowerCase();
        final model = (product['model'] ?? '').toString().toLowerCase();
        final color = (product['color'] ?? '').toString().toLowerCase();
        final ram = (product['ram'] ?? '').toString().toLowerCase();
        final storage = (product['storage'] ?? '').toString().toLowerCase();
        final variant = (product['variant'] ?? '').toString().toLowerCase();

        // Create a combined search string
        final combinedText =
            '$productName $brand $model $color $ram $storage $variant';

        // Check if ALL search words are found in the combined text
        return searchWords.every((word) {
          if (word.isEmpty) return true;

          // Check for special patterns
          if (word.contains('/')) {
            // For patterns like "4/128" or "6/256"
            return combinedText.contains(word);
          }

          // Check for model numbers with different separators
          if (RegExp(r'^[a-zA-Z][0-9]+$').hasMatch(word)) {
            // For patterns like "f17" or "a54"
            final pattern = word.toLowerCase();
            return productName.contains(pattern) ||
                model.toLowerCase().contains(pattern) ||
                combinedText.contains(pattern);
          }

          // Check for numbers (like storage or RAM)
          if (RegExp(r'^\d+$').hasMatch(word)) {
            final number = word;
            // Check if number appears in storage or RAM
            if (storage.contains(number) || ram.contains(number)) {
              return true;
            }
            // Also check in combined text
            return combinedText.contains(number);
          }

          // Regular word search
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

        // Apply discount if exists
        if (item.discountPercentage != null && item.discountPercentage! > 0) {
          double discountAmount = itemTotal * (item.discountPercentage! / 100);
          itemTotal -= discountAmount;
          _totalDiscount += discountAmount;
        }

        _subtotal += itemTotal;

        // Calculate 18% GST for each item
        item.gstAmount = itemTotal * 0.18;
        _gstAmount += item.gstAmount!;
      }
    }

    _totalAmount = _subtotal + _gstAmount;

    // Calculate round off (round to nearest integer)
    _roundOff = _totalAmount.roundToDouble() - _totalAmount;
    _totalAmount = _totalAmount.roundToDouble();

    setState(() {});
  }

  void _addNewItem() {
    setState(() {
      _purchaseItems.add(PurchaseItem());
      _showEditSections[_purchaseItems.length - 1] = true;
    });
  }

  void _removeItem(int index) {
    if (_purchaseItems.length > 1) {
      setState(() {
        _purchaseItems.removeAt(index);
        _showEditSections.remove(index);
        // Reindex the showEditSections map
        final newShowEditSections = <int, bool>{};
        for (int i = 0; i < _purchaseItems.length; i++) {
          newShowEditSections[i] = _showEditSections[i] ?? true;
        }
        _showEditSections = newShowEditSections;
        _calculateTotals();
      });
    }
  }

  void _toggleEditSection(int index) {
    setState(() {
      _showEditSections[index] = !(_showEditSections[index] ?? false);
    });
  }

  Future<void> _showScannerDialog(int itemIndex) async {
    _currentScanItemIndex = itemIndex;
    _scannerController = MobileScannerController();

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
                  'Scan IMEI/Serial Number *',
                  style: TextStyle(color: _pink),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    _scannerController?.dispose();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            content: Container(
              height: 300,
              width: 300,
              child: MobileScanner(
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
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showManualIMEIEntry(itemIndex);
                },
                child: Text('Enter Manually'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onScanComplete(String scannedValue) {
    if (_currentScanItemIndex != null) {
      // Validate IMEI is 15 digits
      if (scannedValue.length != 15 ||
          !RegExp(r'^\d+$').hasMatch(scannedValue)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid IMEI. Must be 15 digits. Scanned: $scannedValue',
            ),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        _purchaseItems[_currentScanItemIndex!].imei = scannedValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('IMEI scanned successfully ✓'),
          backgroundColor: _lightGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _currentScanItemIndex = null;
  }

  Future<void> _showManualIMEIEntry(int itemIndex) async {
    final imeiController = TextEditingController(
      text: _purchaseItems[itemIndex].imei ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter IMEI Number *', style: TextStyle(color: _pink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'IMEI is required for inventory tracking',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: imeiController,
              keyboardType: TextInputType.number,
              maxLength: 15,
              decoration: InputDecoration(
                hintText: 'Enter 15-digit IMEI number...',
                border: OutlineInputBorder(),
                counterText: '',
                prefixIcon: Icon(Icons.smartphone, color: _primaryGreen),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () => imeiController.clear(),
                ),
              ),
              autofocus: true,
              onChanged: (value) {
                if (value.length == 15 && RegExp(r'^\d+$').hasMatch(value)) {
                  // Auto-save if valid
                  setState(() {
                    _purchaseItems[itemIndex].imei = value;
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: _primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'IMEI is usually found under battery or in phone settings',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final imei = imeiController.text.trim();
              if (imei.length == 15 && RegExp(r'^\d+$').hasMatch(imei)) {
                Navigator.pop(context);
                setState(() {
                  _purchaseItems[itemIndex].imei = imei;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('IMEI saved: ${imei.substring(0, 4)}...'),
                    backgroundColor: _lightGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'IMEI must be exactly 15 digits (${imei.length}/15)',
                    ),
                    backgroundColor: _red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _pink),
            child: Text('Save IMEI', style: TextStyle(color: Colors.white)),
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Product',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _primaryGreen,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey.shade600),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _productSearchController,
                      decoration: InputDecoration(
                        hintText:
                            'Search by product name, brand, model, color, RAM, storage...',
                        prefixIcon: Icon(Icons.search, color: _primaryGreen),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: _productSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey),
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
                  const SizedBox(height: 12),

                  if (_filteredProducts.isEmpty &&
                      _productSearchController.text.isNotEmpty)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_android_outlined,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Product not found',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add "${_productSearchController.text}" as new product',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: 200,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _showAddProductDialog(
                                  preFilledSearch:
                                      _productSearchController.text,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add New Product'),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_filteredProducts.isEmpty &&
                      _productSearchController.text.isEmpty)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_android,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No products available',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add your first product to continue',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: 200,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _showAddProductDialog();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _lightGreen,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add New Product'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_filteredProducts.isNotEmpty)
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Found: ${_filteredProducts.length} product${_filteredProducts.length != 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _showAddProductDialog(
                                      preFilledSearch:
                                          _productSearchController.text,
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: _blue,
                                  ),
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Add New'),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                final hasPurchaseRate =
                                    product['purchaseRate'] != null &&
                                    (product['purchaseRate'] is num) &&
                                    product['purchaseRate'] > 0;
                                final productName =
                                    product['productName'] ??
                                    '${product['brand'] ?? ''} ${product['model'] ?? ''}'
                                        .trim();
                                final brand = product['brand'] ?? '';
                                final model = product['model'] ?? '';
                                final color = product['color'] ?? '';
                                final ram = product['ram'] ?? '';
                                final storage = product['storage'] ?? '';
                                final hsnCode = product['hsnCode'] ?? '';
                                final purchaseRate =
                                    product['purchaseRate'] ?? 0.0;

                                return Column(
                                  children: [
                                    ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: hasPurchaseRate
                                              ? _lightGreen.withOpacity(0.1)
                                              : _amber.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.phone_android,
                                          size: 18,
                                          color: hasPurchaseRate
                                              ? _lightGreen
                                              : _amber,
                                        ),
                                      ),
                                      title: Text(
                                        productName.isNotEmpty
                                            ? productName
                                            : 'Unnamed Product',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (brand.isNotEmpty)
                                            Text(
                                              'Brand: $brand',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          if (model.isNotEmpty)
                                            Text(
                                              'Model: $model',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          if (ram.isNotEmpty ||
                                              storage.isNotEmpty)
                                            Text(
                                              '${ram.isNotEmpty ? '$ram RAM' : ''}${ram.isNotEmpty && storage.isNotEmpty ? ', ' : ''}${storage.isNotEmpty ? '$storage Storage' : ''}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          if (color.isNotEmpty)
                                            Text(
                                              'Color: $color',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          const SizedBox(height: 2),
                                          if (hasPurchaseRate)
                                            Row(
                                              children: [
                                                Text(
                                                  'Purchase Rate: ',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${(purchaseRate as num).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: _primaryGreen,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _indigo.withOpacity(
                                                      0.1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'GST: \$${(purchaseRate * 0.18).toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: _indigo,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            Container(
                                              margin: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _amber.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.warning,
                                                    size: 10,
                                                    color: _amber,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'No purchase rate set',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: _amber,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (hsnCode.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    'HSN: ',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  Text(
                                                    hsnCode,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: _pink,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14,
                                      ),
                                      onTap: () async {
                                        if (!hasPurchaseRate) {
                                          // Show dialog to set purchase rate
                                          final newRate =
                                              await _showSetPurchaseRateDialog(
                                                productName,
                                              );
                                          if (newRate != null) {
                                            // Update product with new rate
                                            await _firestoreService
                                                .updateProductPurchaseRate(
                                                  product['id'] ?? '',
                                                  newRate,
                                                );
                                            // Update local product data
                                            product['purchaseRate'] = newRate;
                                            // Refresh products list
                                            await _fetchProducts();
                                            // Return the updated product
                                            Navigator.pop(context, product);
                                          }
                                        } else {
                                          Navigator.pop(context, product);
                                        }
                                      },
                                    ),
                                    // Add Item button after each product
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        bottom: 8,
                                      ),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            if (!hasPurchaseRate) {
                                              // Show dialog to set purchase rate
                                              final newRate =
                                                  await _showSetPurchaseRateDialog(
                                                    productName,
                                                  );
                                              if (newRate != null) {
                                                // Update product with new rate
                                                await _firestoreService
                                                    .updateProductPurchaseRate(
                                                      product['id'] ?? '',
                                                      newRate,
                                                    );
                                                // Update local product data
                                                product['purchaseRate'] =
                                                    newRate;
                                                // Refresh products list
                                                await _fetchProducts();
                                                // Return the updated product
                                                Navigator.pop(context, product);
                                              }
                                            } else {
                                              Navigator.pop(context, product);
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _lightGreen,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                          icon: const Icon(Icons.add, size: 14),
                                          label: const Text(
                                            'Add Item',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (index < _filteredProducts.length - 1)
                                      Divider(
                                        height: 1,
                                        color: Colors.grey.shade200,
                                      ),
                                  ],
                                );
                              },
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

    if (selectedProduct != null) {
      // Show a reminder about IMEI
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Don\'t forget to scan/enter IMEI for ${selectedProduct['productName'] ?? 'this product'}',
            ),
            backgroundColor: _amber,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      });

      // Update the purchase item with selected product
      setState(() {
        _purchaseItems[itemIndex].productId = selectedProduct['id'] ?? '';
        _purchaseItems[itemIndex].productName =
            selectedProduct['productName'] ??
            '${selectedProduct['brand'] ?? ''} ${selectedProduct['model'] ?? ''}'
                .trim();
        _purchaseItems[itemIndex].brand = selectedProduct['brand'];
        _purchaseItems[itemIndex].model = selectedProduct['model'];
        _purchaseItems[itemIndex].color = selectedProduct['color'];
        _purchaseItems[itemIndex].ram = selectedProduct['ram'];
        _purchaseItems[itemIndex].storage = selectedProduct['storage'];
        _purchaseItems[itemIndex].hsnCode = selectedProduct['hsnCode'] ?? '';

        // Use purchaseRate if available - auto-fill purchase rate
        final purchaseRate = selectedProduct['purchaseRate'];
        if (purchaseRate != null && purchaseRate is num && purchaseRate > 0) {
          _purchaseItems[itemIndex].rate = purchaseRate.toDouble();
          // Calculate 18% GST for this item
          _purchaseItems[itemIndex].gstAmount = purchaseRate.toDouble() * 0.18;
        }

        // Show edit section when product is selected
        _showEditSections[itemIndex] = true;
        _calculateTotals();
      });
    }
  }

  Future<double?> _showSetPurchaseRateDialog(String productName) async {
    final rateController = TextEditingController();

    return await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Set Purchase Rate',
          style: TextStyle(color: _primaryGreen),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              'This product doesn\'t have a purchase rate set. Please enter the purchase rate (cost price):',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: rateController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Purchase Rate (Cost Price)',
                hintText: 'Enter purchase rate...',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            if (rateController.text.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price Breakdown:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cost: \$${double.tryParse(rateController.text)?.toStringAsFixed(2) ?? "0.00"}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    'GST (18%): \$${(double.tryParse(rateController.text) ?? 0) * 0.18}',
                    style: TextStyle(fontSize: 11, color: _indigo),
                  ),
                  Text(
                    'Total: \$${(double.tryParse(rateController.text) ?? 0) * 1.18}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final rate = double.tryParse(rateController.text);
              if (rate != null && rate > 0) {
                Navigator.pop(context, rate);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a valid purchase rate'),
                    backgroundColor: _red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _lightGreen),
            child: const Text(
              'Set Purchase Rate',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddProductDialog({String preFilledSearch = ''}) async {
    final brandController = TextEditingController();
    final productNameController = TextEditingController();
    final modelController = TextEditingController();
    final ramController = TextEditingController();
    final storageController = TextEditingController();
    final colorController = TextEditingController();
    final purchaseRateController = TextEditingController();
    final hsnController = TextEditingController();

    // Auto-fill from search if available
    if (preFilledSearch.isNotEmpty) {
      productNameController.text = preFilledSearch;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Product', style: TextStyle(color: _primaryGreen)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProductTextField('Brand *', brandController),
              const SizedBox(height: 12),
              _buildProductTextField('Product Name *', productNameController),
              const SizedBox(height: 12),
              _buildProductTextField('Model', modelController),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildProductTextField(
                      'RAM (e.g., 4GB)',
                      ramController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildProductTextField(
                      'Storage (e.g., 128GB)',
                      storageController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildProductTextField('Color', colorController),
              const SizedBox(height: 12),
              _buildProductTextField(
                'Purchase Rate (Cost Price) *',
                purchaseRateController,
                keyboardType: TextInputType.number,
                prefixIcon: Text('\$ ', style: TextStyle(color: _primaryGreen)),
              ),
              const SizedBox(height: 12),
              // HSN Code Text Field
              _buildProductTextField(
                'HSN Code',
                hsnController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Purchase rate will be updated automatically when you save this purchase',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (brandController.text.isNotEmpty &&
                  productNameController.text.isNotEmpty &&
                  purchaseRateController.text.isNotEmpty) {
                try {
                  final productData = {
                    'brand': brandController.text.trim(),
                    'productName': productNameController.text.trim(),
                    'model': modelController.text.trim().isNotEmpty
                        ? modelController.text.trim()
                        : null,
                    'ram': ramController.text.trim().isNotEmpty
                        ? ramController.text.trim()
                        : null,
                    'storage': storageController.text.trim().isNotEmpty
                        ? storageController.text.trim()
                        : null,
                    'color': colorController.text.trim().isNotEmpty
                        ? colorController.text.trim()
                        : null,
                    'purchaseRate':
                        double.tryParse(purchaseRateController.text.trim()) ??
                        0.0,
                    'hsnCode': hsnController.text.trim().isNotEmpty
                        ? hsnController.text.trim()
                        : null,
                    'stockQuantity': 0,
                  };

                  await _firestoreService.addProduct(productData);
                  await _fetchProducts();

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Product added successfully'),
                      backgroundColor: _lightGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding product: $e'),
                      backgroundColor: _red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please fill all required fields'),
                    backgroundColor: _red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _lightGreen),
            child: const Text(
              'Add Product',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    Widget? prefixIcon,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: _primaryGreen)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText ?? label,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            prefixIcon: prefixIcon,
          ),
        ),
      ],
    );
  }

  Future<void> _savePurchase() async {
    if (_formKey.currentState!.validate() &&
        _selectedSupplier != null &&
        _purchaseItems.isNotEmpty) {
      // Validate all items have required data including IMEI
      for (var i = 0; i < _purchaseItems.length; i++) {
        final item = _purchaseItems[i];

        // Check basic required fields
        if (item.productId == null ||
            item.quantity == null ||
            item.rate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please fill all required fields for item ${i + 1}',
              ),
              backgroundColor: _red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          return;
        }

        // IMEI IS NOW REQUIRED - Check if IMEI exists
        if (item.imei == null || item.imei!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Item ${i + 1}: IMEI is required. Please scan or enter IMEI.',
              ),
              backgroundColor: _red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // Validate IMEI format (15 digits)
        if (item.imei!.length != 15 || !RegExp(r'^\d+$').hasMatch(item.imei!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Item ${i + 1}: IMEI must be exactly 15 digits. Current: ${item.imei!.length} digits',
              ),
              backgroundColor: _red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      try {
        // Prepare purchase data
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
          'items': _purchaseItems.map((item) => item.toMap()).toList(),
        };

        // Save purchase to Firestore
        await _firestoreService.createPurchase(purchaseData);

        // Update purchase rate and HSN code in products collection
        for (var item in _purchaseItems) {
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
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Purchase saved successfully'),
            backgroundColor: _lightGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        Navigator.pop(context, true); // Return success
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving purchase: $e'),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all required fields'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'New Purchase',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Change Date',
            onPressed: _selectDate,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Date Display and Change Button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _lightGreen.withOpacity(0.3)),
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
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: TextStyle(
                            fontSize: 14,
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: const Text('Change'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Supplier Selection - Make entire field clickable
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
                      size: 20,
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
              const SizedBox(height: 12),

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

              // Items Section Header
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
                    style: TextButton.styleFrom(foregroundColor: _lightGreen),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Item'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Purchase Items List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _purchaseItems.length,
                itemBuilder: (context, index) {
                  return _buildPurchaseItemCard(index);
                },
              ),
              const SizedBox(height: 20),

              // ADD ITEM BUTTON before subtotal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addNewItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _lightGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Add New Item',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Summary Section with Round Off
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Subtotal:',
                      '\$${_subtotal.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    if (_totalDiscount > 0)
                      Column(
                        children: [
                          _buildSummaryRow(
                            'Total Discount:',
                            '-\$${_totalDiscount.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    _buildSummaryRow(
                      'GST (18%):',
                      '\$${_gstAmount.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    if (_roundOff != 0)
                      Column(
                        children: [
                          _buildSummaryRow(
                            'Round Off:',
                            _roundOff > 0
                                ? '+\$${_roundOff.abs().toStringAsFixed(2)}'
                                : '-\$${_roundOff.abs().toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Total Amount:',
                      '\$${_totalAmount.toStringAsFixed(2)}',
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
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savePurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _lightGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Save Purchase',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseItemCard(int index) {
    final item = _purchaseItems[index];
    final showEditSection = _showEditSections[index] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Item ${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.productId != null &&
                        (item.imei == null || item.imei!.isEmpty))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning, size: 10, color: _amber),
                            const SizedBox(width: 4),
                            Text(
                              'IMEI Required',
                              style: TextStyle(
                                fontSize: 9,
                                color: _amber,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (item.productId != null)
                    IconButton(
                      onPressed: () => _toggleEditSection(index),
                      icon: Icon(
                        showEditSection ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: _primaryGreen,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: showEditSection
                          ? 'Hide Details'
                          : 'Show Details',
                    ),
                  if (_purchaseItems.length > 1)
                    IconButton(
                      onPressed: () => _removeItem(index),
                      icon: Icon(Icons.delete, size: 18, color: _red),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Product Selection
          GestureDetector(
            onTap: () => _showProductSelection(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.productId != null
                      ? _lightGreen
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.phone_android,
                    size: 16,
                    color: item.productId != null
                        ? _lightGreen
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName ?? 'Select Product *',
                          style: TextStyle(
                            fontSize: 12,
                            color: item.productId != null
                                ? Colors.grey.shade800
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.productId != null && item.brand != null)
                          Text(
                            'Brand: ${item.brand}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, size: 18, color: _primaryGreen),
                ],
              ),
            ),
          ),

          // Product Details Section - AFTER product selection
          if (item.productName != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _lightGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _lightGreen.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: _lightGreen),
                      const SizedBox(width: 8),
                      Text(
                        'Product Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _primaryGreen,
                        ),
                      ),
                      const Spacer(),
                      if (item.gstAmount != null && item.gstAmount! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _indigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'GST: \$${item.gstAmount!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: _indigo,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Product Name
                  Text(
                    item.productName ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Additional details in row
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (item.brand != null && item.brand!.isNotEmpty)
                        _buildDetailChip('Brand: ${item.brand}', _lightGreen),
                      if (item.model != null && item.model!.isNotEmpty)
                        _buildDetailChip('Model: ${item.model}', _blue),
                      if (item.ram != null && item.ram!.isNotEmpty)
                        _buildDetailChip('RAM: ${item.ram}', _purple),
                      if (item.storage != null && item.storage!.isNotEmpty)
                        _buildDetailChip('Storage: ${item.storage}', _teal),
                      if (item.color != null && item.color!.isNotEmpty)
                        _buildDetailChip('Color: ${item.color}', _orange),
                      if (item.rate != null)
                        _buildDetailChip(
                          'Rate: \$${item.rate!.toStringAsFixed(2)}',
                          _primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      if (item.hsnCode != null && item.hsnCode!.isNotEmpty)
                        _buildDetailChip('HSN: ${item.hsnCode}', _pink),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Edit Section (Collapsible)
          if (item.productId != null && showEditSection) ...[
            const SizedBox(height: 12),

            // IMEI Scanner Button - Required
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'IMEI Number *',
                        style: TextStyle(
                          fontSize: 11,
                          color: _pink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(15 digits)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showScannerDialog(index),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: item.imei != null
                                ? _lightGreen.withOpacity(0.1)
                                : _pink.withOpacity(0.1),
                            foregroundColor: item.imei != null
                                ? _lightGreen
                                : _pink,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.qr_code_scanner, size: 16),
                          label: Text(
                            item.imei != null
                                ? 'IMEI: ${item.imei} ✓'
                                : 'Click to Scan IMEI *',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: item.imei != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _showManualIMEIEntry(index),
                        icon: Icon(
                          Icons.keyboard,
                          size: 16,
                          color: _primaryGreen,
                        ),
                        tooltip: 'Enter IMEI manually',
                      ),
                    ],
                  ),
                  // Show error message if IMEI is not entered when trying to save
                  if (item.imei == null || item.imei!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'IMEI is required for each item',
                        style: TextStyle(fontSize: 10, color: _red),
                      ),
                    ),
                ],
              ),
            ),

            // HSN Code Text Field
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HSN Code',
                    style: TextStyle(fontSize: 11, color: _pink),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: item.hsnCode,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Enter HSN Code',
                      hintStyle: TextStyle(fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _purchaseItems[index].hsnCode = value.trim();
                      });
                    },
                  ),
                ],
              ),
            ),

            // Quantity, Rate, and Discount Row
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quantity *',
                            style: TextStyle(
                              fontSize: 11,
                              color: _primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            initialValue: item.quantity?.toString(),
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Enter quantity',
                              hintStyle: TextStyle(fontSize: 11),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              final qty = double.tryParse(value);
                              setState(() {
                                _purchaseItems[index].quantity = qty;
                              });
                              _calculateTotals();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchase Rate *',
                            style: TextStyle(
                              fontSize: 11,
                              color: _primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: TextEditingController(
                              text: item.rate?.toStringAsFixed(2) ?? '',
                            ),
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Enter purchase rate',
                              hintStyle: TextStyle(fontSize: 11),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              prefixText: '\$ ',
                            ),
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
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Discount %',
                            style: TextStyle(fontSize: 11, color: _orange),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            initialValue: item.discountPercentage
                                ?.toStringAsFixed(1),
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Discount percentage',
                              hintStyle: TextStyle(fontSize: 11),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              suffixText: '%',
                              suffixStyle: TextStyle(color: _orange),
                            ),
                            onChanged: (value) {
                              final discount = double.tryParse(value);
                              setState(() {
                                _purchaseItems[index].discountPercentage =
                                    discount;
                              });
                              _calculateTotals();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Show GST calculation for this item
                if (item.rate != null && item.quantity != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _indigo.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _indigo.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Item GST (18%):',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '\$${((item.rate! * item.quantity!) * 0.18).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: _indigo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailChip(
    String text,
    Color color, {
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: fontWeight),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
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
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _primaryGreen,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
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
              horizontal: 12,
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Supplier',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _primaryGreen,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = _suppliers[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _lightGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.business, size: 18, color: _lightGreen),
                    ),
                    title: Text(
                      supplier['name'] ?? 'Unnamed',
                      style: TextStyle(
                        fontSize: 13,
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
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryGreen,
                    side: BorderSide(color: _primaryGreen),
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
}
