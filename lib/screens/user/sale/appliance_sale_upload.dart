import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ApplianceSaleUpload extends StatefulWidget {
  const ApplianceSaleUpload({super.key});

  @override
  State<ApplianceSaleUpload> createState() => _ApplianceSaleUploadState();
}

class _ApplianceSaleUploadState extends State<ApplianceSaleUpload> {
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

  // Gift selection states
  List<String> _selectedGifts = [];
  bool _isOtherGift = false;
  final TextEditingController _otherGiftController = TextEditingController();
  bool _showGiftDropdown = false;

  // EMI Loan fields
  final TextEditingController _loanIdController = TextEditingController();
  bool _autoDebit = false;
  bool _insurance = false;

  // Share functionality fields
  Map<String, dynamic>? _lastSaleData;
  String? _shopMobileNumber;
  String? _shopWhatsAppNumber;
  String? _shopAddress;
  String? _shopInstagram;

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

  // EMI Controllers
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
  final List<String> _applianceBrands = [
    'VOLTAS',
    'Samsung',
    'LG',
    'Whirlpool',
    'Godrej',
    'Havells',
    'Panasonic',
    'Hitachi',
    'Daikin',
    'Blue Star',
    'IFB',
    'Bosch',
    'Siemens',
    'Electrolux',
    'Kenstar',
    'Bajaj',
    'Butterfly',
    'Preethi',
    'Usha',
    'Other',
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
    'MI Finance',
    'First credit private Finance',
    'Chola Murugappa',
    'Other',
  ];

