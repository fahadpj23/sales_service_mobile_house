import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PhoneSaleUpload extends StatefulWidget {
  const PhoneSaleUpload({super.key});

  @override
  State<PhoneSaleUpload> createState() => _PhoneSaleUploadState();
}

class _PhoneSaleUploadState extends State<PhoneSaleUpload> {
  bool _isLoading = false;
  bool _loadingShopInfo = false;
  bool _loadingBills = false;
  bool _withoutBillNumber = false;
  DateTime _saleDate = DateTime.now();
  String? _shopId;
  String? _shopName;

  // Selection states
  String? _selectedBrand;
  String? _selectedProductModel;
  String? _selectedVariant;
  String? _selectedPurchaseMode;
  PaymentBreakdown _selectedPaymentBreakdown = PaymentBreakdown();
  String? _selectedFinanceType;
  String? _selectedBillNumber;

  // NEW: Enhanced Gift selection states
  List<String> _selectedGifts = [];
  bool _isOtherGift = false;
  final TextEditingController _otherGiftController = TextEditingController();
  bool _showGiftDropdown = false;

  // NEW: EMI Loan fields
  final TextEditingController _loanIdController = TextEditingController();
  bool _autoDebit = false;
  bool _insurance = false;

  // Controllers
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
  final TextEditingController _productModelController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _imeiController = TextEditingController();

  // EMI Controllers - NO DEFAULT VALUES
  final TextEditingController _numberOfEmiController = TextEditingController();
  final TextEditingController _perMonthEmiController = TextEditingController();

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

  // Bill search controller
  final TextEditingController _billSearchController = TextEditingController();
  final FocusNode _billSearchFocusNode = FocusNode();

  // Lists
  final List<String> _phoneBrands = [
    'samsung',
    'vivo',
    'oppo',
    'xiaomi',
    'realme',
    'poco',
    'tecno',
    'iqoo',
    'motorola',
    'nothing',
    'pixel',
    'infinix',
    'apple',
    'nokia',
    'google',
    'huawei',
    'oneplus',
    'honor',
    'itel',
    'micromax',
    'lava',
    'spanio',
  ];

  final List<String> _purchaseModes = ['Ready Cash', 'Credit Card', 'EMI'];
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

  // ENHANCED: Gift options list for multi-selection - FIXED with valid Flutter icons
  final List<Map<String, dynamic>> _giftOptions = [
    {'name': 'screenGuard', 'icon': Icons.screen_lock_portrait},
    {'name': 'mobile cover', 'icon': Icons.phone_iphone},
    {'name': 'airpod', 'icon': Icons.headphones},
    {'name': 'neckband', 'icon': Icons.headset},
    {'name': 'headset', 'icon': Icons.headset_mic},
    {'name': 'speaker', 'icon': Icons.speaker},
    {'name': 'watch', 'icon': Icons.watch},
    {'name': 'charger', 'icon': Icons.battery_charging_full},
    {'name': 'cable', 'icon': Icons.usb},
    {'name': 'power bank', 'icon': Icons.battery_unknown},
    {'name': 'memory card', 'icon': Icons.sd_storage},
    {'name': 'tempered glass', 'icon': Icons.shield},
    {'name': 'selfie stick', 'icon': Icons.self_improvement},
    {'name': 'tripod', 'icon': Icons.camera},
    {'name': 'ring light', 'icon': Icons.light},
    {'name': 'Other', 'icon': Icons.add_circle_outline},
  ];

  // Bill numbers list
  List<String> _billNumbers = [];
  Map<String, Map<String, dynamic>> _billDataMap = {};

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Color Scheme
  final Color _primaryColor = const Color(0xFF10B981);
  final Color _primaryDarkColor = const Color(0xFF059669);
  final Color _primaryLightColor = const Color(0xFF34D399);
  final Color _secondaryColor = const Color(0xFF64748B);
  final Color _accentColor = const Color(0xFF8B5CF6);
  final Color _backgroundColor = const Color(0xFFF8FAFC);
  final Color _errorColor = const Color(0xFFEF4444);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _infoColor = const Color(0xFF3B82F6);
  final Color _purpleColor = const Color(0xFF8B5CF6);
  final Color _pinkColor = const Color(0xFFEC4899);
  final Color _tealColor = const Color(0xFF14B8A6);
  final Color _orangeColor = const Color(0xFFF97316);
  final Color _discountColor = const Color(0xFF8B5CF6);
  final Color _returnColor = const Color(0xFFFF6B6B);
  final Color _billAutofillColor = const Color(0xFF8B5CF6);
  final Color _successColor = const Color(0xFF10B981);
  final Color _darkGreenColor = const Color(0xFF047857);
  final Color _giftColor = const Color(0xFFEC4899);
  final Color _loanColor = const Color(0xFF8B5CF6);
  final Color _autoDebitColor = const Color(0xFF14B8A6);
  final Color _insuranceColor = const Color(0xFFF97316);

  final Color _veryLightGreenColor = const Color(0xFFF0FDF4);
  final Color _softGreenColor = const Color(0xFFDCFCE7);

  @override
  void initState() {
    super.initState();
    _getUserShopId();

    // Add listeners
    _rcCashController.addListener(_updateReadyCashPaymentBreakdown);
    _rcGpayController.addListener(_updateReadyCashPaymentBreakdown);
    _rcCardController.addListener(_updateReadyCashPaymentBreakdown);
    _rcCreditController.addListener(_updateReadyCashPaymentBreakdown);

    _dpCashController.addListener(_updateEmiPaymentBreakdown);
    _dpGpayController.addListener(_updateEmiPaymentBreakdown);
    _dpCardController.addListener(_updateEmiPaymentBreakdown);
    _dpCreditController.addListener(_updateEmiPaymentBreakdown);

    _exchangeController.addListener(_updateCreditCardPayment);
    _customerCreditController.addListener(_updateCreditCardPayment);
    _discountController.addListener(_updateCreditCardPayment);
    _priceController.addListener(_updatePrice);

    // Initialize with empty values
    _downPaymentController.text = "";
    _upgradeController.text = "0";
    _supportController.text = "0";
    _disbursementAmountController.text = "0";
    _numberOfEmiController.text = "";
    _perMonthEmiController.text = "";

    _billSearchController.addListener(() {
      setState(() {});
    });

    _billSearchFocusNode.addListener(() {
      if (!_billSearchFocusNode.hasFocus && _selectedBillNumber == null) {
        _billSearchController.clear();
      }
    });
  }

  bool get _isSamsungBrand => _selectedBrand?.toLowerCase() == 'samsung';

  List<String> get _filteredBillNumbers {
    final searchText = _billSearchController.text.toLowerCase();
    if (searchText.isEmpty) {
      return _billNumbers;
    } else {
      return _billNumbers
          .where((bill) => bill.toLowerCase().contains(searchText))
          .toList();
    }
  }

