import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/purchase.dart';
import 'add_product_screen.dart';

class AddPurchaseScreen extends StatefulWidget {
  final Function(int)? onNavigateToHistory;

  const AddPurchaseScreen({super.key, this.onNavigateToHistory});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
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
  final TextEditingController _purchaseRateController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  // Discount fields
  bool _usePercentageDiscount = true;
  final TextEditingController _discountController = TextEditingController();
  double _discountValue = 0;

  // Search controllers for datalist
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _productController = TextEditingController();

  // Rounding amount - auto calculated with manual override option
  double _roundingAmount = 0;
  bool _isRoundingManual = false;
  final TextEditingController _roundingController = TextEditingController();

  bool _isLoading = false;
  double _productRate = 0;
  double _productSaleRate = 0;
  int _productGst = 18;

  List<QueryDocumentSnapshot> _suppliers = [];
  List<QueryDocumentSnapshot> _products = [];
  List<QueryDocumentSnapshot> _filteredSuppliers = [];
  List<QueryDocumentSnapshot> _filteredProducts = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Focus nodes for suggestions
  final FocusNode _supplierFocusNode = FocusNode();
  final FocusNode _productFocusNode = FocusNode();
  bool _showSupplierSuggestions = false;
  bool _showProductSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _loadProducts();

    // Add listeners for search
    _supplierController.addListener(_filterSuppliers);
    _productController.addListener(_filterProducts);

    // Add listener for discount
    _discountController.addListener(_onDiscountChanged);