  // Gift options list
  final List<Map<String, dynamic>> _giftOptions = [
    {'name': 'screenGuard', 'icon': Icons.screen_lock_portrait},
    {'name': 'mobile cover', 'icon': Icons.phone_iphone},
    {'name': 'airpod', 'icon': Icons.headphones},
    {'name': 'neckband', 'icon': Icons.headset},
    {'name': 'headset', 'icon': Icons.headset_mic},
    {'name': 'adapter', 'icon': Icons.usb_off},
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

  // Bill numbers list - only appliance bills
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
  final Color _whatsappColor = const Color(0xFF25D366);
  final Color _applianceColor = const Color(0xFF0EA5E9);

  final Color _veryLightGreenColor = const Color(0xFFF0FDF4);
  final Color _softGreenColor = const Color(0xFFDCFCE7);

  @override
  void initState() {
    super.initState();
    _getUserShopId();

    // Set default zero values
    _discountController.text = "0";
    _exchangeController.text = "0";
    _customerCreditController.text = "0";
    _upgradeController.text = "0";
    _supportController.text = "0";
    _downPaymentController.text = "";
    _disbursementAmountController.text = "";

    // Set default zero for payment breakdown controllers
    _rcCashController.text = "0";
    _rcGpayController.text = "0";
    _rcCardController.text = "0";
    _rcCreditController.text = "0";
    _dpCashController.text = "0";
    _dpGpayController.text = "0";
    _dpCardController.text = "0";
    _dpCreditController.text = "0";

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

  // Check if form is autofilled from bill (read-only mode for certain fields)
  bool get _isAutofilledFromBill =>
      _selectedBillNumber != null && !_withoutBillNumber;

  // Check if a field should be editable
  bool _isFieldEditable(String fieldName) {
    if (!_isAutofilledFromBill) return true;

    final editableFields = [
      'exchange',
      'customerCredit',
      'discount',
      'gifts',
      'downPayment',
      'numberOfEmi',
      'perMonthEmi',
      'disbursementAmount',
      'loanId',
      'autoDebit',
      'insurance',
      'upgrade',
      'support',
      'cash',
      'gpay',
      'card',
      'credit',
      'dpCash',
      'dpGpay',
      'dpCard',
      'dpCredit',
      'customerPhone',
    ];

    return editableFields.contains(fieldName);
  }

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

  String get _formattedGiftList {
    if (_selectedGifts.isEmpty) return '';
    final gifts = _selectedGifts.where((g) => g.isNotEmpty).toList();
    if (gifts.isEmpty) return '';
    if (gifts.length == 1) return gifts.first;
    return '${gifts.length} items: ${gifts.join(', ')}';
  }

  List<String>? get _finalGiftValues {
    if (_selectedGifts.isEmpty) return null;
    return _selectedGifts.where((g) => g.isNotEmpty).toList();
  }

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

  void _addCustomGift() {
    if (_otherGiftController.text.trim().isNotEmpty) {
      setState(() {
        _selectedGifts.add(_otherGiftController.text.trim());
        _otherGiftController.clear();
        _isOtherGift = false;
      });
    }
  }

  void _removeGift(String gift) {
    setState(() {
      _selectedGifts.remove(gift);
    });
  }

  // Load ONLY appliance bills (billType == "appliances")
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

      debugPrint('Loading appliance bills for shop: $_shopId');

      // Get ALL bills for the shop first
      final billsSnapshot = await _firestore
          .collection('bills')
          .where('shopId', isEqualTo: _shopId)
          .get();

      debugPrint('Found ${billsSnapshot.docs.length} total bills');

      final billNumbers = <String>[];
      final billDataMap = <String, Map<String, dynamic>>{};

      // Filter for appliance bills (billType == "appliances")
      for (var doc in billsSnapshot.docs) {
        final billData = doc.data();
        final billType = billData['billType']?.toString() ?? '';

        // Only include appliance bills
        if (billType == 'appliances') {
          final billNumber = billData['billNumber']?.toString();
          if (billNumber != null && billNumber.isNotEmpty) {
            billNumbers.add(billNumber);
            billDataMap[billNumber] = billData;
            debugPrint('Found appliance bill: $billNumber - Type: $billType');
          }
        }
      }

      // Sort bills by billDate (newest first)
      billNumbers.sort((a, b) {
        final aData = billDataMap[a];
        final bData = billDataMap[b];
        final aDate =
            (aData?['billDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final bDate =
            (bData?['billDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      setState(() {
        _billNumbers = billNumbers;
        _billDataMap = billDataMap;
        _loadingBills = false;
      });

      if (billNumbers.isEmpty) {
        _showMessage('No appliance bills found for your shop', isError: false);
      } else {
        debugPrint('Loaded ${billNumbers.length} appliance bills successfully');
      }
    } catch (e) {
      debugPrint('Error loading appliance bills: $e');
      _showMessage('Error loading bills: $e');
      setState(() => _loadingBills = false);
    }
  }

  void _clearFormData() {
    setState(() {
      _customerNameController.clear();
      _customerPhoneController.clear();
      _imeiController.clear();
      _selectedBrand = null;
      _productModelController.clear();
      _selectedProductModel = null;
      _priceController.clear();
      _selectedPurchaseMode = null;
      _selectedFinanceType = null;
      _selectedPaymentBreakdown = PaymentBreakdown();

      _discountController.text = "0";
      _exchangeController.text = "0";
      _customerCreditController.text = "0";
      _upgradeController.text = "0";
      _supportController.text = "0";
      _downPaymentController.text = "";
      _disbursementAmountController.text = "";

      _numberOfEmiController.text = "";
      _perMonthEmiController.text = "";
      _loanIdController.clear();
      _autoDebit = false;
      _insurance = false;

      _selectedGifts.clear();
      _isOtherGift = false;
      _otherGiftController.clear();

      _rcCashController.text = "0";
      _rcGpayController.text = "0";
      _rcCardController.text = "0";
      _rcCreditController.text = "0";
      _dpCashController.text = "0";
      _dpGpayController.text = "0";
      _dpCardController.text = "0";
      _dpCreditController.text = "0";
    });
  }

  // Autofill from appliance bill
  // Autofill from appliance bill - FIXED
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
      debugPrint('=== APPLIANCE BILL DATA STRUCTURE ===');
      debugPrint('All keys in bill: ${billData.keys.join(', ')}');

      // Debug: Print the appliance fields
      debugPrint('billType: ${billData['billType']}');
      debugPrint('applianceBrand: ${billData['applianceBrand']}');
      debugPrint('applianceProductName: ${billData['applianceProductName']}');
      debugPrint('applianceModelId: ${billData['applianceModelId']}');
      debugPrint('customerName: ${billData['customerName']}');
      debugPrint('customerMobile: ${billData['customerMobile']}');
      debugPrint('totalAmount: ${billData['totalAmount']}');
      debugPrint('purchaseMode: ${billData['purchaseMode']}');

      // Clear ALL existing data first
      _clearFormData();

      // Extract customer details
      final customerName = billData['customerName']?.toString() ?? '';
      final customerPhone = billData['customerMobile']?.toString() ?? '';

      // Get appliance details - DIRECTLY from billData
      String applianceBrand = billData['applianceBrand']?.toString() ?? '';
      String applianceProductName =
          billData['applianceProductName']?.toString() ?? '';
      String applianceModelId = billData['applianceModelId']?.toString() ?? '';

      // Get product details from product map if exists
      final productData = billData['product'] as Map<String, dynamic>?;

      // Get product name - priority: applianceProductName > productData.productName > productName
      String productName = applianceProductName;
      if (productName.isEmpty && productData != null) {
        productName = productData['productName']?.toString() ?? '';
      }
      if (productName.isEmpty) {
        productName = billData['productName']?.toString() ?? '';
      }

      // Get price - priority: totalAmount > productData.price
      double productPrice = 0.0;
      if (billData['totalAmount'] != null) {
        productPrice = (billData['totalAmount'] as num).toDouble();
      } else if (productData != null && productData['price'] != null) {
        productPrice = (productData['price'] as num).toDouble();
      }

      // Get brand - priority: applianceBrand > productData.brand > productBrand
      String brand = applianceBrand;
      if (brand.isEmpty && productData != null) {
        brand = productData['brand']?.toString() ?? '';
      }
      if (brand.isEmpty) {
        brand = billData['productBrand']?.toString() ?? '';
      }

      // Get purchase mode and finance type
      String? purchaseMode = billData['purchaseMode']?.toString();
      String? financeType = billData['financeType']?.toString();

      // Get bill date
      Timestamp? billDateTimestamp = billData['billDate'];
      DateTime? billDate = billDateTimestamp?.toDate();

      debugPrint('=== FINAL EXTRACTED VALUES ===');
      debugPrint('Customer Name: "$customerName"');
      debugPrint('Customer Phone: "$customerPhone"');
      debugPrint('Appliance Brand: "$brand"');
      debugPrint('Product Name: "$productName"');
      debugPrint('Price: $productPrice');
      debugPrint('Model ID: "$applianceModelId"');
      debugPrint('Purchase Mode: "$purchaseMode"');
      debugPrint('Finance Type: "$financeType"');

      // Set the values in the form
      setState(() {
        // Set customer details
        _customerNameController.text = customerName;
        _customerPhoneController.text = customerPhone;

        // Set product details
        _productModelController.text = productName;
        _selectedProductModel = productName;

        // Set brand
        if (brand.isNotEmpty) {
          _selectedBrand = brand.toUpperCase();
          debugPrint('Brand set to: ${_selectedBrand}');
        } else {
          _selectedBrand = null;
        }

        // Set price
        if (productPrice > 0) {
          _priceController.text = productPrice.toStringAsFixed(2);
          debugPrint('Price set to: ${_priceController.text}');
        } else {
          _priceController.clear();
        }

        // Set IMEI/Serial
        if (applianceModelId.isNotEmpty) {
          _imeiController.text = applianceModelId;
          debugPrint('Model ID set to: $applianceModelId');
        }

        // Set purchase mode
        if (purchaseMode != null && purchaseMode.isNotEmpty) {
          String normalizedMode = purchaseMode;
          final lowerMode = purchaseMode.toLowerCase();

          if (lowerMode.contains('cash') && !lowerMode.contains('credit')) {
            normalizedMode = 'Ready Cash';
          } else if (lowerMode.contains('credit') &&
              !lowerMode.contains('emi')) {
            normalizedMode = 'Credit Card';
          } else if (lowerMode.contains('emi')) {
            normalizedMode = 'EMI';
          }

          if (_purchaseModes.contains(normalizedMode)) {
            _selectedPurchaseMode = normalizedMode;
            _selectedPaymentBreakdown = PaymentBreakdown();
            debugPrint('Purchase mode set to: $normalizedMode');
          } else {
            _selectedPurchaseMode = null;
          }
        } else {
          _selectedPurchaseMode = null;
        }

        // Set finance type
        if (financeType != null && financeType.isNotEmpty) {
          if (_financeCompaniesList.contains(financeType)) {
            _selectedFinanceType = financeType;
          } else {
            final matchedFinance = _financeCompaniesList.firstWhere(
              (company) =>
                  company.toLowerCase().contains(financeType.toLowerCase()),
              orElse: () => '',
            );
            _selectedFinanceType = matchedFinance.isNotEmpty
                ? matchedFinance
                : financeType;
          }
          debugPrint('Finance type set to: ${_selectedFinanceType}');
        } else {
          _selectedFinanceType = null;
        }

        // Set sale date
        if (billDate != null) {
          _saleDate = billDate;
          debugPrint('Sale date set to: $billDate');
        }
      });

      // Show success message
      String autofillMessage =
          '✓ Data autofilled from appliance bill $billNumber';
      List<String> missingFields = [];

      if (brand.isEmpty) missingFields.add('Brand');
      if (productName.isEmpty) missingFields.add('Product Name');
      if (productPrice == 0.0) missingFields.add('Price');
      if (customerName.isEmpty) missingFields.add('Customer Name');

      if (brand.isNotEmpty && productName.isNotEmpty) {
        autofillMessage += '\n🔌 ${brand.toUpperCase()} - $productName';
      }

      if (missingFields.isNotEmpty) {
        autofillMessage +=
            '\n⚠ Please enter manually: ${missingFields.join(', ')}';
      }

      autofillMessage +=
          '\n\nNote: You can edit Exchange, Credit, Discount, Gifts, and other payment fields.';

      _showMessage(autofillMessage, isError: missingFields.isNotEmpty);

      // Force UI update
      setState(() {});
    } catch (e) {
      debugPrint('Error autofilling data: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      _showMessage('Error autofilling data: $e');
    }
  }

  Future<void> _getShopDetails() async {
    try {
      if (_shopId == null) return;

      final shopDoc = await _firestore
          .collection('Mobile_house_Shops')
          .doc(_shopId)
          .get();

      if (shopDoc.exists) {
        final shopData = shopDoc.data() ?? {};
        setState(() {
          _shopMobileNumber = shopData['phone']?.toString() ?? '';
          _shopWhatsAppNumber =
              shopData['whatsapp']?.toString() ??
              shopData['phone']?.toString() ??
              '';
          _shopAddress = shopData['address']?.toString() ?? '';
          _shopInstagram = shopData['instagram']?.toString() ?? 'mobile.house_';
        });
      }
    } catch (e) {
      debugPrint('Error fetching shop details: $e');
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
      if (mode != 'EMI') {
        _selectedFinanceType = null;
      }

      _discountController.text = "0";
      _exchangeController.text = "0";
      _customerCreditController.text = "0";
      _downPaymentController.text = "";
      _upgradeController.text = "0";
      _supportController.text = "0";

      _numberOfEmiController.text = "";
      _perMonthEmiController.text = "";
      _loanIdController.clear();
      _autoDebit = false;
      _insurance = false;

      _selectedGifts.clear();
      _isOtherGift = false;
      _otherGiftController.clear();
      _showGiftDropdown = false;

      _rcCashController.text = "0";
      _rcGpayController.text = "0";
      _rcCardController.text = "0";
      _rcCreditController.text = "0";
      _dpCashController.text = "0";
      _dpGpayController.text = "0";
      _dpCardController.text = "0";
      _dpCreditController.text = "0";

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

  void _clearLastSaleData() {
    setState(() {
      _lastSaleData = null;
    });
  }

  void _showSharePopup() {
    if (_lastSaleData == null) return;

    final purchaseMode = _lastSaleData!['purchaseMode']?.toString() ?? '';
    final isEmiMode = purchaseMode == 'EMI';
    final isReadyCashMode = purchaseMode == 'Ready Cash';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _successColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: _successColor,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEmiMode ? 'Appliance Sale Uploaded!' : 'Sale Uploaded!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isEmiMode
                      ? 'Share EMI details with customer'
                      : 'Share sale details with customer',
                  style: TextStyle(fontSize: 13, color: _secondaryColor),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearLastSaleData();
                        },
                        child: Text(
                          'Close',
                          style: TextStyle(color: _secondaryColor),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showShareOptionsDialog();
                        },
                        icon: Icon(Icons.share, size: 16),
                        label: Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showShareOptionsDialog() async {
    if (_lastSaleData == null) return;

    final purchaseMode = _lastSaleData!['purchaseMode']?.toString() ?? '';
    final isEmiMode = purchaseMode == 'EMI';

    final message = _generateEmiShareMessage();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEmiMode ? 'Share EMI Details' : 'Share Sale Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildShareOption(
                      icon: Icons.copy,
                      label: 'Copy',
                      color: _secondaryColor,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: message));
                        Navigator.pop(context);
                        _showMessage('📋 Copied to clipboard!', isError: false);
                        _clearLastSaleData();
                      },
                    ),
                    _buildShareOption(
                      icon: Icons.share,
                      label: 'Share',
                      color: _primaryColor,
                      onTap: () {
                        _shareViaIntent(message);
                        Navigator.pop(context);
                        _clearLastSaleData();
                      },
                    ),
                    _buildShareOption(
                      icon: Icons.message,
                      label: 'WhatsApp',
                      color: _whatsappColor,
                      onTap: () {
                        _shareToWhatsApp(message);
                        Navigator.pop(context);
                        _clearLastSaleData();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _clearLastSaleData();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: _secondaryColor),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _uploadApplianceSale() async {
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
        _rcCashController.text = "0";
        _rcGpayController.text = "0";
        _rcCardController.text = "0";
        _rcCreditController.text = "0";
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

      if (_disbursementAmountController.text.isEmpty) {
        _showMessage('Please enter disbursement amount');
        return;
      }
      final disbursementAmount =
          double.tryParse(_disbursementAmountController.text) ?? 0.0;
      if (disbursementAmount <= 0) {
        _showMessage('Please enter valid disbursement amount');
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

      final customerName = _customerNameController.text;
      final customerPhone = _customerPhoneController.text;
      final isEmiMode = _selectedPurchaseMode == 'EMI';
      final isReadyCashMode = _selectedPurchaseMode == 'Ready Cash';
      final isCreditCardMode = _selectedPurchaseMode == 'Credit Card';

      await _getShopDetails();

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
        'upgrade': 0.0,
        'support': 0.0,
        'disbursementAmount':
            double.tryParse(_disbursementAmountController.text) ?? 0.0,
        'downPayment': _selectedPurchaseMode == 'EMI'
            ? double.tryParse(_downPaymentController.text) ?? 0.0
            : 0.0,
        'numberOfEmi': _selectedPurchaseMode == 'EMI'
            ? int.tryParse(_numberOfEmiController.text) ?? 0
            : 0,
        'perMonthEmi': _selectedPurchaseMode == 'EMI'
            ? double.tryParse(_perMonthEmiController.text) ?? 0.0
            : 0.0,
        'loanId': _selectedPurchaseMode == 'EMI'
            ? _loanIdController.text
            : null,
        'autoDebit': _selectedPurchaseMode == 'EMI' ? _autoDebit : false,
        'insurance': _selectedPurchaseMode == 'EMI' ? _insurance : false,
        'gifts': _finalGiftValues,
        'giftsCount': _selectedGifts.length,
        'giftsList': _selectedGifts.join(', '),
        'exchangeValue': exchange,
        'customerCredit': customerCredit,
        'amountToPay': amountToPay > 0 ? amountToPay : 0.0,
        'balanceReturnedToCustomer': balanceReturned,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'billNumber': _withoutBillNumber ? null : _selectedBillNumber,
        'addedAt': DateTime.now(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'saleType': 'appliance',
      };

      await _firestore.collection('applianceSales').add(salesData);

      setState(() {
        _lastSaleData = {...salesData, 'customerPhone': customerPhone};
      });

      _showMessage('✓ Appliance sale uploaded successfully!', isError: false);

      if (isEmiMode || isReadyCashMode || isCreditCardMode) {
        _resetForm();

        Future.delayed(const Duration(milliseconds: 500), () {
          _showSharePopup();
        });
      } else {
        _resetForm();
      }
    } catch (e) {
      _showMessage('Failed to upload sale: $e');
      setState(() => _isLoading = false);
    }

    setState(() => _isLoading = false);
  }

  String _generateEmiShareMessage() {
    if (_lastSaleData == null) return '';

    final sale = _lastSaleData!;
    final purchaseMode = sale['purchaseMode']?.toString() ?? '';
    final isEmiMode = purchaseMode == 'EMI';
    final isReadyCashMode = purchaseMode == 'Ready Cash';

    final brand = sale['brand']?.toString().toUpperCase() ?? '';
    final model = sale['productModel']?.toString() ?? '';
    final price = (sale['price'] as num?)?.toDouble() ?? 0.0;
    final discount = (sale['discount'] as num?)?.toDouble() ?? 0.0;
    final exchange = (sale['exchangeValue'] as num?)?.toDouble() ?? 0.0;
    final customerCredit = (sale['customerCredit'] as num?)?.toDouble() ?? 0.0;
    final effectivePrice = (sale['effectivePrice'] as num?)?.toDouble() ?? 0.0;
    final amountToPay = (sale['amountToPay'] as num?)?.toDouble() ?? 0.0;
    final balanceReturned =
        (sale['balanceReturnedToCustomer'] as num?)?.toDouble() ?? 0.0;
    final saleDate = sale['saleDate'] as DateTime? ?? DateTime.now();
    final customerName = sale['customerName']?.toString() ?? '';
    final customerPhone = sale['customerPhone']?.toString() ?? '';
    final gifts = sale['giftsList']?.toString() ?? '';

    final paymentBreakdown =
        sale['paymentBreakdown'] as Map<String, dynamic>? ?? {};
    final cashAmount = (paymentBreakdown['cash'] as num?)?.toDouble() ?? 0.0;
    final gpayAmount = (paymentBreakdown['gpay'] as num?)?.toDouble() ?? 0.0;
    final cardAmount = (paymentBreakdown['card'] as num?)?.toDouble() ?? 0.0;
    final creditAmount =
        (paymentBreakdown['credit'] as num?)?.toDouble() ?? 0.0;

    final downPayment = (sale['downPayment'] as num?)?.toDouble() ?? 0.0;
    final numberOfEmi = sale['numberOfEmi'] ?? 0;
    final perMonthEmi = (sale['perMonthEmi'] as num?)?.toDouble() ?? 0.0;
    final financeType = sale['financeType']?.toString() ?? '';
    final loanId = sale['loanId']?.toString() ?? '';
    final autoDebit = sale['autoDebit'] as bool? ?? false;
    final insurance = sale['insurance'] as bool? ?? false;

    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = dateFormat.format(saleDate);

    final shopMobile = _shopMobileNumber ?? '9072430483';
    final shopWhatsApp = _shopWhatsAppNumber ?? shopMobile;
    final shopInstagram = _shopInstagram ?? 'mobile.house_';
    final shopName = sale['shopName']?.toString() ?? 'MOBILE HOUSE';

    final buffer = StringBuffer();

    buffer.writeln('📱 *$shopName*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();
    buffer.writeln('✨ *Thanks For Your Visit* ✨');
    buffer.writeln('[ Keep In Touch With Mobile House 😍]');
    buffer.writeln(
      '📸 Instagram : https://instagram.com/${shopInstagram.replaceAll('@', '')}',
    );
    buffer.writeln();

    if (isEmiMode) {
      buffer.writeln('✨ *EMI DETAILS - APPLIANCE* ✨');
    } else if (isReadyCashMode) {
      buffer.writeln('✨ *APPLIANCE SALE DETAILS* ✨');
    }

    buffer.writeln();
    buffer.writeln(' Shop : $shopName');
    buffer.writeln(' Brand : $brand');
    buffer.writeln(' Model : $model');
    buffer.writeln(' Price : ₹${price.toStringAsFixed(0)}');

    if (discount > 0) {
      buffer.writeln(' Discount : ₹${discount.toStringAsFixed(0)}');
    }

    if (isEmiMode) {
      buffer.writeln(' Down Payment : ₹${downPayment.toStringAsFixed(0)}');
    }

    if (cashAmount > 0 ||
        gpayAmount > 0 ||
        cardAmount > 0 ||
        creditAmount > 0) {
      if (cashAmount > 0)
        buffer.writeln('    • Cash: ₹${cashAmount.toStringAsFixed(0)}');
      if (gpayAmount > 0)
        buffer.writeln('    • GPay: ₹${gpayAmount.toStringAsFixed(0)}');
      if (cardAmount > 0)
        buffer.writeln('    • Card: ₹${cardAmount.toStringAsFixed(0)}');
      if (creditAmount > 0)
        buffer.writeln('    • Credit: ₹${creditAmount.toStringAsFixed(0)}');
    }

    if (exchange > 0) {
      buffer.writeln(' Exchange : ₹${exchange.toStringAsFixed(0)}');
    }

    if (customerCredit > 0) {
      buffer.writeln(
        ' Customer Credit : ₹${customerCredit.toStringAsFixed(0)}',
      );
    }

    if (balanceReturned > 0) {
      buffer.writeln(
        ' Balance Returned : ₹${balanceReturned.toStringAsFixed(0)}',
      );
    }

    if (isEmiMode) {
      buffer.writeln();
      buffer.writeln(' EMI : ₹${perMonthEmi.toStringAsFixed(0)}*$numberOfEmi');
      buffer.writeln(' Finance : $financeType');

      if (loanId.isNotEmpty) {
        buffer.writeln(' Loan Id : $loanId');
      }

      buffer.writeln(' Auto Debit : ${autoDebit ? ' YES' : ' NO'}');
      buffer.writeln(' Insurance : ${insurance ? ' YES' : ' NO'}');
    } else if (isReadyCashMode) {
      buffer.writeln(' Total Paid : ₹${amountToPay.toStringAsFixed(0)}');
    }

    buffer.writeln(' Date : $formattedDate');
    buffer.writeln();
    buffer.writeln(' Customer : $customerName');
    buffer.writeln(' Mobile : $customerPhone');

    if (gifts.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('*Mobile house Special gift🎁* ');
      buffer.writeln(' $gifts');
    }

    if (isEmiMode) {
      buffer.writeln();
      buffer.writeln('⚠️ *എല്ലാ മാസവും 1 നു മുമ്പ് EMI pay ചെയ്യണം*');
    }

    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();
    buffer.writeln('🎯 *For Exciting Offers*');
    buffer.writeln('📸 Follow @${shopInstagram.replaceAll('@', '')}');
    buffer.writeln();
    buffer.writeln('📱 MOBILE SALES - SERVICE - EXCHANGE');
    buffer.writeln();
    buffer.writeln(
      '🔄 *പഴയ മൊബൈൽ കൊണ്ടു വരൂ എക്സ്ചേഞ്ച് ചെയ്തു പുതിയ മൊബൈൽ സ്വന്തമാക്കൂ...*',
    );
    buffer.writeln();
    buffer.writeln('📞 *For more info:*');
    buffer.writeln('📞 Whatsapp : $shopWhatsApp');
    buffer.writeln('🌐 Website : https://mobilehouse.in/');

    return buffer.toString();
  }

  void _shareViaIntent(String message) async {
    try {
      await Share.share(message);
    } catch (e) {
      _showMessage('Could not share: $e');
    }
  }

  void _shareToWhatsApp(String message) async {
    try {
      String customerPhone = '';

      if (_lastSaleData != null &&
          _lastSaleData!.containsKey('customerPhone')) {
        customerPhone = _lastSaleData!['customerPhone']?.toString() ?? '';
      }

      customerPhone = customerPhone.replaceAll(RegExp(r'[^0-9]'), '');

      String phone = '';

      if (customerPhone.isNotEmpty && customerPhone.length >= 10) {
        if (customerPhone.startsWith('+')) {
          phone = customerPhone.substring(1);
        } else if (customerPhone.length == 10) {
          phone = '91$customerPhone';
        } else {
          phone = customerPhone;
        }
      } else {
        phone = _shopWhatsAppNumber ?? '9072430483';
        if (!phone.startsWith('+') && phone.length == 10) {
          phone = '91$phone';
        } else if (phone.startsWith('+')) {
          phone = phone.substring(1);
        }
      }

      phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

      final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
      final uri = Uri.parse(url);

      debugPrint('Sharing to WhatsApp: $url');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showMessage(
          'Could not open WhatsApp. Using share instead...',
          isError: false,
        );
        _shareViaIntent(message);
      }
    } catch (e) {
      debugPrint('Error sharing to WhatsApp: $e');
      _shareViaIntent(message);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Confirm Appliance Sale Upload',
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
                    'Product: ${_productModelController.text}',
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
                    const SizedBox(height: 6),
                    Text(
                      'Disbursement: ₹${double.tryParse(_disbursementAmountController.text)?.toStringAsFixed(2) ?? "0.00"}',
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
      _disbursementAmountController.text = "";
      _exchangeController.text = "0";
      _customerCreditController.text = "0";

      _numberOfEmiController.text = "";
      _perMonthEmiController.text = "";
      _loanIdController.clear();
      _autoDebit = false;
      _insurance = false;

      _selectedGifts.clear();
      _isOtherGift = false;
      _otherGiftController.clear();
      _showGiftDropdown = false;

      _rcCashController.text = "0";
      _rcGpayController.text = "0";
      _rcCardController.text = "0";
      _rcCreditController.text = "0";
      _dpCashController.text = "0";
      _dpGpayController.text = "0";
      _dpCardController.text = "0";
      _dpCreditController.text = "0";
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
            _getShopDetails();
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

  Widget _buildGiftSelection() {
    final isEditable = _isFieldEditable('gifts');

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
                          if (isEditable)
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

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _giftOptions.map((gift) {
                    final giftName = gift['name'] as String;
                    final isSelected = _selectedGifts.contains(giftName);

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
                        onSelected: isEditable
                            ? (selected) => _toggleGift(giftName)
                            : null,
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

              if (_isOtherGift && isEditable) ...[
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

  // Bill number field - ONLY APPLIANCE BILLS
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
              'Select Appliance Bill Number',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _applianceColor,
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
                  color: _applianceColor,
                ),
              ),
            const Spacer(),
            Tooltip(
              message: 'Refresh appliance bill list',
              child: GestureDetector(
                onTap: () {
                  _loadBillNumbers();
                  _showMessage('Refreshing appliance bills...', isError: false);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _applianceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.refresh, size: 16, color: _applianceColor),
                ),
              ),
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
                    _clearFormData();
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
                  border: Border.all(color: _applianceColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: _applianceColor, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _billSearchController,
                              focusNode: _billSearchFocusNode,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: _selectedBillNumber != null
                                    ? 'Selected: $_selectedBillNumber'
                                    : 'Search appliance bill number...',
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
                                    _clearFormData();
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
                                  _clearFormData();
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
                                  Icons.kitchen,
                                  color: _applianceColor,
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
                                  Future.delayed(Duration.zero, () {
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
                              'No appliance bills match "${_billSearchController.text}"',
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
                  padding: const EdgeInsets.only(top: 8, left: 2),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: _primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'Appliance bill selected',
                        style: TextStyle(
                          fontSize: 11,
                          color: _primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 20,
                        width: 1,
                        color: _secondaryColor.withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          if (_selectedBillNumber != null) {
                            _showMessage(
                              'Re-autofilling data from appliance bill...',
                              isError: false,
                            );
                            _clearFormData();
                            await Future.delayed(
                              const Duration(milliseconds: 50),
                            );
                            await _autofillFromBill(_selectedBillNumber);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _billAutofillColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _billAutofillColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.autorenew,
                                size: 12,
                                color: _billAutofillColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Autofill Again',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _billAutofillColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_billNumbers.isEmpty && !_loadingBills)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 2),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _warningColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _warningColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: _warningColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No appliance bills found for your shop',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _warningColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Create appliance bills first or use "Without Bill Number" option',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildBrandTextField() {
    final TextEditingController brandController = TextEditingController();

    if (_selectedBrand != null && brandController.text.isEmpty) {
      brandController.text = _selectedBrand!.toUpperCase();
    }

    final isEditable = _isFieldEditable('brand');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Appliance Brand *',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: !isEditable ? Colors.grey : _secondaryColor,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            final searchTerm = textEditingValue.text.toLowerCase();
            return _applianceBrands.where((brand) {
              return brand.toLowerCase().contains(searchTerm);
            });
          },
          onSelected: isEditable
              ? (String selection) {
                  setState(() {
                    _selectedBrand = selection;
                    brandController.text = selection.toUpperCase();
                  });
                }
              : null,
          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController fieldController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted,
              ) {
                if (fieldController.text != brandController.text &&
                    _selectedBrand != null) {
                  fieldController.text = _selectedBrand!.toUpperCase();
                }

                return TextField(
                  controller: fieldController,
                  focusNode: focusNode,
                  enabled: isEditable,
                  onChanged: (value) {
                    if (isEditable) {
                      if (_selectedBrand != null) {
                        setState(() {
                          _selectedBrand = null;
                        });
                      }
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Type or search appliance brand...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: Icon(
                      Icons.search,
                      color: _applianceColor,
                      size: 18,
                    ),
                    suffixIcon: _selectedBrand != null && isEditable
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: 16,
                              color: _secondaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedBrand = null;
                                fieldController.clear();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _secondaryColor.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _applianceColor,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    fillColor: !isEditable ? Colors.grey.shade50 : null,
                    filled: !isEditable,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: !isEditable ? Colors.grey.shade600 : Colors.black,
                  ),
                );
              },
          optionsViewBuilder:
              (
                BuildContext context,
                AutocompleteOnSelected<String> onSelected,
                Iterable<String> options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String option = options.elementAt(index);
                          return ListTile(
                            title: Text(
                              option.toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () {
                              onSelected(option);
                            },
                            leading: Icon(
                              Icons.kitchen,
                              size: 16,
                              color: _applianceColor,
                            ),
                            dense: true,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
          displayStringForOption: (String option) => option.toUpperCase(),
        ),
        if (_selectedBrand != null && isEditable)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _applianceColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 12, color: _applianceColor),
                  const SizedBox(width: 4),
                  Text(
                    'Selected: ${_selectedBrand!.toUpperCase()}',
                    style: TextStyle(fontSize: 11, color: _applianceColor),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoanIdField() {
    final isEditable = _isFieldEditable('loanId');

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
          enabled: isEditable,
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
            fillColor: !isEditable ? Colors.grey.shade50 : null,
            filled: !isEditable,
          ),
          style: TextStyle(
            fontSize: 13,
            color: !isEditable ? Colors.grey.shade600 : Colors.black,
          ),
          keyboardType: TextInputType.text,
        ),
      ],
    );
  }

  Widget _buildLoanOptions() {
    final isEditable = _isFieldEditable('autoDebit');

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

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          color: _autoDebit ? _autoDebitColor : _secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _autoDebit,
                  onChanged: isEditable
                      ? (value) {
                          setState(() {
                            _autoDebit = value;
                          });
                        }
                      : null,
                  activeColor: _autoDebitColor,
                  activeTrackColor: _autoDebitColor.withOpacity(0.3),
                  inactiveThumbColor: _secondaryColor,
                  inactiveTrackColor: _secondaryColor.withOpacity(0.3),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          color: _insurance ? _insuranceColor : _secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _insurance,
                  onChanged: isEditable
                      ? (value) {
                          setState(() {
                            _insurance = value;
                          });
                        }
                      : null,
                  activeColor: _insuranceColor,
                  activeTrackColor: _insuranceColor.withOpacity(0.3),
                  inactiveThumbColor: _secondaryColor,
                  inactiveTrackColor: _secondaryColor.withOpacity(0.3),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplianceSaleForm() {
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
              enabled: !_isAutofilledFromBill,
            ),
            const SizedBox(height: 6),
            _buildAdditionalField(
              label: 'Customer Phone',
              controller: _customerPhoneController,
              hint: 'Enter phone number',
              icon: Icons.phone,
              iconColor: _primaryColor,
              keyboardType: TextInputType.phone,
              enabled: _isFieldEditable('customerPhone'),
            ),
          ],
        ),

        const SizedBox(height: 10),

        _buildBrandTextField(),
        const SizedBox(height: 10),

        if (_selectedBrand != null) ...[
          _buildAdditionalField(
            label: 'Product Model *',
            controller: _productModelController,
            hint: 'Enter appliance model',
            icon: Icons.kitchen,
            iconColor: _applianceColor,
            keyboardType: TextInputType.text,
            enabled: !_isAutofilledFromBill,
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
            label: 'Serial Number / IMEI (Optional)',
            controller: _imeiController,
            hint: 'Enter serial number or IMEI',
            icon: Icons.fingerprint,
            iconColor: _purpleColor,
            keyboardType: TextInputType.text,
            enabled: !_isAutofilledFromBill,
          ),
          const SizedBox(height: 10),
        ],

        if (_selectedProductModel != null &&
            _selectedProductModel!.isNotEmpty) ...[
          _buildAdditionalField(
            label: 'Price *',
            controller: _priceController,
            hint: 'Enter appliance price',
            icon: Icons.attach_money,
            iconColor: _primaryColor,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            enabled: !_isAutofilledFromBill,
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
              border: Border.all(color: _applianceColor.withOpacity(0.3)),
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
                    color: _applianceColor,
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
            onChanged: !_isAutofilledFromBill ? _onPurchaseModeSelected : null,
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
                      enabled: _isFieldEditable('cash'),
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
                      enabled: _isFieldEditable('gpay'),
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
                      enabled: _isFieldEditable('card'),
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
                      enabled: _isFieldEditable('credit'),
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
            onChanged: !_isAutofilledFromBill
                ? (value) => setState(() => _selectedFinanceType = value)
                : null,
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
                enabled: _isFieldEditable('downPayment'),
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
                  fillColor: !_isFieldEditable('downPayment')
                      ? Colors.grey.shade50
                      : null,
                  filled: !_isFieldEditable('downPayment'),
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: !_isFieldEditable('downPayment')
                      ? Colors.grey.shade600
                      : Colors.black,
                ),
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
                enabled: _isFieldEditable('numberOfEmi'),
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
                enabled: _isFieldEditable('perMonthEmi'),
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 10),

              _buildAdditionalField(
                label: 'Disbursement Amount *',
                controller: _disbursementAmountController,
                hint: 'Enter disbursement amount',
                icon: Icons.monetization_on,
                iconColor: _primaryColor,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                enabled: _isFieldEditable('disbursementAmount'),
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 10),

              _buildLoanIdField(),
              const SizedBox(height: 10),

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
                label: 'Exchange Value (Default: 0)',
                controller: _exchangeController,
                hint: 'Enter exchange value',
                icon: Icons.swap_horiz,
                iconColor: _tealColor,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                enabled: _isFieldEditable('exchange'),
                onChanged: (value) {
                  setState(() => _updateCreditCardPayment());
                },
              ),
              const SizedBox(height: 10),

              _buildAdditionalField(
                label: 'Customer Credit (Pay Later) (Default: 0)',
                controller: _customerCreditController,
                hint: 'Enter credit amount',
                icon: Icons.credit_score,
                iconColor: _orangeColor,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                enabled: _isFieldEditable('customerCredit'),
                onChanged: (value) {
                  setState(() => _updateCreditCardPayment());
                },
              ),
              const SizedBox(height: 10),

              _buildAdditionalField(
                label: _selectedPurchaseMode == 'EMI'
                    ? 'Discount (Deducted from Down Payment) (Default: 0)'
                    : 'Discount Amount (Deducted from Price) (Default: 0)',
                controller: _discountController,
                hint: 'Enter discount amount',
                icon: Icons.discount,
                iconColor: _discountColor,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                enabled: _isFieldEditable('discount'),
                onChanged: (value) {
                  setState(() => _updateCreditCardPayment());
                },
              ),
              const SizedBox(height: 10),

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
                        'Remaining Down Payment Breakdown (Default: 0)',
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
                              enabled: _isFieldEditable('dpCash'),
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
                              enabled: _isFieldEditable('dpGpay'),
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
                              enabled: _isFieldEditable('dpCard'),
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
                              enabled: _isFieldEditable('dpCredit'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildPaymentValidationForEMI(),
                    ],
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

                if ((double.tryParse(_disbursementAmountController.text) ??
                        0.0) >
                    0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Disbursement Amount:',
                        style: TextStyle(fontSize: 11, color: _primaryColor),
                      ),
                      Text(
                        '₹${(double.tryParse(_disbursementAmountController.text) ?? 0.0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),

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
              ],
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
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: enabled ? _secondaryColor : Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          enabled: enabled,
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
            fillColor: !enabled ? Colors.grey.shade50 : null,
            filled: !enabled,
          ),
          style: TextStyle(
            fontSize: 13,
            color: !enabled ? Colors.grey.shade600 : Colors.black,
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
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: _secondaryColor)),
        const SizedBox(height: 3),
        TextField(
          controller: controller,
          onChanged: onChanged,
          enabled: enabled,
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
            fillColor: !enabled ? Colors.grey.shade50 : null,
            filled: !enabled,
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            fontSize: 12,
            color: !enabled ? Colors.grey.shade600 : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?>? onChanged,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: onChanged != null ? _secondaryColor : Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _secondaryColor.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
            color: onChanged == null ? Colors.grey.shade50 : null,
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
            style: TextStyle(
              fontSize: 12,
              color: onChanged != null ? Colors.black : Colors.grey.shade600,
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(6),
            disabledHint: Text(
              hint,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ),
      ],
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
        border: Border.all(color: _applianceColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _applianceColor,
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
    final isEditable = !_isAutofilledFromBill;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sale Date',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isEditable ? _secondaryColor : Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: isEditable ? _selectDate : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: _secondaryColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
              color: !isEditable ? Colors.grey.shade50 : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: !isEditable ? Colors.grey : _primaryColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_saleDate.day}/${_saleDate.month}/${_saleDate.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: !isEditable ? Colors.grey.shade600 : _secondaryColor,
                  ),
                ),
                const Spacer(),
                if (isEditable)
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
                colors: [_applianceColor, _applianceColor.withOpacity(0.7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        borderRadius: BorderRadius.circular(10),
        color: (_isLoading || _shopId == null)
            ? _secondaryColor.withOpacity(0.3)
            : null,
      ),
      child: ElevatedButton(
        onPressed: (_isLoading || _shopId == null)
            ? null
            : _uploadApplianceSale,
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
                _shopId == null
                    ? 'Waiting for Shop Info'
                    : 'Upload Appliance Sale',
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
            'Appliance Sale Upload',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: _applianceColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loadBillNumbers,
              tooltip: 'Refresh appliance bill list',
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
                      _buildApplianceSaleForm(),
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
