import 'package:flutter/material.dart';
import 'package:sales_stock/models/purchase_item.dart';
import 'package:sales_stock/services/firestore_service.dart';
import 'package:sales_stock/screens/purchase/create_purchase_form.dart';
import 'package:sales_stock/screens/purchase/create_purchase_preview.dart';
import 'package:sales_stock/screens/purchase/create_purchase_scanner.dart';
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
  int? _currentScanItemIndex;
  int? _currentScanImeiIndex;
  Map<int, bool> _showEditSections = {};
  bool _showPreview = false;
  Map<int, List<String>> _itemImeis = {};

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

  bool _isValidSerialNumber(String serial) {
    // Allow both IMEI (15 digits) and Serial Numbers (can be alphanumeric and longer)
    // Minimum length check, you can adjust as needed
    return serial.isNotEmpty && serial.length >= 10;
  }

  void _togglePreview() {
    setState(() {
      _showPreview = !_showPreview;
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: const Color(0xFFE53935),
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
          CreatePurchaseForm(
            primaryGreen: _primaryGreen,
            lightGreen: _lightGreen,
            formKey: _formKey,
            selectedDate: _selectedDate,
            selectDate: _selectDate,
            suppliers: _suppliers,
            selectedSupplier: _selectedSupplier,
            supplierController: _supplierController,
            showSupplierSelection: _showSupplierSelection,
            invoiceController: _invoiceController,
            notesController: _notesController,
            purchaseItems: _purchaseItems,
            itemImeis: _itemImeis,
            showEditSections: _showEditSections,
            subtotal: _subtotal,
            totalDiscount: _totalDiscount,
            gstAmount: _gstAmount,
            roundOff: _roundOff,
            totalAmount: _totalAmount,
            addNewItem: _addNewItem,
            toggleEditSection: _toggleEditSection,
            removeItem: _removeItem,
            showProductSelection: _showProductSelection,
            showScannerDialog: _showScannerDialog,
            showManualSerialEntry: _showManualSerialEntry,
            onSerialScanned: _onScanComplete,
            isValidSerialNumber: _isValidSerialNumber,
            togglePreview: _togglePreview,
            savePurchase: _savePurchase,
          ),
          if (_showPreview)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: CreatePurchasePreview(
                primaryGreen: _primaryGreen,
                lightGreen: _lightGreen,
                selectedDate: _selectedDate,
                selectedSupplier: _selectedSupplier,
                invoiceController: _invoiceController,
                purchaseItems: _purchaseItems,
                itemImeis: _itemImeis,
                subtotal: _subtotal,
                totalDiscount: _totalDiscount,
                gstAmount: _gstAmount,
                roundOff: _roundOff,
                totalAmount: _totalAmount,
                togglePreview: _togglePreview,
                confirmAndSavePurchase: _confirmAndSavePurchase,
                isValidSerialNumber: _isValidSerialNumber,
              ),
            ),
        ],
      ),
    );
  }

  // Methods that need to be accessible from child widgets
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
                  : const Color(0xFFFF9800),
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
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2196F3),
                ),
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
              : const Color(0xFFFFB300).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.phone_android,
          size: 20,
          color: hasPurchaseRate ? _lightGreen : const Color(0xFFFFB300),
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
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Sell: ₹${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 9,
                      color: const Color(0xFF2196F3),
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
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
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
                            color: const Color(0xFF3F51B5).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: const Color(0xFF3F51B5),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Common HSN for mobiles: 85171300 (18% GST)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: const Color(0xFF3F51B5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
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

  Future<void> _showScannerDialog(int itemIndex, {int? imeiIndex}) async {
    _currentScanItemIndex = itemIndex;
    _currentScanImeiIndex = imeiIndex;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatePurchaseScanner(
          itemIndex: itemIndex,
          imeiIndex: imeiIndex,
          currentSerial:
              imeiIndex != null &&
                  (_itemImeis[itemIndex]?.length ?? 0) > imeiIndex
              ? _itemImeis[itemIndex]![imeiIndex]
              : null,
        ),
      ),
    );

    if (result != null) {
      _onScanComplete(result);
    }
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
          style: TextStyle(color: const Color(0xFFE91E63), fontSize: 14),
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
              maxLength: 30,
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
                    backgroundColor: const Color(0xFFFFB300),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE53935),
              ),
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
                    backgroundColor: const Color(0xFFE53935),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
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

  void _onScanComplete(String scannedValue) {
    if (_currentScanItemIndex != null) {
      if (!_isValidSerialNumber(scannedValue)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid Serial. Must be at least 10 characters. Scanned: $scannedValue',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: const Color(0xFFE53935),
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

  Future<void> _savePurchase() async {
    // Instead of directly saving, show preview first
    _togglePreview();
  }

  Future<void> _confirmAndSavePurchase() async {
    if (_formKey.currentState!.validate() &&
        _selectedSupplier != null &&
        _purchaseItems.isNotEmpty) {
      for (var i = 0; i < _purchaseItems.length; i++) {
        final item = _purchaseItems[i];

        if (item.productId == null ||
            item.quantity == null ||
            item.rate == null) {
          _showErrorSnackbar(
            'Please fill all required fields for item ${i + 1}',
          );
          return;
        }

        final requiredImeiCount = item.quantity!.toInt();
        final itemImeis = _itemImeis[i] ?? [];
        if (itemImeis.length < requiredImeiCount) {
          _showErrorSnackbar(
            'Item ${i + 1}: Need $requiredImeiCount Serial Numbers, got ${itemImeis.length}',
          );
          return;
        }

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