  // ENHANCED: Get formatted gift list for display
  String get _formattedGiftList {
    if (_selectedGifts.isEmpty) return '';
    final gifts = _selectedGifts.where((g) => g.isNotEmpty).toList();
    if (gifts.isEmpty) return '';
    if (gifts.length == 1) return gifts.first;
    return '${gifts.length} items: ${gifts.join(', ')}';
  }

  // ENHANCED: Get final gift value for database
  List<String>? get _finalGiftValues {
    if (_selectedGifts.isEmpty) return null;
    return _selectedGifts.where((g) => g.isNotEmpty).toList();
  }

  // ENHANCED: Toggle gift selection
  void _toggleGift(String giftName) {
    setState(() {
      if (giftName == 'Other') {
        _isOtherGift = true;
        _showGiftDropdown = false;
      } else {
        if (_selectedGifts.contains(giftName)) {
          _selectedGifts.remove(giftName);
        } else {
          _selectedGifts.add(giftName);
        }
      }
    });
  }

  // ENHANCED: Add custom gift
  void _addCustomGift() {
    if (_otherGiftController.text.trim().isNotEmpty) {
      setState(() {
        _selectedGifts.add(_otherGiftController.text.trim());
        _otherGiftController.clear();
        _isOtherGift = false;
      });
    }
  }

  // ENHANCED: Remove gift
  void _removeGift(String gift) {
    setState(() {
      _selectedGifts.remove(gift);
    });
  }

  Future<void> _loadBillNumbers() async {
    try {
      setState(() => _loadingBills = true);

      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _loadingBills = false);
        return;
      }

      if (_shopId == null) {
        await _getUserShopId();
        if (_shopId == null) {
          _showMessage('Shop information not available.');
          setState(() => _loadingBills = false);
          return;
        }
      }

      final billsSnapshot = await _firestore
          .collection('bills')
          .where('shopId', isEqualTo: _shopId)
          .limit(100)
          .get();

      final billNumbers = <String>[];
      final billDataMap = <String, Map<String, dynamic>>{};

      for (var doc in billsSnapshot.docs) {
        final billData = doc.data();
        final billNumber = billData['billNumber']?.toString();
        final billShopId = billData['shopId']?.toString();

        if (billShopId == _shopId &&
            billNumber != null &&
            billNumber.isNotEmpty) {
          billNumbers.add(billNumber);
          billDataMap[billNumber] = billData;
        }
      }