    // Focus listeners
    _supplierFocusNode.addListener(() {
      if (_supplierFocusNode.hasFocus && _selectedSupplierId == null) {
        setState(() {
          _showSupplierSuggestions =
              _supplierController.text.isNotEmpty &&
              _filteredSuppliers.isNotEmpty;
        });
      } else if (!_supplierFocusNode.hasFocus) {
        // Increased delay to 500ms to allow tap to complete
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_supplierFocusNode.hasFocus) {
            setState(() {
              _showSupplierSuggestions = false;
            });
          }
        });
      }
    });

    _productFocusNode.addListener(() {
      if (_productFocusNode.hasFocus && _selectedProductId == null) {
        setState(() {
          // Show suggestions if there's text in the search field
          if (_productController.text.isNotEmpty) {
            _showProductSuggestions = true;
            _filterProducts();
          }
        });
      } else if (!_productFocusNode.hasFocus) {
        // Increased delay to 500ms to allow tap to complete
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_productFocusNode.hasFocus) {
            setState(() {
              _showProductSuggestions = false;
            });
          }
        });
      }
    });

    // Add listener to rounding controller for manual input
    _roundingController.addListener(_onRoundingChanged);
  }

  void _onDiscountChanged() {
    if (_discountController.text.isNotEmpty) {
      double? value = double.tryParse(_discountController.text);
      if (value != null && value >= 0) {
        setState(() {
          _discountValue = value;
        });
      }
    } else {
      setState(() {
        _discountValue = 0;
      });
    }
  }

  void _onRoundingChanged() {
    if (_isRoundingManual && _roundingController.text.isNotEmpty) {
      double? value = double.tryParse(_roundingController.text);
      if (value != null) {
        setState(() {
          _roundingAmount = value;
        });
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
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
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

  // Show Add Product Dialog with proper handling
  Future<void> _showAddProductDialog() async {
    // Hide product suggestions first
    if (mounted) {
      setState(() {
        _showProductSuggestions = false;
      });
    }

    // Remove keyboard/focus without waiting for a delayed overlay update
    _productFocusNode.unfocus();

    await Future.delayed(const Duration(milliseconds: 50));

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
                        onPressed: () {
                          Navigator.of(dialogContext).pop(false);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AddProductScreen(
                    onNavigateToProductList: (index) {
                      // Product saved successfully
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

    // Refresh products after dialog closes
    if (!mounted) return;

    await _loadProducts();

    if (result == true) {
      await _selectProductAfterAdd();
    }
  }

  Future<void> _selectProductAfterAdd() async {
    // Small delay to ensure the dialog is completely closed
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
        _showDialog(
          'Success',
          'Product added and selected automatically!',
          isError: false,
        );
      }
    } catch (e) {
      // Ignore error
    }
  }

  // Method to show existing invoice details in a dialog
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
                'Invoice #$invoiceNo already exists in the system.',
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
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: Colors.green[700],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Invoice Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please use a different invoice number to continue.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Focus on invoice field to change number
                FocusScope.of(context).requestFocus(FocusNode());
              },
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
    // Navigate to view existing purchase details
    Navigator.pop(context, {
      'navigateTo': 'purchaseDetails',
      'purchaseId': purchaseId,
    });
  }

  Future<void> _loadSuppliers() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('suppliers').get();
      setState(() {
        _suppliers = snapshot.docs;
        _filteredSuppliers = snapshot.docs;
      });
    } catch (e) {
      _showDialog('Error', 'Error loading suppliers: $e', isError: true);
    }
  }

  Future<void> _loadProducts() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('products').get();
      setState(() {
        _products = snapshot.docs;
        _filteredProducts = snapshot.docs;
      });
    } catch (e) {
      _showDialog('Error', 'Error loading products: $e', isError: true);
    }
  }

  void _filterSuppliers() {
    // Don't filter if a supplier is already selected
    if (_selectedSupplierId != null) {
      return;
    }

    String query = _supplierController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredSuppliers = _suppliers;
        _showSupplierSuggestions = false;
      } else {
        _filteredSuppliers = _suppliers.where((supplier) {
          Map<String, dynamic> data = supplier.data() as Map<String, dynamic>;
          String name = (data['supplierName'] ?? '').toString().toLowerCase();
          String phone = (data['phoneNumber'] ?? '').toString().toLowerCase();
          String email = (data['email'] ?? '').toString().toLowerCase();
          return name.contains(query) ||
              phone.contains(query) ||
              email.contains(query);
        }).toList();
        _showSupplierSuggestions =
            _filteredSuppliers.isNotEmpty && _supplierFocusNode.hasFocus;
      }
    });
  }

  void _filterProducts() {
    // Don't filter if a product is already selected
    if (_selectedProductId != null) {
      return;
    }

    String query = _productController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _products;
        _showProductSuggestions = false;
      } else {
        _filteredProducts = _products.where((product) {
          Map<String, dynamic> data = product.data() as Map<String, dynamic>;
          String name = (data['productName'] ?? '').toString().toLowerCase();
          String category = (data['category'] ?? '').toString().toLowerCase();
          String brand = (data['brand'] ?? '').toString().toLowerCase();
          return name.contains(query) ||
              category.contains(query) ||
              brand.contains(query);
        }).toList();
        // Show suggestions whenever there's a search query
        _showProductSuggestions = true;
      }
    });
  }

  void _selectSupplier(QueryDocumentSnapshot supplier) {
    Map<String, dynamic> data = supplier.data() as Map<String, dynamic>;
    setState(() {
      _selectedSupplierId = supplier.id;
      _selectedSupplierName = (data['supplierName'] ?? 'Unknown').toString();
      _supplierController.text = _selectedSupplierName!;
      _showSupplierSuggestions = false;
      _filteredSuppliers = _suppliers;
    });
    _supplierFocusNode.unfocus();

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
      _productController.text = _selectedProductName!;
      _productRate = (data['purchaseRate'] ?? 0).toDouble();
      _productSaleRate = (data['saleRate'] ?? 0).toDouble();
      _productGst = (data['gstPercentage'] ?? 18).toInt();
      _purchaseRateController.text = _productRate.toString();
      _quantityController.text = '1';
      _discountController.clear();
      _discountValue = 0;
      _showProductSuggestions = false;
      _filteredProducts = _products;
    });
    _productFocusNode.unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${_selectedProductName!}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _clearSupplierSelection() {
    setState(() {
      _selectedSupplierId = null;
      _selectedSupplierName = null;
      _supplierController.clear();
      _showSupplierSuggestions = false;
      _filteredSuppliers = _suppliers;
    });
    _supplierFocusNode.requestFocus();
  }

  void _clearProductSelection() {
    setState(() {
      _selectedProductId = null;
      _selectedProductName = null;
      _productController.clear();
      _purchaseRateController.clear();
      _quantityController.clear();
      _discountController.clear();
      _discountValue = 0;
      _showProductSuggestions = false;
      _filterProducts();
    });
    _productFocusNode.requestFocus();
  }

  void _addToCartWithDiscount() {
    if (_selectedProductId == null) {
      _showDialog('Error', 'Please select a product', isError: true);
      return;
    }

    if (_quantityController.text.trim().isEmpty) {
      _showDialog('Error', 'Please enter quantity', isError: true);
      return;
    }

    int quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      _showDialog('Error', 'Please enter valid quantity', isError: true);
      return;
    }

    double rate = double.tryParse(_purchaseRateController.text.trim()) ?? 0;
    if (rate <= 0) {
      _showDialog('Error', 'Please enter valid purchase rate', isError: true);
      return;
    }

    // Apply discount
    double discountAmount = 0;
    if (_discountValue > 0) {
      if (_usePercentageDiscount) {
        discountAmount = rate * (_discountValue / 100);
      } else {
        discountAmount = _discountValue;
      }
    }

    double finalRate = rate - discountAmount;
    if (finalRate < 0) {
      _showDialog(
        'Error',
        'Discount cannot exceed the purchase rate',
        isError: true,
      );
      return;
    }

    String productName = _selectedProductName!;

    // Check if item already exists in cart
    int existingIndex = _cartItems.indexWhere(
      (item) => item.productId == _selectedProductId,
    );

    if (existingIndex != -1) {
      // Update existing item
      setState(() {
        _cartItems[existingIndex].quantity += quantity;
        _cartItems[existingIndex].rate = finalRate;
        _cartItems[existingIndex].discount = discountAmount;
        _cartItems[existingIndex].discountType = _usePercentageDiscount
            ? 'percentage'
            : 'amount';
        _cartItems[existingIndex].total =
            finalRate * _cartItems[existingIndex].quantity;
        _cartItems[existingIndex].originalRate = rate;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated: $productName (Qty: ${_cartItems[existingIndex].quantity})',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // Add new item
      setState(() {
        _cartItems.add(
          CartItem(
            productId: _selectedProductId!,
            productName: productName,
            rate: finalRate,
            quantity: quantity,
            total: finalRate * quantity,
            gstPercentage: _productGst,
            discount: discountAmount,
            discountType: _usePercentageDiscount ? 'percentage' : 'amount',
            originalRate: rate,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added: $productName (Qty: $quantity)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Clear fields
    setState(() {
      _selectedProductId = null;
      _selectedProductName = null;
      _purchaseRateController.clear();
      _quantityController.clear();
      _discountController.clear();
      _discountValue = 0;
      _productRate = 0;
      _productSaleRate = 0;
      _productGst = 18;
      _productController.clear();
      _showProductSuggestions = false;
      _filteredProducts = _products;
    });

    _resetRounding();
  }

  void _removeFromCart(int index) {
    setState(() => _cartItems.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed product from cart'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 1),
      ),
    );
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

  // UPDATED: Improved rounding logic
  void _calculateRounding() {
    if (_isRoundingManual) return;

    double grandTotal = _getGrandTotalBeforeRounding();

    // Get nearest integer based on your rule
    int targetTotal;

    double decimalPart = grandTotal % 1;

    if (decimalPart <= 0.50) {
      targetTotal = grandTotal.floor();
    } else {
      targetTotal = grandTotal.ceil();
    }

    _roundingAmount = targetTotal - grandTotal;

    // Avoid floating point issues
    if (_roundingAmount.abs() < 0.001) {
      _roundingAmount = 0;
    }

    _roundingController.text = _roundingAmount.toStringAsFixed(2);
  }

  double _getGrandTotalBeforeRounding() => _getSubtotal() + _getTotalGST();

  double _getGrandTotal() {
    return _getGrandTotalBeforeRounding() + _roundingAmount;
  }

  void _resetRounding() {
    setState(() {
      _isRoundingManual = false;
      _roundingAmount = 0;
      _roundingController.clear();
    });
    // Recalculate after state update
    _calculateRounding();
  }

  void _toggleRoundingMode() {
    setState(() {
      _isRoundingManual = !_isRoundingManual;
      if (!_isRoundingManual) {
        _roundingController.clear();
        _calculateRounding();
      } else {
        // Set initial manual rounding to current auto value
        _roundingController.text = _roundingAmount.toStringAsFixed(2);
      }
    });
  }

  void _applyManualRounding() {
    double? value = double.tryParse(_roundingController.text);
    if (value != null) {
      setState(() {
        _roundingAmount = value;
        _isRoundingManual = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rounding set to: ${value.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      _showDialog('Error', 'Please enter a valid number', isError: true);
    }
  }

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

    // Check for duplicate invoice number
    try {
      QuerySnapshot existingInvoice = await _firestore
          .collection('purchases')
          .where('invoiceNo', isEqualTo: _invoiceController.text.trim())
          .get();

      if (existingInvoice.docs.isNotEmpty) {
        // Get the existing purchase data
        var existingDoc = existingInvoice.docs.first;
        var existingData = existingDoc.data() as Map<String, dynamic>;
        var existingDate = existingData['date'] != null
            ? (existingData['date'] as Timestamp).toDate()
            : null;
        var items = existingData['items'] ?? [];
        var grandTotal = (existingData['grandTotal'] ?? 0.0).toDouble();
        var supplierName = existingData['supplierName'] ?? 'Unknown';

        // Show dialog with existing invoice details
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
      // Continue with save if check fails
      print('Error checking duplicate invoice: $e');
    }

    setState(() => _isLoading = true);

    try {
      _calculateRounding();

      List<PurchaseItem> purchaseItems = _cartItems
          .map(
            (item) => PurchaseItem(
              productId: item.productId,
              productName: item.productName,
              rate: item.rate,
              quantity: item.quantity,
              total: item.total,
              gstPercentage: item.gstPercentage,
            ),
          )
          .toList();

      Map<String, dynamic> purchaseData = {
        'supplierId': _selectedSupplierId,
        'supplierName': _selectedSupplierName ?? 'Unknown',
        'invoiceNo': _invoiceController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate),
        'items': purchaseItems.map((item) => item.toMap()).toList(),
        'totalAmount': _getSubtotal(),
        'gstAmount': _getTotalGST(),
        'roundingAmount': _roundingAmount,
        'isRoundingManual': _isRoundingManual,
        'grandTotal': _getGrandTotal(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('purchases').add(purchaseData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase added successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Reset all fields
      setState(() {
        _selectedSupplierId = null;
        _selectedSupplierName = null;
        _cartItems.clear();
        _selectedProductId = null;
        _selectedProductName = null;
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
        _supplierController.clear();
        _productController.clear();
        _discountController.clear();
        _discountValue = 0;
        _filteredSuppliers = _suppliers;
        _filteredProducts = _products;
        _showSupplierSuggestions = false;
        _showProductSuggestions = false;
      });

      // Navigate to PurchaseHistoryScreen using the callback
      if (widget.onNavigateToHistory != null) {
        widget.onNavigateToHistory!(4); // Index 4 is PurchaseHistoryScreen
      } else {
        // Fallback: Pop the screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showDialog(
        'Error',
        'Error saving purchase: ${e.toString()}',
        isError: true,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 800;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: Container(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: SingleChildScrollView(
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
            _buildSupplierDatalist(),
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
            _buildProductSelectorWithSearch(),
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
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.green[700]!,
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
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
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Today',
                style: TextStyle(fontSize: 10, color: Colors.green[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // UPDATED: Supplier datalist with GestureDetector for single-click on web
  Widget _buildSupplierDatalist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedSupplierId != null
                  ? Colors.green
                  : Colors.grey[300]!,
              width: _selectedSupplierId != null ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _selectedSupplierId != null
                    ? Icons.check_circle
                    : Icons.business,
                color: _selectedSupplierId != null
                    ? Colors.green
                    : Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _supplierController,
                  focusNode: _supplierFocusNode,
                  style: const TextStyle(fontSize: 13),
                  readOnly: _selectedSupplierId != null,
                  decoration: InputDecoration(
                    hintText: _selectedSupplierId != null
                        ? 'Supplier selected ✓'
                        : 'Type to search supplier...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: _selectedSupplierId != null
                          ? Colors.green
                          : Colors.grey[400],
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    suffixIcon: _selectedSupplierId != null
                        ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.red,
                            ),
                            onPressed: _clearSupplierSelection,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        : (_supplierController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: _clearSupplierSelection,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              : null),
                  ),
                  onChanged: (value) {
                    if (value.isEmpty && _selectedSupplierId != null) {
                      _clearSupplierSelection();
                    }
                    if (_selectedSupplierId == null) {
                      _filterSuppliers();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        if (_showSupplierSuggestions &&
            _filteredSuppliers.isNotEmpty &&
            _selectedSupplierId == null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredSuppliers.length,
              itemBuilder: (context, index) {
                final supplier = _filteredSuppliers[index];
                final data = supplier.data() as Map<String, dynamic>;
                final name = (data['supplierName'] ?? 'Unknown').toString();
                final phone = data['phoneNumber']?.toString() ?? '';
                final email = data['email']?.toString() ?? '';

                // Supplier items with GestureDetector for single-click
                return GestureDetector(
                  onTap: () => _selectSupplier(supplier),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.business,
                          size: 20,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (phone.isNotEmpty || email.isNotEmpty)
                                Text(
                                  [
                                    phone,
                                    email,
                                  ].where((s) => s.isNotEmpty).join(' • '),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
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
          ),
        if (_selectedSupplierId != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  // UPDATED: Product selector with GestureDetector for single-click on web
  Widget _buildProductSelectorWithSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedProductId != null
                  ? Colors.green
                  : Colors.grey[300]!,
              width: _selectedProductId != null ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _selectedProductId != null ? Icons.check_circle : Icons.search,
                color: _selectedProductId != null
                    ? Colors.green
                    : Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _productController,
                  focusNode: _productFocusNode,
                  style: const TextStyle(fontSize: 13),
                  readOnly: _selectedProductId != null,
                  decoration: InputDecoration(
                    hintText: _selectedProductId != null
                        ? 'Product selected ✓'
                        : 'Type to search product...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: _selectedProductId != null
                          ? Colors.green
                          : Colors.grey[400],
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    suffixIcon: _selectedProductId != null
                        ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.red,
                            ),
                            onPressed: _clearProductSelection,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        : (_productController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: _clearProductSelection,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              : null),
                  ),
                  onChanged: (value) {
                    if (value.isEmpty && _selectedProductId != null) {
                      _clearProductSelection();
                    }
                    if (_selectedProductId == null) {
                      _filterProducts();
                      // Ensure suggestions are shown when there's text
                      if (value.isNotEmpty) {
                        setState(() {
                          _showProductSuggestions = true;
                        });
                      } else {
                        setState(() {
                          _showProductSuggestions = false;
                        });
                      }
                    }
                  },
                  onTap: () {
                    // Show suggestions when tapping the field
                    if (_selectedProductId == null &&
                        _productController.text.isNotEmpty) {
                      setState(() {
                        _showProductSuggestions = true;
                        _filterProducts();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // Show suggestions when there's text in the search field AND product not selected
        if (_productController.text.isNotEmpty &&
            _selectedProductId == null &&
            _showProductSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredProducts.isEmpty
                  ? 1
                  : _filteredProducts.length + 1,
              itemBuilder: (context, index) {
                // If no products found, show "Add New Product" with GestureDetector
                if (_filteredProducts.isEmpty) {
                  return GestureDetector(
                    onTap: () async {
                      // Important: close the suggestion UI before opening dialog
                      setState(() {
                        _showProductSuggestions = false;
                      });

                      await Future.delayed(const Duration(milliseconds: 30));

                      if (!mounted) return;

                      await _showAddProductDialog();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
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
                            'No products found. Add New Product',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Add New Product option at the end of results with GestureDetector
                if (index == _filteredProducts.length) {
                  return GestureDetector(
                    onTap: () async {
                      // Important: close the suggestion UI before opening dialog
                      setState(() {
                        _showProductSuggestions = false;
                      });

                      await Future.delayed(const Duration(milliseconds: 30));

                      if (!mounted) return;

                      await _showAddProductDialog();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
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
                            'Add New Product',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final product = _filteredProducts[index];
                final data = product.data() as Map<String, dynamic>;
                final name = (data['productName'] ?? 'Unknown').toString();
                final category = data['category']?.toString() ?? '';

                // Product items with GestureDetector for single-click
                return GestureDetector(
                  onTap: () => _selectProduct(product),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_bag,
                          size: 20,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (category.isNotEmpty)
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
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
          ),
        if (_selectedProductId != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Rate with header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchase Rate *',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextFormField(
                            controller: _purchaseRateController,
                            style: const TextStyle(fontSize: 13),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                              isDense: true,
                              prefixText: '₹ ',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quantity *',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextFormField(
                            controller: _quantityController,
                            style: const TextStyle(fontSize: 13),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '1',
                              hintStyle: TextStyle(fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Discount section - reduced size
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.discount, size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Discount (0% default)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                        const Spacer(),
                        // Toggle between Percentage and Amount
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: TextFormField(
                              controller: _discountController,
                              style: const TextStyle(fontSize: 12),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: _usePercentageDiscount ? '0' : '0.00',
                                hintStyle: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                isDense: true,
                                suffixText: _usePercentageDiscount ? '%' : '',
                                suffixStyle: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onChanged: (value) {
                                _onDiscountChanged();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: _addToCartWithDiscount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            minimumSize: const Size(40, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Icon(Icons.add, size: 18),
                        ),
                      ],
                    ),
                    if (_discountValue > 0 &&
                        _purchaseRateController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _buildDiscountPreview(),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue[700] : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountPreview() {
    double purchaseRate = double.tryParse(_purchaseRateController.text) ?? 0;
    double discountAmount = 0;
    String displayText = '';

    if (_usePercentageDiscount) {
      discountAmount = purchaseRate * (_discountValue / 100);
      displayText =
          '${_discountValue}% discount = ₹${discountAmount.toStringAsFixed(2)} off';
    } else {
      discountAmount = _discountValue;
      displayText = '₹${_discountValue.toStringAsFixed(2)} discount';
    }

    double finalRate = purchaseRate - discountAmount;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            displayText,
            style: TextStyle(
              fontSize: 10,
              color: Colors.green[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Final: ₹${finalRate.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSection() {
    // Calculate rounding without setState
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cart cleared successfully!'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 1),
                        ),
                      );
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return _buildCartItemCard(item, index);
                    },
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
    // Calculate rounding without setState
    _calculateRounding();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Rounding:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _isRoundingManual
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isRoundingManual)
                    Container(
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
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          isDense: true,
                        ),
                        onFieldSubmitted: (_) => _applyManualRounding(),
                      ),
                    )
                  else
                    Text(
                      _roundingAmount.toStringAsFixed(2),
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  const SizedBox(width: 4),
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
                    tooltip: _isRoundingManual
                        ? 'Switch to Auto'
                        : 'Switch to Manual',
                  ),
                ],
              ),
            ],
          ),
          if (_isRoundingManual)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isRoundingManual = false;
                      _roundingController.clear();
                    });
                    _calculateRounding();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    minimumSize: const Size(50, 25),
                    side: BorderSide(color: Colors.grey[400]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Auto', style: TextStyle(fontSize: 10)),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: _applyManualRounding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    minimumSize: const Size(50, 25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Apply', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(CartItem item, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!, width: 0.5),
      ),
      child: Container(
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
                  if (item.discount > 0)
                    Text(
                      '₹${item.originalRate.toStringAsFixed(2)} → ₹${item.rate.toStringAsFixed(2)} (${item.discountType == 'percentage' ? '${((item.discount / item.originalRate) * 100).toStringAsFixed(1)}% off' : '₹${item.discount.toStringAsFixed(2)} off'})',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  Text(
                    '₹${item.rate.toStringAsFixed(2)} x ${item.quantity}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => _updateCartItemQuantity(
                              index,
                              item.quantity - 1,
                            ),
                            icon: const Icon(Icons.remove, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 16,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              item.quantity.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _updateCartItemQuantity(
                              index,
                              item.quantity + 1,
                            ),
                            icon: const Icon(Icons.add, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
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

  Widget _buildSubmitButton() {
    return SizedBox(
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
    );
  }

  Widget _buildCartSummaryRow(
    String label,
    double value, {
    bool isBold = false,
    bool isRounding = false,
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
            isRounding
                ? value.toStringAsFixed(2)
                : '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isBold ? 13 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isRounding
                  ? Colors.blue
                  : (isBold ? Colors.green[700] : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _purchaseRateController.dispose();
    _quantityController.dispose();
    _supplierController.dispose();
    _productController.dispose();
    _roundingController.dispose();
    _discountController.dispose();
    _supplierFocusNode.dispose();
    _productFocusNode.dispose();
    super.dispose();
  }
}

// Cart Item Model
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
  });
}
