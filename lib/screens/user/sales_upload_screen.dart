import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneSaleUpload extends StatefulWidget {
  const PhoneSaleUpload({super.key});

  @override
  State<PhoneSaleUpload> createState() => _PhoneSaleUploadState();
}

class _PhoneSaleUploadState extends State<PhoneSaleUpload> {
  final TextEditingController _accessoriesSaleAmountController =
      TextEditingController();
  final TextEditingController _serviceAmountController =
      TextEditingController();
  final TextEditingController _gpayAmountController = TextEditingController();
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _cardAmountController = TextEditingController();

  bool _isLoading = false;
  DateTime _saleDate = DateTime.now();
  String? _shopId;
  String? _shopName;
  double _totalAmount = 0.0;
  double _enteredPaymentTotal = 0.0;

  // Phone sales data structure
  final List<PhoneSaleItem> _phoneSaleItems = [];

  // Selection states
  String? _selectedBrand;
  String? _selectedProduct;
  String? _selectedVariant;
  String? _selectedPurchaseMode;
  PaymentBreakdown _selectedPaymentBreakdown = PaymentBreakdown();
  String? _selectedFinanceType;

  // Controllers for current sale item
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _downPaymentController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _upgradeController = TextEditingController();
  final TextEditingController _supportController = TextEditingController();
  final TextEditingController _disbursementAmountController =
      TextEditingController();
  final TextEditingController _exchangeController = TextEditingController();
  final TextEditingController _customerCreditController =
      TextEditingController();

  // Payment breakdown controllers for Ready Cash
  final TextEditingController _rcCashController = TextEditingController();
  final TextEditingController _rcGpayController = TextEditingController();
  final TextEditingController _rcCardController = TextEditingController();
  final TextEditingController _rcCreditController = TextEditingController();

  // Down payment breakdown controllers for EMI
  final TextEditingController _dpCashController = TextEditingController();
  final TextEditingController _dpGpayController = TextEditingController();
  final TextEditingController _dpCardController = TextEditingController();
  final TextEditingController _dpCreditController = TextEditingController();

  // Available data lists
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _variants = [];

  // Price display
  double _selectedPrice = 0.0;

  // Purchase modes
  final List<String> _purchaseModes = ['Ready Cash', 'Credit Card', 'EMI'];

  // Finance companies
  final List<String> _financeCompaniesList = [
    'Bajaj Finance',
    'TVS Credit',
    'HDB Financial',
    'Samsung Finance',
    'Oppo Finance',
    'Vivo Finance',
    'yoga kshema Finance',
    'First credit private Finance',
    'ICICI Bank',
    'HDFC Bank',
    'Axis Bank',
    'Other',
  ];

  // Phone brands (now fetched from products collection)
  List<String> _phoneBrands = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Color scheme
  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _secondaryColor = const Color(0xFF64748B);
  final Color _accentColor = const Color(0xFF10B981);
  final Color _backgroundColor = const Color(0xFFF8FAFC);
  final Color _errorColor = const Color(0xFFEF4444);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _infoColor = const Color(0xFF3B82F6);
  final Color _purpleColor = const Color(0xFF8B5CF6);
  final Color _pinkColor = const Color(0xFFEC4899);
  final Color _tealColor = const Color(0xFF14B8A6); // For exchange
  final Color _orangeColor = const Color(0xFFF97316); // For customer credit
  final Color _discountColor = const Color(0xFF8B5CF6); // For discount
  final Color _returnColor = const Color(0xFFFF6B6B); // For balance returned

  @override
  void initState() {
    super.initState();
    _getUserShopId();
    _addPaymentListeners();
    _fetchBrands();

    // Add listeners to Ready Cash payment breakdown controllers
    _rcCashController.addListener(_updateReadyCashPaymentBreakdown);
    _rcGpayController.addListener(_updateReadyCashPaymentBreakdown);
    _rcCardController.addListener(_updateReadyCashPaymentBreakdown);
    _rcCreditController.addListener(_updateReadyCashPaymentBreakdown);

    // Add listeners to EMI down payment breakdown controllers
    _dpCashController.addListener(_updateEmiPaymentBreakdown);
    _dpGpayController.addListener(_updateEmiPaymentBreakdown);
    _dpCardController.addListener(_updateEmiPaymentBreakdown);
    _dpCreditController.addListener(_updateEmiPaymentBreakdown);

    _exchangeController.addListener(_updateCreditCardPayment);
    _customerCreditController.addListener(_updateCreditCardPayment);
    _discountController.addListener(_updateCreditCardPayment);
  }

  void _updateReadyCashPaymentBreakdown() {
    if (_selectedPurchaseMode == 'Ready Cash') {
      setState(() {
        _selectedPaymentBreakdown.cash =
            double.tryParse(_rcCashController.text) ?? 0.0;
        _selectedPaymentBreakdown.gpay =
            double.tryParse(_rcGpayController.text) ?? 0.0;
        _selectedPaymentBreakdown.card =
            double.tryParse(_rcCardController.text) ?? 0.0;
        _selectedPaymentBreakdown.credit =
            double.tryParse(_rcCreditController.text) ?? 0.0;
      });
    }
  }

  void _updateEmiPaymentBreakdown() {
    if (_selectedPurchaseMode == 'EMI') {
      setState(() {
        _selectedPaymentBreakdown.cash =
            double.tryParse(_dpCashController.text) ?? 0.0;
        _selectedPaymentBreakdown.gpay =
            double.tryParse(_dpGpayController.text) ?? 0.0;
        _selectedPaymentBreakdown.card =
            double.tryParse(_dpCardController.text) ?? 0.0;
        _selectedPaymentBreakdown.credit =
            double.tryParse(_dpCreditController.text) ?? 0.0;
      });
    }
  }

  void _addPaymentListeners() {
    _accessoriesSaleAmountController.addListener(_calculateTotals);
    _serviceAmountController.addListener(_calculateTotals);
    _gpayAmountController.addListener(_calculateTotals);
    _cashAmountController.addListener(_calculateTotals);
    _cardAmountController.addListener(_calculateTotals);
  }

  void _calculateTotals() {
    final saleAmount =
        double.tryParse(_accessoriesSaleAmountController.text) ?? 0.0;
    final serviceAmount = double.tryParse(_serviceAmountController.text) ?? 0.0;

    final gpayAmount = double.tryParse(_gpayAmountController.text) ?? 0.0;
    final cashAmount = double.tryParse(_cashAmountController.text) ?? 0.0;
    final cardAmount = double.tryParse(_cardAmountController.text) ?? 0.0;

    setState(() {
      _totalAmount = saleAmount + serviceAmount;
      _enteredPaymentTotal = gpayAmount + cashAmount + cardAmount;
    });
  }

  Future<void> _fetchBrands() async {
    try {
      final productsSnapshot = await _firestore.collection('products').get();

      final brands = <String>{};
      for (var doc in productsSnapshot.docs) {
        final data = doc.data();
        if (data['brand'] != null) {
          brands.add(data['brand'].toString().toLowerCase());
        }
      }

      setState(() {
        _phoneBrands = brands.toList()..sort();
      });
    } catch (e) {
      print('Error fetching brands: $e');
    }
  }