      setState(() {
        _billNumbers = billNumbers;
        _billDataMap = billDataMap;
        _loadingBills = false;
      });
    } catch (e) {
      _showMessage('Error loading bills: $e');
      setState(() => _loadingBills = false);
    }
  }

  Future<void> _autofillFromBill(String? billNumber) async {
    if (billNumber == null || billNumber.isEmpty) {
      _showMessage('No bill number selected');
      return;
    }

    if (!_billDataMap.containsKey(billNumber)) {
      _showMessage('Bill data not found for $billNumber');
      return;
    }

    final billData = _billDataMap[billNumber];
    if (billData == null) {
      _showMessage('Bill data not found for $billNumber');
      return;
    }

    try {
      final customerName = billData['customerName']?.toString() ?? '';
      final customerPhone = billData['customerMobile']?.toString() ?? '';
      final imei = billData['imei']?.toString() ?? '';

      final originalPhoneData =
          billData['originalPhoneData'] as Map<String, dynamic>?;
      final productBrand = originalPhoneData?['productBrand']?.toString() ?? '';
      final productName = originalPhoneData?['productName']?.toString() ?? '';
      final productPrice =
          (originalPhoneData?['productPrice'] as num?)?.toDouble() ?? 0.0;

      Timestamp? billDateTimestamp = billData['billDate'];
      DateTime? billDate = billDateTimestamp?.toDate();

      setState(() {
        _customerNameController.text = customerName;
        _customerPhoneController.text = customerPhone;

        if (productBrand.isNotEmpty) {
          _selectedBrand = productBrand.toLowerCase();
        }
        _productModelController.text = productName;
        _imeiController.text = imei;
        if (productPrice > 0) {
          _priceController.text = productPrice.toStringAsFixed(2);
        }

        if (billDate != null) {
          _saleDate = billDate;
        }
      });

      _showMessage('✓ Data autofilled from bill $billNumber', isError: false);
    } catch (e) {
      _showMessage('Error autofilling data: $e');
    }
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

  void _updatePrice() => setState(() {});

  double _calculateEffectivePrice() {
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;

    if (_selectedPurchaseMode == 'EMI') {
      return price;
    } else {
      final effectivePrice = price - discount;
      return effectivePrice < 0 ? 0.0 : effectivePrice;
    }
  }

  double _getSelectedPrice() {
    return double.tryParse(_priceController.text) ?? 0.0;
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

    if (_selectedPurchaseMode == 'EMI') {
      final remainingDownPayment =
          downPayment - exchange - customerCredit - discount;
      return remainingDownPayment.clamp(0.0, downPayment);
    } else {
      final remainingDownPayment = downPayment - exchange - customerCredit;
      return remainingDownPayment.clamp(0.0, downPayment);
    }
  }

  double _calculateBalanceReturned() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final exchange = double.tryParse(_exchangeController.text) ?? 0.0;
    final customerCredit =
        double.tryParse(_customerCreditController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;

    if (_selectedPurchaseMode == 'EMI') {
      final downPayment = double.tryParse(_downPaymentController.text) ?? 0.0;
      final totalAdjustments = exchange + customerCredit;
      final adjustedDownPayment = downPayment - discount;

      if (totalAdjustments > adjustedDownPayment) {
        return totalAdjustments - adjustedDownPayment;
      }
      return 0.0;
    } else {
      final effectivePrice = price - discount;
      final totalAdjustments = exchange + customerCredit;

      if (totalAdjustments > effectivePrice) {
        return totalAdjustments - effectivePrice;
      }
      return 0.0;
    }
  }

  void _onPurchaseModeSelected(String? mode) {
    setState(() {
      _selectedPurchaseMode = mode;
      _selectedPaymentBreakdown = PaymentBreakdown();
      _selectedFinanceType = null;
      _discountController.text = "0";
      _downPaymentController.text = ""; // REMOVED default "0"
      _upgradeController.text = "0";
      _supportController.text = "0";
      _disbursementAmountController.text = "0";
      _exchangeController.text = "0";
      _customerCreditController.text = "0";

      // EMI fields - NO DEFAULT VALUES
      _numberOfEmiController.text = "";
      _perMonthEmiController.text = "";
      _loanIdController.clear();
      _autoDebit = false;
      _insurance = false;

      // Gift fields
      _selectedGifts.clear();
      _isOtherGift = false;
      _otherGiftController.clear();
      _showGiftDropdown = false;

      // Reset payment breakdown controllers
      _rcCashController.text = "";
      _rcGpayController.text = "";
      _rcCardController.text = "";
      _rcCreditController.text = "";
      _dpCashController.text = "";
      _dpGpayController.text = "";
      _dpCardController.text = "";
      _dpCreditController.text = "";

      if (mode == 'Credit Card') {
        final effectivePrice = _calculateEffectivePrice();
        final exchange = double.tryParse(_exchangeController.text) ?? 0.0;
        final customerCredit =
            double.tryParse(_customerCreditController.text) ?? 0.0;
        _selectedPaymentBreakdown.card =
            effectivePrice - exchange - customerCredit;
      }
    });
  }

  void _uploadPhoneSale() async {
    if (_shopId == null || _shopName == null) {
      _showMessage('Shop information not found.');
      return;
    }

    if (!_withoutBillNumber &&
        (_selectedBillNumber == null || _selectedBillNumber!.isEmpty)) {
      _showMessage(
        'Please select a bill number or check "Without Bill Number"',
      );
      return;
    }

    if (_selectedBrand == null ||
        _productModelController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _selectedPurchaseMode == null ||
        _getSelectedPrice() == 0) {
      _showMessage('Please complete all required fields');
      return;
    }

    if (_customerNameController.text.isEmpty) {
      _showMessage('Please enter customer name');
      return;
    }

    final price = _getSelectedPrice();
    final effectivePrice = _calculateEffectivePrice();
    final exchange = double.tryParse(_exchangeController.text) ?? 0.0;
    final customerCredit =
        double.tryParse(_customerCreditController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final amountToPay = _calculateAmountToPay();
    final balanceReturned = _calculateBalanceReturned();

    if (_selectedPurchaseMode != 'EMI') {
      if (effectivePrice < 0) {
        _showMessage('Discount cannot be more than price');
        return;
      }
    }

    if (_selectedPurchaseMode == 'Ready Cash') {
      if (balanceReturned > 0) {
        _selectedPaymentBreakdown = PaymentBreakdown();
        _rcCashController.text = "";
        _rcGpayController.text = "";
        _rcCardController.text = "";
        _rcCreditController.text = "";
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
      if (downPayment <= 0) {
        _showMessage('Please enter valid down payment amount for EMI');
        return;
      }

      // Validate EMI fields
      if (_numberOfEmiController.text.isEmpty) {
        _showMessage('Please enter number of EMI');
        return;
      }
      final numberOfEmi = int.tryParse(_numberOfEmiController.text) ?? 0;
      if (numberOfEmi <= 0) {
        _showMessage('Please enter valid number of EMI');
        return;
      }

      if (_perMonthEmiController.text.isEmpty) {
        _showMessage('Please enter per month EMI amount');
        return;
      }
      final perMonthEmi = double.tryParse(_perMonthEmiController.text) ?? 0.0;
      if (perMonthEmi <= 0) {
        _showMessage('Please enter valid per month EMI amount');
        return;
      }

      final remainingDownPayment = _calculateRemainingDownPayment();

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

    final shouldUpload = await _showConfirmationDialog();
    if (!shouldUpload) return;

    setState(() => _isLoading = true);

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        _showMessage('User not authenticated');
        setState(() => _isLoading = false);
        return;
      }

      final upgradeValue = _isSamsungBrand
          ? (double.tryParse(_upgradeController.text) ?? 0.0)
          : 0.0;

      final supportValue = _isSamsungBrand
          ? (double.tryParse(_supportController.text) ?? 0.0)
          : 0.0;

      final salesData = {
        'userId': user.uid,
        'userEmail': user.email,
        'shopId': _shopId,
        'shopName': _shopName,
        'saleDate': _saleDate,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'brand': _selectedBrand ?? '',
        'productModel': _productModelController.text,
        'imei': _imeiController.text,
        'price': price,
        'discount': discount,
        'effectivePrice': effectivePrice,
        'purchaseMode': _selectedPurchaseMode ?? '',
        'paymentBreakdown': _selectedPaymentBreakdown.toMap(),
        'financeType': _selectedFinanceType,
        'upgrade': upgradeValue,
        'support': supportValue,
        'disbursementAmount':
            double.tryParse(_disbursementAmountController.text) ?? 0.0,
        'downPayment': _selectedPurchaseMode == 'EMI'
            ? double.tryParse(_downPaymentController.text) ?? 0.0
            : 0.0,
        // EMI fields
        'numberOfEmi': _selectedPurchaseMode == 'EMI'
            ? int.tryParse(_numberOfEmiController.text) ?? 0
            : 0,
        'perMonthEmi': _selectedPurchaseMode == 'EMI'
            ? double.tryParse(_perMonthEmiController.text) ?? 0.0
            : 0.0,
        // NEW: Loan fields
        'loanId': _selectedPurchaseMode == 'EMI'
            ? _loanIdController.text
            : null,
        'autoDebit': _selectedPurchaseMode == 'EMI' ? _autoDebit : false,
        'insurance': _selectedPurchaseMode == 'EMI' ? _insurance : false,
        // Enhanced gift fields
        'gifts': _finalGiftValues,
        'giftsCount': _selectedGifts.length,
        'giftsList': _selectedGifts.join(', '),
        'exchangeValue': exchange,
        'customerCredit': customerCredit,
        'amountToPay': amountToPay > 0 ? amountToPay : 0.0,
        'balanceReturnedToCustomer': balanceReturned,
        'customerName': _customerNameController.text,
        'customerPhone': _customerPhoneController.text,
        'billNumber': _withoutBillNumber ? null : _selectedBillNumber,
        'addedAt': DateTime.now(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('phoneSales').add(salesData);

      _showMessage('✓ Phone sale uploaded successfully!', isError: false);
      _resetForm();
    } catch (e) {
      _showMessage('Failed to upload sale: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Confirm Sale Upload',
              style: TextStyle(fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date: ${DateFormat('dd/MM/yyyy').format(_saleDate)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Shop: $_shopName',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Customer: ${_customerNameController.text.isNotEmpty ? _customerNameController.text : "N/A"}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  if (!_withoutBillNumber && _selectedBillNumber != null)
                    Text(
                      'Bill No: $_selectedBillNumber',
                      style: const TextStyle(fontSize: 13),
                    ),
                  if (_withoutBillNumber)
                    Text(
                      'Bill No: Without Bill Number',
                      style: TextStyle(fontSize: 13, color: _warningColor),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Brand: ${_selectedBrand?.toUpperCase() ?? "N/A"}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Model: ${_productModelController.text}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  if (_imeiController.text.isNotEmpty)
                    Text(
                      'IMEI: ${_imeiController.text}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Price: ₹${_getSelectedPrice().toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Purchase Mode: ${_selectedPurchaseMode ?? "N/A"}',
                    style: const TextStyle(fontSize: 13),
                  ),

                  if (_selectedPurchaseMode == 'EMI') ...[
                    const SizedBox(height: 6),
                    Text(
                      'Finance Company: $_selectedFinanceType',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Down Payment: ₹${double.tryParse(_downPaymentController.text)?.toStringAsFixed(2) ?? "0.00"}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Number of EMI: ${int.tryParse(_numberOfEmiController.text)?.toString() ?? "0"}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Per Month EMI: ₹${double.tryParse(_perMonthEmiController.text)?.toStringAsFixed(2) ?? "0.00"}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (_loanIdController.text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Loan ID: ${_loanIdController.text}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Auto Debit: ',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Icon(
                          _autoDebit ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: _autoDebit ? _successColor : _errorColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Insurance: ',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Icon(
                          _insurance ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: _insurance ? _successColor : _errorColor,
                        ),
                      ],
                    ),
                  ],

                  if (_selectedGifts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _giftColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.card_giftcard,
                                size: 14,
                                color: _giftColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Gifts Provided (${_selectedGifts.length}):',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _giftColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ..._selectedGifts
                              .map(
                                (gift) => Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    top: 2,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check,
                                        size: 12,
                                        color: _giftColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '• $gift',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _secondaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ],
                      ),
                    ),
                  ],

                  if (_isSamsungBrand && _selectedPurchaseMode == 'EMI') ...[
                    if ((double.tryParse(_upgradeController.text) ?? 0.0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Upgrade: ₹${(double.tryParse(_upgradeController.text) ?? 0.0).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 13, color: _purpleColor),
                        ),
                      ),
                    if ((double.tryParse(_supportController.text) ?? 0.0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Support: ₹${(double.tryParse(_supportController.text) ?? 0.0).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 13, color: _pinkColor),
                        ),
                      ),
                  ],

                  if (_calculateBalanceReturned() > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Balance to Return: ₹${_calculateBalanceReturned().toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 13, color: _returnColor),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel', style: TextStyle(fontSize: 13)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _resetForm() {
    setState(() {
      _selectedBrand = null;
      _selectedProductModel = null;
      _selectedPurchaseMode = null;
      _selectedPaymentBreakdown = PaymentBreakdown();
      _selectedFinanceType = null;
      _selectedBillNumber = null;
      _withoutBillNumber = false;
      _billSearchController.clear();
      _customerNameController.clear();
      _customerPhoneController.clear();
      _productModelController.clear();
      _imeiController.clear();
      _priceController.clear();
      _discountController.text = "0";
      _downPaymentController.text = "";
      _upgradeController.text = "0";
      _supportController.text = "0";
      _disbursementAmountController.text = "0";
      _exchangeController.text = "0";
      _customerCreditController.text = "0";

      // EMI fields - NO DEFAULT VALUES
      _numberOfEmiController.text = "";
      _perMonthEmiController.text = "";
      _loanIdController.clear();
      _autoDebit = false;
      _insurance = false;

      // Gift fields
      _selectedGifts.clear();
      _isOtherGift = false;
      _otherGiftController.clear();
      _showGiftDropdown = false;

      // Payment breakdown controllers
      _rcCashController.text = "";
      _rcGpayController.text = "";
      _rcCardController.text = "";
      _rcCreditController.text = "";
      _dpCashController.text = "";
      _dpGpayController.text = "";
      _dpCardController.text = "";
      _dpCreditController.text = "";
    });
  }

  Future<void> _getUserShopId() async {
    try {
      setState(() => _loadingShopInfo = true);

      final User? user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;

          setState(() {
            _shopId = userData['shopId']?.toString();
            _shopName = userData['shopName']?.toString();
            _loadingShopInfo = false;
          });

          if (_shopId != null) {
            _loadBillNumbers();
          }
        } else {
          setState(() => _loadingShopInfo = false);
        }
      } else {
        setState(() => _loadingShopInfo = false);
      }
    } catch (e) {
      setState(() => _loadingShopInfo = false);
      _showMessage('Error loading shop information: $e');
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: isError ? _errorColor : _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
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
      setState(() => _saleDate = picked);
    }
  }

  // ENHANCED: Multi-select Gift dropdown widget - FIXED with valid icons
  Widget _buildGiftSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: _giftColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _giftColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.card_giftcard, color: _giftColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Gifts Provided (Select Multiple)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _giftColor,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedGifts.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _giftColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedGifts.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Display selected gifts
              if (_selectedGifts.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedGifts.map((gift) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _giftColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 12, color: _giftColor),
                          const SizedBox(width: 4),
                          Text(
                            gift,
                            style: TextStyle(
                              fontSize: 11,
                              color: _giftColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _removeGift(gift),
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: _errorColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // Gift selection buttons - FIXED with valid Flutter icons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _giftOptions.map((gift) {
                    final giftName = gift['name'] as String;
                    final isSelected = _selectedGifts.contains(giftName);
                    final isOther = giftName == 'Other';

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              gift['icon'] as IconData,
                              size: 14,
                              color: isSelected ? Colors.white : _giftColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              giftName,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        onSelected: (selected) => _toggleGift(giftName),
                        backgroundColor: Colors.white,
                        selectedColor: _giftColor,
                        checkmarkColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Custom gift input
              if (_isOtherGift) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _otherGiftController,
                        decoration: InputDecoration(
                          hintText: 'Enter custom gift name',
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: Icon(
                            Icons.edit,
                            color: _giftColor,
                            size: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _giftColor.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _giftColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                        onSubmitted: (_) => _addCustomGift(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.add_circle, color: _giftColor, size: 28),
                      onPressed: _addCustomGift,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBillNumberField() {
    if (_shopId == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _warningColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _warningColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: _warningColor, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Shop information not available. Please wait.',
                style: TextStyle(fontSize: 11, color: _secondaryColor),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Select Bill Number',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _secondaryColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            if (_loadingBills)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: _primaryColor,
                ),
              ),
            const Spacer(),
            GestureDetector(
              onTap: _loadBillNumbers,
              child: Icon(Icons.refresh, size: 16, color: _primaryColor),
            ),
          ],
        ),
        const SizedBox(height: 4),

        Row(
          children: [
            Checkbox(
              value: _withoutBillNumber,
              onChanged: (value) {
                setState(() {
                  _withoutBillNumber = value ?? false;
                  if (_withoutBillNumber) {
                    _selectedBillNumber = null;
                    _billSearchController.clear();
                  }
                });
              },
              activeColor: _primaryColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 2),
            Text(
              'Without Bill Number',
              style: TextStyle(fontSize: 11, color: _secondaryColor),
            ),
            const SizedBox(width: 6),
            if (_withoutBillNumber)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: _warningColor.withOpacity(0.3)),
                ),
                child: Text(
                  'No bill required',
                  style: TextStyle(
                    fontSize: 9,
                    color: _warningColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        if (!_withoutBillNumber) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _secondaryColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: _primaryColor, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _billSearchController,
                              focusNode: _billSearchFocusNode,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: _selectedBillNumber != null
                                    ? 'Selected: $_selectedBillNumber'
                                    : 'Search or select bill number...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: _selectedBillNumber != null
                                      ? _billAutofillColor
                                      : _secondaryColor.withOpacity(0.5),
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: _selectedBillNumber != null
                                    ? _billAutofillColor
                                    : Colors.black,
                                fontWeight: _selectedBillNumber != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              onTap: () {
                                if (_selectedBillNumber != null) {
                                  setState(() {
                                    _selectedBillNumber = null;
                                    _billSearchController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          if (_selectedBillNumber != null)
                            IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 16,
                                color: _secondaryColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedBillNumber = null;
                                  _billSearchController.clear();
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (_billSearchController.text.isNotEmpty ||
                        _billSearchFocusNode.hasFocus)
                      Divider(
                        height: 0.5,
                        color: _secondaryColor.withOpacity(0.2),
                      ),

                    if ((_billSearchController.text.isNotEmpty ||
                            _billSearchFocusNode.hasFocus) &&
                        _filteredBillNumbers.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: Scrollbar(
                          thumbVisibility: true,
                          thickness: 3,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filteredBillNumbers.length,
                            itemBuilder: (context, index) {
                              final billNumber = _filteredBillNumbers[index];
                              return ListTile(
                                title: Text(
                                  billNumber,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                leading: Icon(
                                  Icons.receipt,
                                  color: _billAutofillColor,
                                  size: 18,
                                ),
                                trailing: _selectedBillNumber == billNumber
                                    ? Icon(
                                        Icons.check_circle,
                                        color: _primaryColor,
                                        size: 16,
                                      )
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedBillNumber = billNumber;
                                    _billSearchController.text = billNumber;
                                  });
                                  Future.microtask(() {
                                    _autofillFromBill(billNumber);
                                  });
                                  _billSearchFocusNode.unfocus();
                                },
                                tileColor: _selectedBillNumber == billNumber
                                    ? _veryLightGreenColor
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                visualDensity: VisualDensity.compact,
                              );
                            },
                          ),
                        ),
                      ),

                    if ((_billSearchController.text.isNotEmpty ||
                            _billSearchFocusNode.hasFocus) &&
                        _filteredBillNumbers.isEmpty &&
                        _billNumbers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 14,
                              color: _errorColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'No bills match "${_billSearchController.text}"',
                              style: TextStyle(
                                fontSize: 11,
                                color: _errorColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              if (_selectedBillNumber != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 2),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 11, color: _primaryColor),
                      const SizedBox(width: 3),
                      Text(
                        'Bill selected - data autofilled',
                        style: TextStyle(
                          fontSize: 10,
                          color: _primaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () async {
                          if (_selectedBillNumber != null) {
                            await _autofillFromBill(_selectedBillNumber);
                          }
                        },
                        child: Text(
                          '(Refresh)',
                          style: TextStyle(
                            fontSize: 9,
                            color: _primaryDarkColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_billNumbers.isEmpty && !_loadingBills)
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, size: 11, color: _warningColor),
                          const SizedBox(width: 3),
                          Text(
                            'No bills found for your shop "$_shopName".',
                            style: TextStyle(
                              fontSize: 10,
                              color: _warningColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Text(
                          'Create bills first or use "Without Bill Number" option.',
                          style: TextStyle(
                            fontSize: 9,
                            color: _secondaryColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  // NEW: Loan ID field
  Widget _buildLoanIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loan ID (Optional)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _loanColor,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _loanIdController,
          decoration: InputDecoration(
            hintText: 'Enter loan reference ID',
            hintStyle: const TextStyle(fontSize: 12),
            prefixIcon: Icon(Icons.numbers, color: _loanColor, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _secondaryColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _loanColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
          style: const TextStyle(fontSize: 13),
          keyboardType: TextInputType.text,
        ),
      ],
    );
  }

  // NEW: Auto Debit and Insurance selection
  Widget _buildLoanOptions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _loanColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _loanColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Settings',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _loanColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _autoDebit
                          ? _autoDebitColor
                          : _secondaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _autoDebit
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _autoDebit ? _autoDebitColor : _secondaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto Debit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _autoDebit
                                    ? _autoDebitColor
                                    : _secondaryColor,
                              ),
                            ),
                            Text(
                              'Enable auto-debit from bank',
                              style: TextStyle(
                                fontSize: 9,
                                color: _secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _autoDebit,
                        onChanged: (value) {
                          setState(() {
                            _autoDebit = value;
                          });
                        },
                        activeColor: _autoDebitColor,
                        activeTrackColor: _autoDebitColor.withOpacity(0.3),
                        inactiveThumbColor: _secondaryColor,
                        inactiveTrackColor: _secondaryColor.withOpacity(0.3),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _insurance
                          ? _insuranceColor
                          : _secondaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _insurance ? Icons.shield : Icons.shield_outlined,
                        color: _insurance ? _insuranceColor : _secondaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Insurance',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _insurance
                                    ? _insuranceColor
                                    : _secondaryColor,
                              ),
                            ),
                            Text(
                              'Device insurance',
                              style: TextStyle(
                                fontSize: 9,
                                color: _secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _insurance,
                        onChanged: (value) {
                          setState(() {
                            _insurance = value;
                          });
                        },
                        activeColor: _insuranceColor,
                        activeTrackColor: _insuranceColor.withOpacity(0.3),
                        inactiveThumbColor: _secondaryColor,
                        inactiveTrackColor: _secondaryColor.withOpacity(0.3),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneSaleForm() {
    final balanceReturned = _calculateBalanceReturned();
    final amountToPay = _calculateAmountToPay();
    final price = _getSelectedPrice();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBillNumberField(),
        const SizedBox(height: 16),
        _buildDatePicker(),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            _buildAdditionalField(
              label: 'Customer Name *',
              controller: _customerNameController,
              hint: 'Enter customer name',
              icon: Icons.person,
              iconColor: _primaryColor,
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 6),
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

        const SizedBox(height: 10),

        _buildDropdown(
          label: 'Select Brand *',
          value: _selectedBrand,
          items: _phoneBrands.map((brand) {
            return DropdownMenuItem<String>(
              value: brand,
              child: Text(
                brand.toUpperCase(),
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedBrand = value;
              if (!_isSamsungBrand) {
                _upgradeController.text = "0";
                _supportController.text = "0";
              }
            });
          },
          hint: 'Choose phone brand',
        ),
        const SizedBox(height: 10),

        if (_selectedBrand != null) ...[
          _buildAdditionalField(
            label: 'Product Model *',
            controller: _productModelController,
            hint: 'Enter phone model (e.g., iPhone 15 Pro, Galaxy S23)',
            icon: Icons.phone_android,
            iconColor: _primaryColor,
            keyboardType: TextInputType.text,
            onChanged: (value) {
              setState(() {
                _selectedProductModel = value;
              });
            },
          ),
          const SizedBox(height: 10),
        ],

        if (_selectedProductModel != null &&
            _selectedProductModel!.isNotEmpty) ...[
          _buildAdditionalField(
            label: 'IMEI Number (Optional)',
            controller: _imeiController,
            hint: 'Enter 15-digit IMEI number',
            icon: Icons.fingerprint,
            iconColor: _purpleColor,
            keyboardType: TextInputType.number,
            onChanged: (value) {
              if (value.length > 15) {
                _imeiController.text = value.substring(0, 15);
                _imeiController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _imeiController.text.length),
                );
              }
            },
          ),
          const SizedBox(height: 10),
        ],

        if (_selectedProductModel != null &&
            _selectedProductModel!.isNotEmpty) ...[
          _buildAdditionalField(
            label: 'Price *',
            controller: _priceController,
            hint: 'Enter phone price',
            icon: Icons.attach_money,
            iconColor: _primaryColor,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 10),
        ],

        if (price > 0) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _veryLightGreenColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Price',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _secondaryColor,
                  ),
                ),
                Text(
                  '₹${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (price > 0) ...[
          _buildDropdown(
            label: 'Purchase Mode *',
            value: _selectedPurchaseMode,
            items: _purchaseModes.map((mode) {
              return DropdownMenuItem<String>(
                value: mode,
                child: Text(mode, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
            onChanged: _onPurchaseModeSelected,
            hint: 'Select purchase mode',
          ),
          const SizedBox(height: 10),
        ],

        if (balanceReturned > 0)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _returnColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _returnColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: _returnColor, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Balance to be Returned to Customer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _returnColor,
                        ),
                      ),
                      Text(
                        '₹${balanceReturned.toStringAsFixed(2)} will be returned to customer',
                        style: TextStyle(fontSize: 11, color: _secondaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (_selectedPurchaseMode == 'Ready Cash' && balanceReturned == 0) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Breakdown *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentField(
                      label: 'Cash',
                      controller: _rcCashController,
                      onChanged: (value) {},
                      hint: 'Cash amount',
                      icon: Icons.money,
                      iconColor: const Color(0xFF34A853),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildPaymentField(
                      label: 'GPay',
                      controller: _rcGpayController,
                      onChanged: (value) {},
                      hint: 'GPay amount',
                      icon: Icons.phone_android,
                      iconColor: const Color(0xFF4285F4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentField(
                      label: 'Card',
                      controller: _rcCardController,
                      onChanged: (value) {},
                      hint: 'Card amount',
                      icon: Icons.credit_card,
                      iconColor: const Color(0xFFFBBC05),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildPaymentField(
                      label: 'Credit',
                      controller: _rcCreditController,
                      onChanged: (value) {},
                      hint: 'Credit amount',
                      icon: Icons.credit_score,
                      iconColor: _orangeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildPaymentValidationForReadyCash(),
            ],
          ),
          const SizedBox(height: 10),
        ],

        if (_selectedPurchaseMode == 'Credit Card') ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBC05).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFFFBBC05).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.credit_card,
                      color: const Color(0xFFFBBC05),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credit Card Payment',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            balanceReturned > 0
                                ? 'No payment needed - balance will be returned'
                                : 'Adjusted for exchange and customer credit',
                            style: TextStyle(
                              fontSize: 11,
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
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFBBC05),
                          ),
                        ),
                        Text(
                          'Effective Price',
                          style: TextStyle(fontSize: 9, color: _secondaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  balanceReturned > 0
                      ? 'No Card Payment Required'
                      : 'Card Amount: ₹${_selectedPaymentBreakdown.card.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFBBC05),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (_selectedPurchaseMode == 'EMI') ...[
          _buildDropdown(
            label: 'Finance Company *',
            value: _selectedFinanceType,
            items: _financeCompaniesList.map((company) {
              return DropdownMenuItem<String>(
                value: company,
                child: Text(company, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedFinanceType = value),
            hint: 'Select finance company',
          ),
          const SizedBox(height: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Down Payment Amount *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _secondaryColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _downPaymentController,
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Enter down payment amount',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: Icon(
                    Icons.attach_money,
                    color: _primaryColor,
                    size: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _secondaryColor.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _primaryColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EMI Details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 10),

              _buildAdditionalField(
                label: 'Number of EMI *',
                controller: _numberOfEmiController,
                hint: 'Enter number of EMI (e.g., 3, 6, 9, 12)',
                icon: Icons.format_list_numbered,
                iconColor: _purpleColor,
                keyboardType: TextInputType.number,
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 10),

              _buildAdditionalField(
                label: 'Per Month EMI (Installment Amount) *',
                controller: _perMonthEmiController,
                hint: 'Enter amount per EMI installment',
                icon: Icons.install_mobile,
                iconColor: _tealColor,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 10),

              // NEW: Loan ID field
              _buildLoanIdField(),
              const SizedBox(height: 10),

              // NEW: Auto Debit and Insurance options
              _buildLoanOptions(),
              const SizedBox(height: 10),
            ],
          ),
          const SizedBox(height: 10),
        ],

        if (_selectedPurchaseMode != null && price > 0) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Adjustments',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 10),

              _buildAdditionalField(
                label: 'Exchange Value',
                controller: _exchangeController,
                hint: 'Enter exchange value',
                icon: Icons.swap_horiz,
                iconColor: _tealColor,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() => _updateCreditCardPayment());
                },
              ),
              const SizedBox(height: 10),

              _buildAdditionalField(
                label: 'Customer Credit (Pay Later)',
                controller: _customerCreditController,
                hint: 'Enter credit amount',
                icon: Icons.credit_score,
                iconColor: _orangeColor,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() => _updateCreditCardPayment());
                },
              ),
              const SizedBox(height: 10),

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
                  setState(() => _updateCreditCardPayment());
                },
              ),
              const SizedBox(height: 10),

              // ENHANCED: Multi-select Gift section
              _buildGiftSelection(),
              const SizedBox(height: 10),

              const SizedBox(height: 10),
              _buildPaymentSummary(),
              const SizedBox(height: 10),

              if (_selectedPurchaseMode == 'EMI') ...[
                if (_shouldShowDownPaymentBreakdown())
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remaining Down Payment Breakdown *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _secondaryColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Expanded(
                            child: _buildPaymentField(
                              label: 'Cash',
                              controller: _dpCashController,
                              onChanged: (value) {},
                              hint: 'Cash amount',
                              icon: Icons.money,
                              iconColor: const Color(0xFF34A853),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildPaymentField(
                              label: 'GPay',
                              controller: _dpGpayController,
                              onChanged: (value) {},
                              hint: 'GPay amount',
                              icon: Icons.phone_android,
                              iconColor: const Color(0xFF4285F4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPaymentField(
                              label: 'Card',
                              controller: _dpCardController,
                              onChanged: (value) {},
                              hint: 'Card amount',
                              icon: Icons.credit_card,
                              iconColor: const Color(0xFFFBBC05),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildPaymentField(
                              label: 'Credit',
                              controller: _dpCreditController,
                              onChanged: (value) {},
                              hint: 'Credit amount',
                              icon: Icons.credit_score,
                              iconColor: _orangeColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildPaymentValidationForEMI(),
                    ],
                  ),

                if (_isSamsungBrand) ...[
                  const SizedBox(height: 10),
                  _buildAdditionalField(
                    label: 'Upgrade (Samsung Only)',
                    controller: _upgradeController,
                    hint: 'Enter upgrade amount (default: 0)',
                    icon: Icons.upgrade,
                    iconColor: _purpleColor,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildAdditionalField(
                    label: 'Support (Samsung Only)',
                    controller: _supportController,
                    hint: 'Enter support amount (default: 0)',
                    icon: Icons.support_agent,
                    iconColor: _pinkColor,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                _buildAdditionalField(
                  label: 'Disbursement Amount',
                  controller: _disbursementAmountController,
                  hint: 'Enter disbursement amount (default: 0)',
                  icon: Icons.monetization_on,
                  iconColor: _primaryColor,
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

    return remainingDownPayment > 0 && balanceReturned == 0;
  }

  Widget _buildPaymentSummary() {
    final price = _getSelectedPrice();
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final effectivePrice = _calculateEffectivePrice();
    final exchange = double.tryParse(_exchangeController.text) ?? 0.0;
    final customerCredit =
        double.tryParse(_customerCreditController.text) ?? 0.0;
    final amountToPay = _calculateAmountToPay();
    final balanceReturned = _calculateBalanceReturned();

    final downPayment = double.tryParse(_downPaymentController.text) ?? 0.0;
    final remainingDownPayment = _calculateRemainingDownPayment();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _veryLightGreenColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Original Price:',
                style: TextStyle(fontSize: 11, color: _secondaryColor),
              ),
              Text(
                '₹${price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _secondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),

          if (discount > 0)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedPurchaseMode == 'EMI'
                          ? 'Discount (from Down Payment):'
                          : 'Discount (from Price):',
                      style: TextStyle(fontSize: 11, color: _discountColor),
                    ),
                    Text(
                      '-₹${discount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _discountColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
              ],
            ),

          if (_selectedPurchaseMode != 'EMI') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Effective Price:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primaryDarkColor,
                  ),
                ),
                Text(
                  '₹${effectivePrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _primaryDarkColor,
                  ),
                ),
              ],
            ),
            Divider(height: 12, color: _secondaryColor.withOpacity(0.2)),
          ],

          if (_selectedPurchaseMode == 'EMI' && downPayment > 0)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Down Payment:',
                      style: TextStyle(fontSize: 11, color: _secondaryColor),
                    ),
                    Text(
                      '₹${downPayment.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _secondaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (discount > 0)
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discount Applied:',
                            style: TextStyle(
                              fontSize: 11,
                              color: _discountColor,
                            ),
                          ),
                          Text(
                            '-₹${discount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _discountColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                    ],
                  ),
                if (exchange > 0 || customerCredit > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        if (exchange > 0)
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Exchange Applied:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _tealColor,
                                    ),
                                  ),
                                  Text(
                                    '-₹${exchange.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _tealColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                            ],
                          ),
                        if (customerCredit > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Customer Credit Applied:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _orangeColor,
                                ),
                              ),
                              Text(
                                '-₹${customerCredit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
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
                  Column(
                    children: [
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Remaining Down Payment:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _primaryColor,
                            ),
                          ),
                          Text(
                            '₹${remainingDownPayment.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                // EMI details
                if ((int.tryParse(_numberOfEmiController.text) ?? 0) > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Number of EMI:',
                        style: TextStyle(fontSize: 11, color: _purpleColor),
                      ),
                      Text(
                        '${int.tryParse(_numberOfEmiController.text) ?? 0}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _purpleColor,
                        ),
                      ),
                    ],
                  ),
                if ((double.tryParse(_perMonthEmiController.text) ?? 0.0) > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Per Month EMI:',
                        style: TextStyle(fontSize: 11, color: _tealColor),
                      ),
                      Text(
                        '₹${(double.tryParse(_perMonthEmiController.text) ?? 0.0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _tealColor,
                        ),
                      ),
                    ],
                  ),

                // Loan details
                if (_loanIdController.text.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Loan ID:',
                        style: TextStyle(fontSize: 11, color: _loanColor),
                      ),
                      Expanded(
                        child: Text(
                          _loanIdController.text,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _loanColor,
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                if (_autoDebit || _insurance)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        if (_autoDebit)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _autoDebitColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 10,
                                  color: _autoDebitColor,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Auto Debit',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: _autoDebitColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_insurance)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _insuranceColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield,
                                  size: 10,
                                  color: _insuranceColor,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Insurance',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: _insuranceColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                if (_isSamsungBrand && _selectedPurchaseMode == 'EMI')
                  Column(
                    children: [
                      const SizedBox(height: 3),
                      if ((double.tryParse(_upgradeController.text) ?? 0.0) > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Upgrade:',
                              style: TextStyle(
                                fontSize: 11,
                                color: _purpleColor,
                              ),
                            ),
                            Text(
                              '₹${(double.tryParse(_upgradeController.text) ?? 0.0).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _purpleColor,
                              ),
                            ),
                          ],
                        ),
                      if ((double.tryParse(_supportController.text) ?? 0.0) > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Support:',
                              style: TextStyle(fontSize: 11, color: _pinkColor),
                            ),
                            Text(
                              '₹${(double.tryParse(_supportController.text) ?? 0.0).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _pinkColor,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                Divider(height: 12, color: _secondaryColor.withOpacity(0.2)),
              ],
            ),

          if (_selectedPurchaseMode != 'EMI')
            Column(
              children: [
                if (exchange > 0 || customerCredit > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        if (exchange > 0)
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Exchange:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _tealColor,
                                    ),
                                  ),
                                  Text(
                                    '-₹${exchange.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _tealColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                            ],
                          ),
                        if (customerCredit > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Customer Credit:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _orangeColor,
                                ),
                              ),
                              Text(
                                '-₹${customerCredit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _orangeColor,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                Divider(height: 12, color: _secondaryColor.withOpacity(0.2)),
              ],
            ),

          // Gift summary
          if (_selectedGifts.isNotEmpty)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _giftColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.card_giftcard, size: 12, color: _giftColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gifts (${_selectedGifts.length}):',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _giftColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            ..._selectedGifts
                                .map(
                                  (gift) => Padding(
                                    padding: const EdgeInsets.only(
                                      left: 8,
                                      top: 1,
                                    ),
                                    child: Text(
                                      '• $gift',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _secondaryColor,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 12, color: _secondaryColor.withOpacity(0.2)),
              ],
            ),

          if (balanceReturned > 0)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.money_off, size: 12, color: _returnColor),
                        const SizedBox(width: 3),
                        Text(
                          'Balance Returned to Customer:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _returnColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹${balanceReturned.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _returnColor,
                      ),
                    ),
                  ],
                ),
                Divider(height: 12, color: _secondaryColor.withOpacity(0.2)),
              ],
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedPurchaseMode == 'EMI'
                    ? 'Amount Financed (EMI):'
                    : 'Amount to Pay:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _primaryDarkColor,
                ),
              ),
              Text(
                '₹${amountToPay > 0 ? amountToPay.toStringAsFixed(2) : '0.00'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _primaryDarkColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          if (_selectedPurchaseMode == 'EMI')
            Text(
              'Note: Discount is deducted from down payment for EMI',
              style: TextStyle(
                fontSize: 9,
                color: _secondaryColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (_isSamsungBrand && _selectedPurchaseMode == 'EMI')
            Text(
              'Note: Upgrade and Support fields available for Samsung only',
              style: TextStyle(
                fontSize: 9,
                color: _purpleColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (balanceReturned > 0)
            Text(
              'Note: Customer will receive ₹${balanceReturned.toStringAsFixed(2)} as balance',
              style: TextStyle(
                fontSize: 9,
                color: _returnColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (_selectedGifts.isNotEmpty)
            Text(
              'Note: ${_selectedGifts.length} gift(s) provided to customer',
              style: TextStyle(
                fontSize: 9,
                color: _giftColor,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isValid ? _veryLightGreenColor : _errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isValid
              ? _primaryColor.withOpacity(0.3)
              : _errorColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.error,
            size: 14,
            color: isValid ? _primaryColor : _errorColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balanceReturned > 0
                      ? 'No Payment Required - Balance will be Returned'
                      : 'Payment Total: ₹${paymentTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isValid ? _primaryColor : _errorColor,
                  ),
                ),
                if (!isValid && balanceReturned == 0)
                  Text(
                    'Should be ₹${targetAmount.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 10, color: _errorColor),
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
                    style: TextStyle(fontSize: 9, color: _secondaryColor),
                  ),
                if (_selectedPaymentBreakdown.gpay > 0)
                  Text(
                    'GPay: ₹${_selectedPaymentBreakdown.gpay.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 9, color: _secondaryColor),
                  ),
                if (_selectedPaymentBreakdown.card > 0)
                  Text(
                    'Card: ₹${_selectedPaymentBreakdown.card.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 9, color: _secondaryColor),
                  ),
                if (_selectedPaymentBreakdown.credit > 0)
                  Text(
                    'Credit: ₹${_selectedPaymentBreakdown.credit.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 9, color: _secondaryColor),
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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isValid ? _veryLightGreenColor : _errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isValid
              ? _primaryColor.withOpacity(0.3)
              : _errorColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.error,
            size: 14,
            color: isValid ? _primaryColor : _errorColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balanceReturned > 0
                      ? 'Balance will be returned to customer'
                      : 'Remaining Down Payment: ₹${paymentTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isValid ? _primaryColor : _errorColor,
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
                    style: TextStyle(fontSize: 10, color: _errorColor),
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
                    style: TextStyle(fontSize: 9, color: _secondaryColor),
                  ),
                if (_selectedPaymentBreakdown.gpay > 0)
                  Text(
                    'GPay: ₹${_selectedPaymentBreakdown.gpay.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 9, color: _secondaryColor),
                  ),
                if (_selectedPaymentBreakdown.card > 0)
                  Text(
                    'Card: ₹${_selectedPaymentBreakdown.card.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 9, color: _secondaryColor),
                  ),
                if (_selectedPaymentBreakdown.credit > 0)
                  Text(
                    'Credit: ₹${_selectedPaymentBreakdown.credit.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 9, color: _secondaryColor),
                  ),
              ],
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
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12),
            prefixIcon: Icon(icon, color: iconColor, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _secondaryColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: iconColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
          style: const TextStyle(fontSize: 13),
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
        Text(label, style: TextStyle(fontSize: 11, color: _secondaryColor)),
        const SizedBox(height: 3),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11),
            prefixIcon: Icon(icon, size: 16, color: iconColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _secondaryColor.withOpacity(0.3)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 6,
            ),
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
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
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _secondaryColor.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            items: items,
            onChanged: onChanged,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            icon: Icon(Icons.arrow_drop_down, color: _primaryColor, size: 18),
            isExpanded: true,
            style: const TextStyle(fontSize: 12, color: Colors.black),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _primaryDarkColor],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.phone_iphone, size: 28, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            'Phone Sales Upload',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _withoutBillNumber
                ? 'Uploading without bill number'
                : 'Select bill to autofill data',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopInfo() {
    if (_shopId == null || _shopName == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _secondaryColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.store, color: _secondaryColor, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: _loadingShopInfo
                  ? Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Loading shop information...',
                          style: TextStyle(
                            fontSize: 11,
                            color: _secondaryColor,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shop information not available',
                          style: TextStyle(
                            fontSize: 11,
                            color: _secondaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        GestureDetector(
                          onTap: _getUserShopId,
                          child: Text(
                            'Tap to refresh',
                            style: TextStyle(
                              fontSize: 10,
                              color: _primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _veryLightGreenColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _primaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.store, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Active Shop",
                  style: TextStyle(
                    fontSize: 9,
                    color: _secondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _shopName!,
                  style: TextStyle(
                    fontSize: 11,
                    color: _primaryDarkColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_shopId != null)
                  Text(
                    'ID: ${_shopId!.substring(0, min(8, _shopId!.length))}...',
                    style: TextStyle(fontSize: 8, color: _secondaryColor),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _getUserShopId,
            child: Icon(Icons.refresh, size: 14, color: _primaryColor),
          ),
        ],
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sale Date',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _secondaryColor,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: _secondaryColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: _primaryColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_saleDate.day}/${_saleDate.month}/${_saleDate.year}',
                  style: TextStyle(fontSize: 12, color: _secondaryColor),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down, color: _primaryColor, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton() {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        gradient: (_isLoading || _shopId == null)
            ? null
            : LinearGradient(
                colors: [_primaryColor, _primaryDarkColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        borderRadius: BorderRadius.circular(10),
        color: (_isLoading || _shopId == null)
            ? _secondaryColor.withOpacity(0.3)
            : null,
      ),
      child: ElevatedButton(
        onPressed: (_isLoading || _shopId == null) ? null : _uploadPhoneSale,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.zero,
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 1.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Uploading...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Text(
                _shopId == null ? 'Waiting for Shop Info' : 'Upload Phone Sale',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 0.9),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Phone Sales Upload',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loadBillNumbers,
              tooltip: 'Refresh bill list',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildShopInfo(),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildPhoneSaleForm(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildUploadButton(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _discountController.dispose();
    _downPaymentController.dispose();
    _upgradeController.dispose();
    _supportController.dispose();
    _disbursementAmountController.dispose();
    _exchangeController.dispose();
    _customerCreditController.dispose();
    _productModelController.dispose();
    _priceController.dispose();
    _imeiController.dispose();
    _rcCashController.dispose();
    _rcGpayController.dispose();
    _rcCardController.dispose();
    _rcCreditController.dispose();
    _dpCashController.dispose();
    _dpGpayController.dispose();
    _dpCardController.dispose();
    _dpCreditController.dispose();
    _billSearchController.dispose();
    _billSearchFocusNode.dispose();
    _numberOfEmiController.dispose();
    _perMonthEmiController.dispose();
    _loanIdController.dispose();
    _otherGiftController.dispose();
    super.dispose();
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