  Future<void> _fetchProductsByBrand(String brand) async {
    try {
      final productsSnapshot = await _firestore
          .collection('products')
          .where('brand', isEqualTo: brand.toLowerCase())
          .get();

      setState(() {
        _products = productsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['productName'] ?? '',
            'brand': data['brand'] ?? '',
            'variants': data['variants'] ?? [],
          };
        }).toList();
        _selectedProduct = null;
        _selectedVariant = null;
        _variants = [];
        _selectedPrice = 0.0;
      });
    } catch (e) {
      print('Error fetching products: $e');
    }
  }

  void _onProductSelected(String? productId) {
    setState(() {
      _selectedProduct = productId;
      _selectedVariant = null;
      _selectedPrice = 0.0;

      if (productId != null && productId.isNotEmpty) {
        final product = _products.firstWhere(
          (p) => p['id']?.toString() == productId,
          orElse: () => {},
        );
        if (product.isNotEmpty) {
          _variants = List<Map<String, dynamic>>.from(
            product['variants'] ?? [],
          );
        }
      } else {
        _variants = [];
      }
    });
  }

  void _onVariantSelected(String? variantKey) {
    setState(() {
      _selectedVariant = variantKey;
      if (variantKey != null && variantKey.isNotEmpty && _variants.isNotEmpty) {
        final variant = _variants.firstWhere(
          (v) => v['id']?.toString() == variantKey,
          orElse: () => {},
        );
        if (variant.isNotEmpty) {
          final price = variant['price'];
          if (price is num) {
            _selectedPrice = price.toDouble();
          } else if (price is String) {
            _selectedPrice = double.tryParse(price) ?? 0.0;
          } else {
            _selectedPrice = 0.0;
          }
        }
      }
    });
  }

  void _onPurchaseModeSelected(String? mode) {
    setState(() {
      _selectedPurchaseMode = mode;
      _selectedPaymentBreakdown = PaymentBreakdown();
      _selectedFinanceType = null;
      _discountController.clear();
      _downPaymentController.clear();
      _upgradeController.clear();
      _supportController.clear();
      _disbursementAmountController.clear();
      _exchangeController.clear();
      _customerCreditController.clear();
      _rcCashController.clear();
      _rcGpayController.clear();
      _rcCardController.clear();
      _rcCreditController.clear();
      _dpCashController.clear();
      _dpGpayController.clear();
      _dpCardController.clear();
      _dpCreditController.clear();

      if (mode == 'Ready Cash') {
        // Leave it blank for user to fill
      } else if (mode == 'Credit Card') {
        // For Credit Card, card amount will be effective price minus exchange and customer credit
        final effectivePrice = _calculateEffectivePrice();
        final exchange = double.tryParse(_exchangeController.text) ?? 0.0;
        final customerCredit =
            double.tryParse(_customerCreditController.text) ?? 0.0;
        _selectedPaymentBreakdown.card =
            effectivePrice - exchange - customerCredit;
      }
    });
  }

  double _calculateEffectivePrice() {
    final discount = double.tryParse(_discountController.text) ?? 0.0;

    // For EMI, discount is NOT subtracted from effective price
    if (_selectedPurchaseMode == 'EMI') {
      return _selectedPrice; // Original price without discount
    } else {
      // For Ready Cash and Credit Card, discount is subtracted from price
      final effectivePrice = _selectedPrice - discount;
      return effectivePrice < 0 ? 0.0 : effectivePrice;
    }
  }

  double _calculatePaymentTotal(PaymentBreakdown breakdown) {
    return breakdown.cash + breakdown.gpay + breakdown.card + breakdown.credit;
  }

  double _calculateAmountToPay() {
    final effectivePrice = _calculateEffectivePrice();
    final exchange = double.tryParse(_exchangeController.text) ?? 0.0;
    final customerCredit =
        double.tryParse(_customerCreditController.text) ?? 0.0;

    return effectivePrice - exchange - customerCredit;
  }

  double _calculateRemainingDownPayment() {
    final downPayment = double.tryParse(_downPaymentController.text) ?? 0.0;
    final exchange = double.tryParse(_exchangeController.text) ?? 0.0;
    final customerCredit =
        double.tryParse(_customerCreditController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;

    // For EMI: Discount is subtracted from down payment along with exchange and credit
    if (_selectedPurchaseMode == 'EMI') {
      final remainingDownPayment =
          downPayment - exchange - customerCredit - discount;
      // Ensure it doesn't go below 0 or above down payment
      return remainingDownPayment.clamp(0.0, downPayment);
    } else {
      // For non-EMI modes, discount is already applied to effective price
      final remainingDownPayment = downPayment - exchange - customerCredit;
      return remainingDownPayment.clamp(0.0, downPayment);
    }
  }

  void _updateCreditCardPayment() {
    if (_selectedPurchaseMode == 'Credit Card') {
      setState(() {
        final amountToPay = _calculateAmountToPay();
        final balanceReturned = _calculateBalanceReturned();
        _selectedPaymentBreakdown.card = balanceReturned > 0
            ? 0.0
            : (amountToPay > 0 ? amountToPay : 0.0);
      });
    }
  }

  double _calculateBalanceReturned() {
    final exchange = double.tryParse(_exchangeController.text) ?? 0.0;
    final customerCredit =
        double.tryParse(_customerCreditController.text) ?? 0.0;

    if (_selectedPurchaseMode == 'EMI') {
      final downPayment = double.tryParse(_downPaymentController.text) ?? 0.0;
      final discount = double.tryParse(_discountController.text) ?? 0.0;

      // For EMI: If exchange + customer credit is greater than down payment - discount
      // then return the balance
      final totalAdjustments = exchange + customerCredit;
      final adjustedDownPayment = downPayment - discount;

      if (totalAdjustments > adjustedDownPayment) {
        return totalAdjustments - adjustedDownPayment;
      }
      return 0.0;
    } else {
      // For Ready Cash and Credit Card
      final effectivePrice = _calculateEffectivePrice();
      final totalAdjustments = exchange + customerCredit;

      if (totalAdjustments > effectivePrice) {
        return totalAdjustments - effectivePrice;
      }
      return 0.0;
    }
  }

  void _addPhoneSaleItem() {
    if (_selectedBrand == null ||
        _selectedProduct == null ||
        _selectedVariant == null ||
        _selectedPurchaseMode == null ||
        _selectedPrice == 0) {
      _showMessage('Please complete all required fields');
      return;
    }

    if (_customerNameController.text.isEmpty) {
      _showMessage('Please enter customer name');
      return;
    }

    final effectivePrice = _calculateEffectivePrice();
    final exchange = double.tryParse(_exchangeController.text) ?? 0.0;
    final customerCredit =
        double.tryParse(_customerCreditController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final amountToPay = _calculateAmountToPay();
    final balanceReturned = _calculateBalanceReturned();

    // For non-EMI modes, validate discount doesn't exceed price
    if (_selectedPurchaseMode != 'EMI') {
      if (effectivePrice < 0) {
        _showMessage('Discount cannot be more than price');
        return;
      }
    }

    // Validate based on purchase mode
    if (_selectedPurchaseMode == 'Ready Cash') {
      // For Ready Cash with balance returned, no payment needed
      if (balanceReturned > 0) {
        // Set payment breakdown to zero when balance is returned
        _selectedPaymentBreakdown = PaymentBreakdown();
        _rcCashController.clear();
        _rcGpayController.clear();
        _rcCardController.clear();
        _rcCreditController.clear();
      } else {
        final paymentTotal = _calculatePaymentTotal(_selectedPaymentBreakdown);
        if (paymentTotal == 0 && amountToPay > 0) {
          _showMessage('Please enter payment amounts for Ready Cash');
          return;
        }
        if ((paymentTotal - amountToPay).abs() > 0.01) {
          _showMessage(
            'Payment total (${paymentTotal.toStringAsFixed(2)}) does not match amount to pay (${amountToPay.toStringAsFixed(2)})',
          );
          return;
        }
      }
    } else if (_selectedPurchaseMode == 'EMI') {
      if (_selectedFinanceType == null) {
        _showMessage('Please select finance company for EMI');
        return;
      }
      if (_downPaymentController.text.isEmpty) {
        _showMessage('Please enter down payment amount for EMI');
        return;
      }
      final downPayment = double.tryParse(_downPaymentController.text) ?? 0.0;
      if (downPayment == 0) {
        _showMessage('Please enter down payment amount for EMI');
        return;
      }

      // Calculate remaining down payment after exchange, customer credit, and discount
      final remainingDownPayment = _calculateRemainingDownPayment();

      // For EMI with balance returned, remaining down payment will be 0
      if (balanceReturned == 0 && remainingDownPayment > 0) {
        if (_calculatePaymentTotal(_selectedPaymentBreakdown) == 0) {
          _showMessage(
            'Please enter payment mode(s) for remaining down payment',
          );
          return;
        }
        final downPaymentTotal = _calculatePaymentTotal(
          _selectedPaymentBreakdown,
        );
        if ((downPaymentTotal - remainingDownPayment).abs() > 0.01) {
          _showMessage(
            'Payment total (${downPaymentTotal.toStringAsFixed(2)}) does not match remaining down payment (${remainingDownPayment.toStringAsFixed(2)})',
          );
          return;
        }
      }
    } else if (_selectedPurchaseMode == 'Credit Card') {
      final cardAmount = _selectedPaymentBreakdown.card;
      if (balanceReturned > 0) {
        // No card payment needed when balance is returned
        if (cardAmount > 0) {
          _showMessage(
            'No card payment needed when exchange value is greater than amount to pay',
          );
          return;
        }
      } else {
        if ((cardAmount - amountToPay).abs() > 0.01) {
          _showMessage(
            'Card amount (${cardAmount.toStringAsFixed(2)}) does not match amount to pay (${amountToPay.toStringAsFixed(2)})',
          );
          return;
        }
      }
    }

    final product = _products.firstWhere((p) => p['id'] == _selectedProduct);
    final variant = _variants.firstWhere((v) => v['id'] == _selectedVariant);

    final phoneSaleItem = PhoneSaleItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      brand: _selectedBrand ?? '',
      productId: _selectedProduct ?? '',
      productName: product['name']?.toString() ?? '',
      variant: variant['name']?.toString() ?? '',
      variantKey: variant['id']?.toString() ?? '',
      price: _selectedPrice,
      discount: discount,
      effectivePrice: effectivePrice,
      purchaseMode: _selectedPurchaseMode ?? '',
      paymentBreakdown: _selectedPaymentBreakdown,
      financeType: _selectedFinanceType,
      upgrade: _upgradeController.text,
      support: _supportController.text,
      disbursementAmount:
          double.tryParse(_disbursementAmountController.text) ?? 0.0,
      downPayment: _selectedPurchaseMode == 'EMI'
          ? double.tryParse(_downPaymentController.text) ?? 0.0
          : 0.0,
      exchangeValue: exchange,
      customerCredit: customerCredit,
      amountToPay: amountToPay > 0 ? amountToPay : 0.0,
      balanceReturnedToCustomer: balanceReturned,
      customerName: _customerNameController.text,
      customerPhone: _customerPhoneController.text,
      addedAt: DateTime.now(),
    );

    setState(() {
      _phoneSaleItems.add(phoneSaleItem);
      _resetForm();
    });

    // Show warning if balance is returned
    if (balanceReturned > 0) {
      _showMessage(
        'Balance of ₹${balanceReturned.toStringAsFixed(2)} will be returned to customer',
        isError: false,
      );
    }
  }

  void _resetForm() {
    setState(() {
      _selectedBrand = null;
      _selectedProduct = null;
      _selectedVariant = null;
      _selectedPurchaseMode = null;
      _selectedPaymentBreakdown = PaymentBreakdown();
      _selectedFinanceType = null;
      _selectedPrice = 0.0;
      _customerNameController.clear();
      _customerPhoneController.clear();
      _discountController.clear();
      _downPaymentController.clear();
      _upgradeController.clear();
      _supportController.clear();
      _disbursementAmountController.clear();
      _exchangeController.clear();
      _customerCreditController.clear();
      _rcCashController.clear();
      _rcGpayController.clear();
      _rcCardController.clear();
      _rcCreditController.clear();
      _dpCashController.clear();
      _dpGpayController.clear();
      _dpCardController.clear();
      _dpCreditController.clear();
      _products = [];
      _variants = [];
    });
  }

  void _removePhoneSaleItem(String id) {
    setState(() {
      _phoneSaleItems.removeWhere((item) => item.id == id);
    });
  }

  void _getUserShopId() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          setState(() {
            _shopId = userData['shopId'];
            _shopName = userData['shopName'];
          });
        }
      }
    } catch (e) {
      print('Error getting shop ID: $e');
    }
  }

  void _uploadSalesData() async {
    if (_accessoriesSaleAmountController.text.isEmpty) {
      _showMessage('Please enter sale amount');
      return;
    }

    final saleAmount = double.tryParse(_accessoriesSaleAmountController.text);
    final serviceAmount = double.tryParse(_serviceAmountController.text) ?? 0.0;

    if (saleAmount == null) {
      _showMessage('Please enter valid sale amount');
      return;
    }

    // Validate payment amounts
    final gpayAmount = double.tryParse(_gpayAmountController.text) ?? 0.0;
    final cashAmount = double.tryParse(_cashAmountController.text) ?? 0.0;
    final cardAmount = double.tryParse(_cardAmountController.text) ?? 0.0;

    final paymentTotal = gpayAmount + cashAmount + cardAmount;
    final calculatedTotal = saleAmount + serviceAmount;

    if ((paymentTotal - calculatedTotal).abs() > 0.01) {
      _showMessage(
        'Payment total (${paymentTotal.toStringAsFixed(2)}) does not match calculated total (${calculatedTotal.toStringAsFixed(2)})',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        _showMessage('User not authenticated');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (_shopId == null) {
        _showMessage(
          'Shop information not found. Please check your profile setup.',
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Prepare phone sales data
      double totalPhoneSalesValue = 0.0;
      double totalPhoneDiscount = 0.0;
      double totalDisbursementAmount = 0.0;
      double totalExchangeValue = 0.0;
      double totalCustomerCredit = 0.0;
      double totalAmountToPay = 0.0;
      double totalBalanceReturned = 0.0;
      int totalPhonesSold = _phoneSaleItems.length;

      // Convert phone sale items to Firestore compatible format
      final phoneSalesData = _phoneSaleItems.map((item) {
        totalPhoneSalesValue += item.price;
        totalPhoneDiscount += item.discount;
        totalDisbursementAmount += item.disbursementAmount;
        totalExchangeValue += item.exchangeValue;
        totalCustomerCredit += item.customerCredit;
        totalAmountToPay += item.amountToPay;
        totalBalanceReturned += item.balanceReturnedToCustomer;
        return item.toMap();
      }).toList();

      final salesData = {
        'userId': user.uid,
        'userEmail': user.email,
        'shopId': _shopId,
        'shopName': _shopName,
        'saleDate': _saleDate,
        'accessoriesSaleAmount': saleAmount,
        'serviceAmount': serviceAmount,
        'totalAmount': calculatedTotal,
        // Payment breakdown
        'gpayAmount': gpayAmount,
        'cashAmount': cashAmount,
        'cardAmount': cardAmount,
        'paymentTotal': paymentTotal,
        // Phone sales
        'phoneSales': phoneSalesData,
        'totalPhonesSold': totalPhonesSold,
        'totalPhoneSalesValue': totalPhoneSalesValue,
        'totalPhoneDiscount': totalPhoneDiscount,
        'totalDisbursementAmount': totalDisbursementAmount,
        'totalExchangeValue': totalExchangeValue,
        'totalCustomerCredit': totalCustomerCredit,
        'totalAmountToPay': totalAmountToPay,
        'totalBalanceReturned': totalBalanceReturned,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('sales').add(salesData);

      _showMessage('Sales data uploaded successfully!', isError: false);
      _clearForm();
    } catch (e) {
      _showMessage('Failed to upload sales data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? _errorColor : _accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _clearForm() {
    _accessoriesSaleAmountController.clear();
    _serviceAmountController.clear();
    _gpayAmountController.clear();
    _cashAmountController.clear();
    _cardAmountController.clear();
    _customerNameController.clear();
    _customerPhoneController.clear();
    _discountController.clear();
    _downPaymentController.clear();
    _upgradeController.clear();
    _supportController.clear();
    _disbursementAmountController.clear();
    _exchangeController.clear();
    _customerCreditController.clear();
    _rcCashController.clear();
    _rcGpayController.clear();
    _rcCardController.clear();
    _rcCreditController.clear();
    _dpCashController.clear();
    _dpGpayController.clear();
    _dpCardController.clear();
    _dpCreditController.clear();

    setState(() {
      _saleDate = DateTime.now();
      _totalAmount = 0.0;
      _enteredPaymentTotal = 0.0;
      _phoneSaleItems.clear();
      _resetForm();
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _saleDate) {
      setState(() {
        _saleDate = picked;
      });
    }
  }

  Widget _buildPhoneSalesSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            if (_phoneSaleItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Added Phone Sales (${_phoneSaleItems.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _secondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              ..._phoneSaleItems.map((item) => _buildPhoneSaleItemCard(item)),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_iphone,
                    color: _primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Phone Sales',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const Spacer(),
                _buildPhoneStats(),
              ],
            ),
            const SizedBox(height: 12),

            // Phone Sales Form
            _buildPhoneSaleForm(),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: _addPhoneSaleItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Phone Sale'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneSaleForm() {
    final balanceReturned = _calculateBalanceReturned();
    final amountToPay = _calculateAmountToPay();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer Details
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            _buildAdditionalField(
              label: 'Customer Name *',
              controller: _customerNameController,
              hint: 'Enter customer name',
              icon: Icons.person,
              iconColor: _primaryColor,
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 8),
            const SizedBox(width: 8),
            _buildAdditionalField(
              label: 'Customer Phone',
              controller: _customerPhoneController,
              hint: 'Enter phone number',
              icon: Icons.phone,
              iconColor: _primaryColor,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Brand Selection
        _buildDropdown(
          label: 'Select Brand *',
          value: _selectedBrand,
          items: _phoneBrands.map((brand) {
            return DropdownMenuItem<String>(
              value: brand,
              child: Text(
                brand.toUpperCase(),
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedBrand = value;
              if (value != null) {
                _fetchProductsByBrand(value);
              }
            });
          },
          hint: 'Choose phone brand',
        ),
        const SizedBox(height: 12),

        // Product Selection
        if (_selectedBrand != null) ...[
          _buildDropdown(
            label: 'Select Product *',
            value: _selectedProduct,
            items: _products.map((product) {
              return DropdownMenuItem<String>(
                value: product['id']?.toString() ?? '',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name']?.toString() ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      product['brand']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: _secondaryColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: _onProductSelected,
            hint: 'Choose product model',
          ),
          const SizedBox(height: 12),
        ],

        // Variant Selection
        if (_selectedProduct != null && _variants.isNotEmpty) ...[
          _buildDropdown(
            label: 'Select Variant *',
            value: _selectedVariant,
            items: _variants.map((variant) {
              return DropdownMenuItem<String>(
                value: variant['id']?.toString() ?? '',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          variant['ram']?.toString() ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text("/"),
                        Text(
                          variant['storage']?.toString() ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '₹${variant['price'] ?? 0}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: _onVariantSelected,
            hint: 'Choose RAM/Storage variant',
          ),
          const SizedBox(height: 12),
        ],

        // Price Display
        if (_selectedPrice > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _accentColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Price',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _secondaryColor,
                  ),
                ),
                Text(
                  '₹${_selectedPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Purchase Mode
        if (_selectedPrice > 0) ...[
          _buildDropdown(
            label: 'Purchase Mode *',
            value: _selectedPurchaseMode,
            items: _purchaseModes.map((mode) {
              return DropdownMenuItem<String>(
                value: mode,
                child: Text(mode, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: _onPurchaseModeSelected,
            hint: 'Select purchase mode',
          ),
          const SizedBox(height: 12),
        ],

        // Balance Returned Warning
        if (balanceReturned > 0)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _returnColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _returnColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: _returnColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Balance to be Returned to Customer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _returnColor,
                        ),
                      ),
                      Text(
                        '₹${balanceReturned.toStringAsFixed(2)} will be returned to customer',
                        style: TextStyle(fontSize: 12, color: _secondaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Ready Cash Payment Breakdown
        if (_selectedPurchaseMode == 'Ready Cash' && balanceReturned == 0) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Breakdown *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentField(
                      label: 'Cash',
                      controller: _rcCashController,
                      onChanged: (value) {
                        // Handled by listener
                      },
                      hint: 'Cash amount',
                      icon: Icons.money,
                      iconColor: const Color(0xFF34A853),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentField(
                      label: 'GPay',
                      controller: _rcGpayController,
                      onChanged: (value) {
                        // Handled by listener
                      },
                      hint: 'GPay amount',
                      icon: Icons.phone_android,
                      iconColor: const Color(0xFF4285F4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentField(
                      label: 'Card',
                      controller: _rcCardController,
                      onChanged: (value) {
                        // Handled by listener
                      },
                      hint: 'Card amount',
                      icon: Icons.credit_card,
                      iconColor: const Color(0xFFFBBC05),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentField(
                      label: 'Credit',
                      controller: _rcCreditController,
                      onChanged: (value) {
                        // Handled by listener
                      },
                      hint: 'Credit amount',
                      icon: Icons.credit_score,
                      iconColor: _orangeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPaymentValidationForReadyCash(),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Credit Card Purchase Mode
        if (_selectedPurchaseMode == 'Credit Card') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBC05).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFBBC05).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.credit_card, color: const Color(0xFFFBBC05)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credit Card Payment',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            balanceReturned > 0
                                ? 'No payment needed - balance will be returned'
                                : 'Adjusted for exchange and customer credit',
                            style: TextStyle(
                              fontSize: 12,
                              color: _secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${_calculateEffectivePrice().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFBBC05),
                          ),
                        ),
                        Text(
                          'Effective Price',
                          style: TextStyle(
                            fontSize: 10,
                            color: _secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  balanceReturned > 0
                      ? 'No Card Payment Required'
                      : 'Card Amount: ₹${_selectedPaymentBreakdown.card.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFBBC05),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // EMI Options
        if (_selectedPurchaseMode == 'EMI') ...[
          // Finance Company
          _buildDropdown(
            label: 'Finance Company *',
            value: _selectedFinanceType,
            items: _financeCompaniesList.map((company) {
              return DropdownMenuItem<String>(
                value: company,
                child: Text(company, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedFinanceType = value;
              });
            },
            hint: 'Select finance company',
          ),
          const SizedBox(height: 12),

          // Down Payment Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Down Payment Amount *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _secondaryColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _downPaymentController,
                onChanged: (value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Enter down payment amount',
                  prefixIcon: Icon(
                    Icons.attach_money,
                    color: _primaryColor,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: _secondaryColor.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _primaryColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Additional Information Section (for all purchase modes)
        if (_selectedPurchaseMode != null && _selectedPrice > 0) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Adjustments',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 12),

              // Exchange Value Field
              _buildAdditionalField(
                label: 'Exchange Value',
                controller: _exchangeController,
                hint: 'Enter exchange value',
                icon: Icons.swap_horiz,
                iconColor: _tealColor,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() {
                    _updateCreditCardPayment();
                  });
                },
              ),
              const SizedBox(height: 12),

              // Customer Credit Field (Pay Later)
              _buildAdditionalField(
                label: 'Customer Credit (Pay Later)',
                controller: _customerCreditController,
                hint: 'Enter credit amount',
                icon: Icons.credit_score,
                iconColor: _orangeColor,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() {
                    _updateCreditCardPayment();
                  });
                },
              ),
              const SizedBox(height: 12),

              // Discount Field (Note: Different behavior for EMI vs non-EMI)
              _buildAdditionalField(
                label: _selectedPurchaseMode == 'EMI'
                    ? 'Discount (Deducted from Down Payment)'
                    : 'Discount Amount (Deducted from Price)',
                controller: _discountController,
                hint: 'Enter discount amount',
                icon: Icons.discount,
                iconColor: _discountColor,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() {
                    _updateCreditCardPayment();
                  });
                },
              ),
              const SizedBox(height: 12),

              // Payment Calculation Summary
              const SizedBox(height: 12),
              _buildPaymentSummary(),
              const SizedBox(height: 12),

              // EMI Additional Fields and Down Payment Breakdown
              if (_selectedPurchaseMode == 'EMI') ...[
                // Down Payment Breakdown (Multiple payment methods)
                if (_shouldShowDownPaymentBreakdown())
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remaining Down Payment Breakdown *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _secondaryColor,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: _buildPaymentField(
                              label: 'Cash',
                              controller: _dpCashController,
                              onChanged: (value) {
                                // Handled by listener
                              },
                              hint: 'Cash amount',
                              icon: Icons.money,
                              iconColor: const Color(0xFF34A853),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPaymentField(
                              label: 'GPay',
                              controller: _dpGpayController,
                              onChanged: (value) {
                                // Handled by listener
                              },
                              hint: 'GPay amount',
                              icon: Icons.phone_android,
                              iconColor: const Color(0xFF4285F4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPaymentField(
                              label: 'Card',
                              controller: _dpCardController,
                              onChanged: (value) {
                                // Handled by listener
                              },
                              hint: 'Card amount',
                              icon: Icons.credit_card,
                              iconColor: const Color(0xFFFBBC05),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPaymentField(
                              label: 'Credit',
                              controller: _dpCreditController,
                              onChanged: (value) {
                                // Handled by listener
                              },
                              hint: 'Credit amount',
                              icon: Icons.credit_score,
                              iconColor: _orangeColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildPaymentValidationForEMI(),
                    ],
                  ),

                const SizedBox(height: 12),
                _buildAdditionalField(
                  label: 'Upgrade',
                  controller: _upgradeController,
                  hint: 'Enter upgrade details',
                  icon: Icons.upgrade,
                  iconColor: _purpleColor,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 12),

                // Support Field
                _buildAdditionalField(
                  label: 'Support',
                  controller: _supportController,
                  hint: 'Enter support details',
                  icon: Icons.support_agent,
                  iconColor: _pinkColor,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 12),

                // Disbursement Amount Field
                _buildAdditionalField(
                  label: 'Disbursement Amount',
                  controller: _disbursementAmountController,
                  hint: 'Enter disbursement amount',
                  icon: Icons.monetization_on,
                  iconColor: _accentColor,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  bool _shouldShowDownPaymentBreakdown() {
    if (_selectedPurchaseMode != 'EMI') return false;

    final downPayment = double.tryParse(_downPaymentController.text) ?? 0.0;
    if (downPayment == 0) return false;

    final remainingDownPayment = _calculateRemainingDownPayment();
    final balanceReturned = _calculateBalanceReturned();

    // Don't show breakdown if balance is returned
    return remainingDownPayment > 0 && balanceReturned == 0;
  }

  Widget _buildPaymentSummary() {
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final effectivePrice = _calculateEffectivePrice();
    final exchange = double.tryParse(_exchangeController.text) ?? 0.0;
    final customerCredit =
        double.tryParse(_customerCreditController.text) ?? 0.0;
    final amountToPay = _calculateAmountToPay();
    final balanceReturned = _calculateBalanceReturned();

    // For EMI, calculate remaining down payment
    final downPayment = double.tryParse(_downPaymentController.text) ?? 0.0;
    final remainingDownPayment = _calculateRemainingDownPayment();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Original Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Original Price:',
                style: TextStyle(fontSize: 12, color: _secondaryColor),
              ),
              Text(
                '₹${_selectedPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _secondaryColor,
                ),
              ),
            ],
          ),

          // Discount (applies differently based on purchase mode)
          if (discount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedPurchaseMode == 'EMI'
                      ? 'Discount (from Down Payment):'
                      : 'Discount (from Price):',
                  style: TextStyle(fontSize: 12, color: _discountColor),
                ),
                Text(
                  '-₹${discount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _discountColor,
                  ),
                ),
              ],
            ),

          // Effective Price (shows differently for EMI)
          if (_selectedPurchaseMode != 'EMI') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Effective Price:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
                Text(
                  '₹${effectivePrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
            Divider(height: 16, color: _secondaryColor.withOpacity(0.2)),
          ],

          // For EMI, show down payment section with discount
          if (_selectedPurchaseMode == 'EMI' && downPayment > 0)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Down Payment:',
                      style: TextStyle(fontSize: 12, color: _secondaryColor),
                    ),
                    Text(
                      '₹${downPayment.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _secondaryColor,
                      ),
                    ),
                  ],
                ),
                if (discount > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Discount Applied:',
                        style: TextStyle(fontSize: 12, color: _discountColor),
                      ),
                      Text(
                        '-₹${discount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _discountColor,
                        ),
                      ),
                    ],
                  ),
                if (exchange > 0 || customerCredit > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        if (exchange > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Exchange Applied:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _tealColor,
                                ),
                              ),
                              Text(
                                '-₹${exchange.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _tealColor,
                                ),
                              ),
                            ],
                          ),
                        if (customerCredit > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Customer Credit Applied:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _orangeColor,
                                ),
                              ),
                              Text(
                                '-₹${customerCredit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _orangeColor,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                if (balanceReturned == 0 && remainingDownPayment > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Remaining Down Payment:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _accentColor,
                        ),
                      ),
                      Text(
                        '₹${remainingDownPayment.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _accentColor,
                        ),
                      ),
                    ],
                  ),
                Divider(height: 16, color: _secondaryColor.withOpacity(0.2)),
              ],
            ),

          // For non-EMI, show exchange and credit directly
          if (_selectedPurchaseMode != 'EMI')
            Column(
              children: [
                if (exchange > 0 || customerCredit > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        if (exchange > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Exchange:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _tealColor,
                                ),
                              ),
                              Text(
                                '-₹${exchange.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _tealColor,
                                ),
                              ),
                            ],
                          ),
                        if (customerCredit > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Customer Credit:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _orangeColor,
                                ),
                              ),
                              Text(
                                '-₹${customerCredit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _orangeColor,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                Divider(height: 16, color: _secondaryColor.withOpacity(0.2)),
              ],
            ),

          // Balance Returned to Customer
          if (balanceReturned > 0)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.money_off, size: 14, color: _returnColor),
                        const SizedBox(width: 4),
                        Text(
                          'Balance Returned to Customer:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _returnColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹${balanceReturned.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _returnColor,
                      ),
                    ),
                  ],
                ),
                Divider(height: 16, color: _secondaryColor.withOpacity(0.2)),
              ],
            ),

          // Final amount to pay
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedPurchaseMode == 'EMI'
                    ? 'Amount Financed (EMI):'
                    : 'Amount to Pay:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                ),
              ),
              Text(
                '₹${amountToPay > 0 ? amountToPay.toStringAsFixed(2) : '0.00'}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                ),
              ),
            ],
          ),
          if (_selectedPurchaseMode == 'EMI')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Note: Discount is deducted from down payment for EMI',
                style: TextStyle(
                  fontSize: 10,
                  color: _secondaryColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (balanceReturned > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Note: Customer will receive ₹${balanceReturned.toStringAsFixed(2)} as balance',
                style: TextStyle(
                  fontSize: 10,
                  color: _returnColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdditionalField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required TextInputType keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _secondaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: iconColor, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _secondaryColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: iconColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          keyboardType: keyboardType,
        ),
      ],
    );
  }

  Widget _buildPaymentField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required String hint,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: _secondaryColor)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: iconColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _secondaryColor.withOpacity(0.3)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildPaymentValidationForReadyCash() {
    final paymentTotal = _calculatePaymentTotal(_selectedPaymentBreakdown);
    final targetAmount = _calculateAmountToPay();
    final balanceReturned = _calculateBalanceReturned();
    final isValid = balanceReturned > 0
        ? paymentTotal == 0
        : (paymentTotal - targetAmount).abs() <= 0.01 && paymentTotal >= 0;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isValid
            ? _accentColor.withOpacity(0.1)
            : _errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid
              ? _accentColor.withOpacity(0.3)
              : _errorColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.error,
            size: 16,
            color: isValid ? _accentColor : _errorColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balanceReturned > 0
                      ? 'No Payment Required - Balance will be Returned'
                      : 'Payment Total: ₹${paymentTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isValid ? _accentColor : _errorColor,
                  ),
                ),
                if (!isValid && balanceReturned == 0)
                  Text(
                    'Should be ₹${targetAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: _errorColor),
                  ),
              ],
            ),
          ),
          if (paymentTotal > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_selectedPaymentBreakdown.cash > 0)
                  Text(
                    'Cash: ₹${_selectedPaymentBreakdown.cash.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10, color: _secondaryColor),
                  ),
                if (_selectedPaymentBreakdown.gpay > 0)
                  Text(
                    'GPay: ₹${_selectedPaymentBreakdown.gpay.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10, color: _secondaryColor),
                  ),
                if (_selectedPaymentBreakdown.card > 0)
                  Text(
                    'Card: ₹${_selectedPaymentBreakdown.card.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10, color: _secondaryColor),
                  ),
                if (_selectedPaymentBreakdown.credit > 0)
                  Text(
                    'Credit: ₹${_selectedPaymentBreakdown.credit.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10, color: _secondaryColor),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentValidationForEMI() {
    final downPayment = double.tryParse(_downPaymentController.text) ?? 0.0;
    final exchange = double.tryParse(_exchangeController.text) ?? 0.0;
    final customerCredit =
        double.tryParse(_customerCreditController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final remainingDownPayment = _calculateRemainingDownPayment();
    final balanceReturned = _calculateBalanceReturned();

    final paymentTotal = _calculatePaymentTotal(_selectedPaymentBreakdown);
    final isValid =
        (paymentTotal - remainingDownPayment).abs() <= 0.01 &&
        paymentTotal >= 0;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isValid
            ? _accentColor.withOpacity(0.1)
            : _errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid
              ? _accentColor.withOpacity(0.3)
              : _errorColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.error,
            size: 16,
            color: isValid ? _accentColor : _errorColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balanceReturned > 0
                      ? 'Balance will be returned to customer'
                      : 'Remaining Down Payment: ₹${paymentTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isValid ? _accentColor : _errorColor,
                  ),
                ),
                if (downPayment > 0)
                  Text(
                    'Down Payment: ₹${downPayment.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 10, color: _secondaryColor),
                  ),
                if (exchange > 0)
                  Text(
                    'Exchange: -₹${exchange.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 10, color: _tealColor),
                  ),
                if (customerCredit > 0)
                  Text(
                    'Customer Credit: -₹${customerCredit.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 10, color: _orangeColor),
                  ),
                if (discount > 0)
                  Text(
                    'Discount: -₹${discount.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 10, color: _discountColor),
                  ),
                if (balanceReturned > 0)
                  Text(
                    'Balance Returned: ₹${balanceReturned.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 10, color: _returnColor),
                  ),
                if (!isValid && balanceReturned == 0)
                  Text(
                    'Should be ₹${remainingDownPayment.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: _errorColor),
                  ),
              ],
            ),
          ),
          if (paymentTotal > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_selectedPaymentBreakdown.cash > 0)
                  Text(
                    'Cash: ₹${_selectedPaymentBreakdown.cash.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10, color: _secondaryColor),
                  ),
                if (_selectedPaymentBreakdown.gpay > 0)
                  Text(
                    'GPay: ₹${_selectedPaymentBreakdown.gpay.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10, color: _secondaryColor),
                  ),
                if (_selectedPaymentBreakdown.card > 0)
                  Text(
                    'Card: ₹${_selectedPaymentBreakdown.card.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10, color: _secondaryColor),
                  ),
                if (_selectedPaymentBreakdown.credit > 0)
                  Text(
                    'Credit: ₹${_selectedPaymentBreakdown.credit.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10, color: _secondaryColor),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneSaleItemCard(PhoneSaleItem item) {
    final paymentTotal = _calculatePaymentTotal(item.paymentBreakdown);
    final remainingDownPayment = item.purchaseMode == 'EMI'
        ? item.downPayment -
              item.exchangeValue -
              item.customerCredit -
              item.discount
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _secondaryColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Info
            if (item.customerName.isNotEmpty || item.customerPhone.isNotEmpty)
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _secondaryColor.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.person, size: 14, color: _primaryColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.customerName.isNotEmpty)
                            Text(
                              item.customerName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          if (item.customerPhone.isNotEmpty)
                            Text(
                              item.customerPhone,
                              style: TextStyle(
                                fontSize: 11,
                                color: _secondaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: _errorColor, size: 18),
                      onPressed: () => _removePhoneSaleItem(item.id),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // Balance Returned Display
            if (item.balanceReturnedToCustomer > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _returnColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _returnColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.money_off, size: 16, color: _returnColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Balance Returned to Customer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _returnColor,
                            ),
                          ),
                          Text(
                            '₹${item.balanceReturnedToCustomer.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _returnColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Product Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${item.productName} ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.brand.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: _secondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.variant,
                    style: TextStyle(
                      fontSize: 10,
                      color: _accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Price: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: _secondaryColor,
                          ),
                        ),
                        Text(
                          '₹${item.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _accentColor,
                          ),
                        ),
                      ],
                    ),
                    // Show discount differently for EMI vs non-EMI
                    if (item.discount > 0)
                      Row(
                        children: [
                          Text(
                            item.purchaseMode == 'EMI'
                                ? 'Discount (from DP): '
                                : 'Discount: ',
                            style: TextStyle(
                              fontSize: 11,
                              color: _secondaryColor,
                            ),
                          ),
                          Text(
                            '-₹${item.discount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: item.purchaseMode == 'EMI'
                                  ? _discountColor
                                  : _infoColor,
                            ),
                          ),
                        ],
                      ),
                    if (item.purchaseMode != 'EMI')
                      Row(
                        children: [
                          Text(
                            'Effective: ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _primaryColor,
                            ),
                          ),
                          Text(
                            '₹${item.effectivePrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getPurchaseModeColor(
                      item.purchaseMode,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.purchaseMode,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getPurchaseModeColor(item.purchaseMode),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            // Payment breakdown display for Ready Cash
            if (item.purchaseMode == 'Ready Cash' && paymentTotal > 0) ...[
              const SizedBox(height: 6),
              _buildPaymentBreakdownDisplay(
                breakdown: item.paymentBreakdown,
                total: paymentTotal,
                label: 'Payment',
              ),
            ] else if (item.purchaseMode == 'EMI') ...[
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.financeType != null)
                    Text(
                      '${item.financeType}',
                      style: TextStyle(fontSize: 12, color: _secondaryColor),
                    ),
                  if (item.downPayment > 0)
                    Text(
                      'Down Payment: ₹${item.downPayment.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 11, color: _secondaryColor),
                    ),
                  if (item.exchangeValue > 0 ||
                      item.customerCredit > 0 ||
                      item.discount > 0)
                    Container(
                      padding: const EdgeInsets.all(4),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          if (item.exchangeValue > 0)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Exchange Applied:',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _tealColor,
                                  ),
                                ),
                                Text(
                                  '-₹${item.exchangeValue.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _tealColor,
                                  ),
                                ),
                              ],
                            ),
                          if (item.customerCredit > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Credit Applied:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _orangeColor,
                                    ),
                                  ),
                                  Text(
                                    '-₹${item.customerCredit.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _orangeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.discount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Discount Applied:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _discountColor,
                                    ),
                                  ),
                                  Text(
                                    '-₹${item.discount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _discountColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (item.balanceReturnedToCustomer == 0 &&
                      remainingDownPayment > 0)
                    Text(
                      'Remaining Down Payment: ₹${remainingDownPayment.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _accentColor,
                      ),
                    ),
                  if (paymentTotal > 0)
                    _buildPaymentBreakdownDisplay(
                      breakdown: item.paymentBreakdown,
                      total: paymentTotal,
                      label: 'Remaining Down Payment',
                    ),
                ],
              ),
            ] else if (item.purchaseMode == 'Credit Card') ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.credit_card,
                    size: 12,
                    color: const Color(0xFFFBBC05),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.balanceReturnedToCustomer > 0
                        ? 'No Payment - Balance Returned'
                        : 'Card Payment: ₹${item.paymentBreakdown.card.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFFFBBC05),
                    ),
                  ),
                ],
              ),
            ],

            // Additional Information Display
            if (item.upgrade.isNotEmpty ||
                item.support.isNotEmpty ||
                item.disbursementAmount > 0) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (item.upgrade.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _purpleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.upgrade, size: 10, color: _purpleColor),
                          const SizedBox(width: 4),
                          Text(
                            item.upgrade,
                            style: TextStyle(fontSize: 10, color: _purpleColor),
                          ),
                        ],
                      ),
                    ),
                  if (item.support.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _pinkColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.support_agent,
                            size: 10,
                            color: _pinkColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.support,
                            style: TextStyle(fontSize: 10, color: _pinkColor),
                          ),
                        ],
                      ),
                    ),
                  if (item.disbursementAmount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on,
                            size: 10,
                            color: _accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Disbursement: ₹${item.disbursementAmount.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 10, color: _accentColor),
                          ),
                        ],
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

  Widget _buildPaymentBreakdownDisplay({
    required PaymentBreakdown breakdown,
    required double total,
    required String label,
  }) {
    final paymentMethods = <String>[];
    if (breakdown.cash > 0) {
      paymentMethods.add('Cash: ₹${breakdown.cash.toStringAsFixed(0)}');
    }
    if (breakdown.gpay > 0) {
      paymentMethods.add('GPay: ₹${breakdown.gpay.toStringAsFixed(0)}');
    }
    if (breakdown.card > 0) {
      paymentMethods.add('Card: ₹${breakdown.card.toStringAsFixed(0)}');
    }
    if (breakdown.credit > 0) {
      paymentMethods.add('Credit: ₹${breakdown.credit.toStringAsFixed(0)}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$label: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _secondaryColor,
              ),
            ),
            Text(
              '₹${total.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _accentColor,
              ),
            ),
          ],
        ),
        if (paymentMethods.isNotEmpty)
          Text(
            paymentMethods.join(', '),
            style: TextStyle(fontSize: 11, color: _secondaryColor),
          ),
      ],
    );
  }

  Color _getPurchaseModeColor(String mode) {
    switch (mode) {
      case 'Ready Cash':
        return _accentColor;
      case 'Credit Card':
        return const Color(0xFFFBBC05);
      case 'EMI':
        return const Color(0xFF8B5CF6);
      default:
        return _primaryColor;
    }
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _secondaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _secondaryColor.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            items: items,
            onChanged: onChanged,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(color: _secondaryColor.withOpacity(0.5)),
            ),
            icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
            isExpanded: true,
            style: const TextStyle(fontSize: 14, color: Colors.black),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneStats() {
    final totalExchange = _phoneSaleItems.fold<double>(
      0,
      (sum, item) => sum + item.exchangeValue,
    );
    final totalCredit = _phoneSaleItems.fold<double>(
      0,
      (sum, item) => sum + item.customerCredit,
    );
    final totalDiscount = _phoneSaleItems.fold<double>(
      0,
      (sum, item) => sum + item.discount,
    );
    final totalBalanceReturned = _phoneSaleItems.fold<double>(
      0,
      (sum, item) => sum + item.balanceReturnedToCustomer,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _secondaryColor.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.inventory_2, size: 12, color: _primaryColor),
                      const SizedBox(width: 2),
                      Text(
                        _phoneSaleItems.length.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Phones',
                    style: TextStyle(fontSize: 9, color: _secondaryColor),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Container(
                width: 1,
                height: 20,
                color: _secondaryColor.withOpacity(0.2),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.attach_money, size: 12, color: _accentColor),
                      const SizedBox(width: 2),
                      Text(
                        _phoneSaleItems
                            .fold<double>(0, (sum, item) => sum + item.price)
                            .toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _accentColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Value',
                    style: TextStyle(fontSize: 9, color: _secondaryColor),
                  ),
                ],
              ),
            ],
          ),
          if (totalExchange > 0 ||
              totalCredit > 0 ||
              totalDiscount > 0 ||
              totalBalanceReturned > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (totalExchange > 0) ...[
                    Icon(Icons.swap_horiz, size: 10, color: _tealColor),
                    const SizedBox(width: 2),
                    Text(
                      'Ex: ₹${totalExchange.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 10, color: _tealColor),
                    ),
                  ],
                  if (totalCredit > 0) ...[
                    if (totalExchange > 0) const SizedBox(width: 4),
                    Icon(Icons.credit_score, size: 10, color: _orangeColor),
                    const SizedBox(width: 2),
                    Text(
                      'Cr: ₹${totalCredit.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 10, color: _orangeColor),
                    ),
                  ],
                  if (totalDiscount > 0) ...[
                    if (totalExchange > 0 || totalCredit > 0)
                      const SizedBox(width: 4),
                    Icon(Icons.discount, size: 10, color: _discountColor),
                    const SizedBox(width: 2),
                    Text(
                      'Dis: ₹${totalDiscount.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 10, color: _discountColor),
                    ),
                  ],
                  if (totalBalanceReturned > 0) ...[
                    if (totalExchange > 0 ||
                        totalCredit > 0 ||
                        totalDiscount > 0)
                      const SizedBox(width: 4),
                    Icon(Icons.money_off, size: 10, color: _returnColor),
                    const SizedBox(width: 2),
                    Text(
                      'Ret: ₹${totalBalanceReturned.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 10, color: _returnColor),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, const Color(0xFF1D4ED8)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Daily Sales Report',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildShopInfo() {
    if (_shopId == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _secondaryColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.store, color: _secondaryColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: _isLoading
                  ? Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Loading shop...',
                          style: TextStyle(
                            fontSize: 12,
                            color: _secondaryColor,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Shop information not available',
                      style: TextStyle(fontSize: 12, color: _secondaryColor),
                    ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _accentColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.store, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Active Shop",
                  style: TextStyle(
                    fontSize: 10,
                    color: _secondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _shopName!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool isOptional = false,
    String? hintText,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _secondaryColor,
                fontSize: 13,
              ),
            ),
            if (isOptional)
              Text(
                ' (Optional)',
                style: TextStyle(
                  color: _secondaryColor.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: iconColor ?? _primaryColor, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _secondaryColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _primaryColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sale Date',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _secondaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: _secondaryColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: _primaryColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_saleDate.day}/${_saleDate.month}/${_saleDate.year}',
                  style: TextStyle(fontSize: 14, color: _secondaryColor),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down, color: _primaryColor, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Payment Breakdown Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.payment, color: _accentColor, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  'Payment Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const Spacer(),
                _buildPaymentTotalDisplay(),
              ],
            ),
            const SizedBox(height: 16),

            // Payment fields in 2 columns
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    label: 'GPay Amount',
                    icon: Icons.phone_android,
                    controller: _gpayAmountController,
                    hintText: 'GPay amount',
                    iconColor: const Color(0xFF4285F4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputField(
                    label: 'Cash Amount',
                    icon: Icons.money,
                    controller: _cashAmountController,
                    hintText: 'Cash amount',
                    iconColor: const Color(0xFF34A853),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInputField(
              label: 'Card Amount',
              icon: Icons.credit_card,
              controller: _cardAmountController,
              hintText: 'Card amount',
              iconColor: const Color(0xFFFBBC05),
            ),

            // Validation message
            if (_totalAmount > 0 &&
                (_enteredPaymentTotal - _totalAmount).abs() > 0.01)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _errorColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: _errorColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment total (${_enteredPaymentTotal.toStringAsFixed(2)}) does not match calculated total (${_totalAmount.toStringAsFixed(2)})',
                        style: TextStyle(fontSize: 12, color: _errorColor),
                      ),
                    ),
                  ],
                ),
              ),
            if (_totalAmount > 0 &&
                (_enteredPaymentTotal - _totalAmount).abs() <= 0.01)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accentColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: _accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Payment amounts match the total',
                      style: TextStyle(
                        fontSize: 12,
                        color: _accentColor,
                        fontWeight: FontWeight.w500,
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

  Widget _buildPaymentTotalDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _secondaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calculate, size: 12, color: _primaryColor),
              const SizedBox(width: 4),
              Text(
                'Total: ₹${_totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Paid: ₹${_enteredPaymentTotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 10,
              color: _enteredPaymentTotal == _totalAmount
                  ? _accentColor
                  : (_enteredPaymentTotal > _totalAmount
                        ? _warningColor
                        : _errorColor),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    bool paymentsMatch = (_enteredPaymentTotal - _totalAmount).abs() <= 0.01;

    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        gradient:
            (_isLoading ||
                _shopId == null ||
                !paymentsMatch ||
                _totalAmount == 0)
            ? null
            : LinearGradient(
                colors: [_primaryColor, const Color(0xFF1D4ED8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        borderRadius: BorderRadius.circular(12),
        color:
            (_isLoading ||
                _shopId == null ||
                !paymentsMatch ||
                _totalAmount == 0)
            ? _secondaryColor.withOpacity(0.3)
            : null,
      ),
      child: ElevatedButton(
        onPressed:
            (_isLoading ||
                _shopId == null ||
                !paymentsMatch ||
                _totalAmount == 0)
            ? null
            : _uploadSalesData,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Uploading...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Text(
                _shopId == null
                    ? 'Waiting for Shop Info'
                    : (!paymentsMatch
                          ? 'Fix Payment Amounts'
                          : _totalAmount == 0
                          ? 'Enter Sale Amount'
                          : 'Upload Sales Report'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Sales Upload'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 20),

            // Shop Info
            _buildShopInfo(),
            const SizedBox(height: 20),

            // Main Form
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDatePicker(),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'Sale Total Amount',
                      icon: Icons.attach_money,
                      controller: _accessoriesSaleAmountController,
                      hintText: 'Enter total sale amount',
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(
                      label: 'Service Amount',
                      icon: Icons.build,
                      controller: _serviceAmountController,
                      isOptional: true,
                      hintText: 'Enter service amount (optional)',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Section
            _buildPaymentSection(),
            const SizedBox(height: 16),

            // Phone Sales Section
            _buildPhoneSalesSection(),

            const SizedBox(height: 20),

            // Upload Button
            _buildUploadButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _accessoriesSaleAmountController.dispose();
    _serviceAmountController.dispose();
    _gpayAmountController.dispose();
    _cashAmountController.dispose();
    _cardAmountController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _discountController.dispose();
    _downPaymentController.dispose();
    _upgradeController.dispose();
    _supportController.dispose();
    _disbursementAmountController.dispose();
    _exchangeController.dispose();
    _customerCreditController.dispose();
    _rcCashController.dispose();
    _rcGpayController.dispose();
    _rcCardController.dispose();
    _rcCreditController.dispose();
    _dpCashController.dispose();
    _dpGpayController.dispose();
    _dpCardController.dispose();
    _dpCreditController.dispose();

    super.dispose();
  }
}

class PhoneSaleItem {
  final String id;
  final String brand;
  final String productId;
  final String productName;
  final String variant;
  final String variantKey;
  final double price;
  final double discount;
  final double effectivePrice;
  final String purchaseMode;
  final PaymentBreakdown paymentBreakdown;
  final String? financeType;
  final String upgrade;
  final String support;
  final double disbursementAmount;
  final double downPayment;
  final double exchangeValue;
  final double customerCredit;
  final double amountToPay;
  final double balanceReturnedToCustomer;
  final String customerName;
  final String customerPhone;
  final DateTime addedAt;

  PhoneSaleItem({
    required this.id,
    required this.brand,
    required this.productId,
    required this.productName,
    required this.variant,
    required this.variantKey,
    required this.price,
    required this.discount,
    required this.effectivePrice,
    required this.purchaseMode,
    required this.paymentBreakdown,
    this.financeType,
    required this.upgrade,
    required this.support,
    required this.disbursementAmount,
    required this.downPayment,
    required this.exchangeValue,
    required this.customerCredit,
    required this.amountToPay,
    required this.balanceReturnedToCustomer,
    required this.customerName,
    required this.customerPhone,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brand': brand,
      'productId': productId,
      'productName': productName,
      'variant': variant,
      'variantKey': variantKey,
      'price': price,
      'discount': discount,
      'effectivePrice': effectivePrice,
      'purchaseMode': purchaseMode,
      'paymentBreakdown': paymentBreakdown.toMap(),
      'financeType': financeType,
      'upgrade': upgrade,
      'support': support,
      'disbursementAmount': disbursementAmount,
      'downPayment': downPayment,
      'exchangeValue': exchangeValue,
      'customerCredit': customerCredit,
      'amountToPay': amountToPay,
      'balanceReturnedToCustomer': balanceReturnedToCustomer,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}

class PaymentBreakdown {
  double cash;
  double gpay;
  double card;
  double credit;

  PaymentBreakdown({
    this.cash = 0.0,
    this.gpay = 0.0,
    this.card = 0.0,
    this.credit = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {'cash': cash, 'gpay': gpay, 'card': card, 'credit': credit};
  }

  factory PaymentBreakdown.fromMap(Map<String, dynamic> map) {
    return PaymentBreakdown(
      cash: (map['cash'] as num?)?.toDouble() ?? 0.0,
      gpay: (map['gpay'] as num?)?.toDouble() ?? 0.0,
      card: (map['card'] as num?)?.toDouble() ?? 0.0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
