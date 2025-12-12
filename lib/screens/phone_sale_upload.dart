import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneSaleUpload extends StatefulWidget {
  const PhoneSaleUpload({super.key});

  @override
  State<PhoneSaleUpload> createState() => _PhoneSaleUploadState();
}

class _PhoneSaleUploadState extends State<PhoneSaleUpload> {
  bool _isLoading = false;
  bool _loadingShopInfo = false;
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
  final TextEditingController _imeiController =
      TextEditingController(); // NEW: IMEI Controller

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

  // Predefined smartphone brands
  final List<String> _phoneBrands = [
    'apple',
    'samsung',
    'xiaomi',
    'redmi',
    'realme',
    'oneplus',
    'oppo',
    'vivo',
    'motorola',
    'nokia',
    'google',
    'asus',
    'sony',
    'lg',
    'huawei',
    'honor',
    'poco',
    'infinix',
    'tecno',
    'itel',
    'micromax',
    'lava',
    'gionee',
    'blackberry',
    'htc',
    'lenovo',
  ];

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
  final Color _tealColor = const Color(0xFF14B8A6);
  final Color _orangeColor = const Color(0xFFF97316);
  final Color _discountColor = const Color(0xFF8B5CF6);
  final Color _returnColor = const Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _getUserShopId();

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
    _priceController.addListener(_updatePrice);
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

  void _updatePrice() {
    setState(() {});
  }

  double _calculateEffectivePrice() {
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;

    // For EMI, discount is NOT subtracted from effective price
    if (_selectedPurchaseMode == 'EMI') {
      return price; // Original price without discount
    } else {
      // For Ready Cash and Credit Card, discount is subtracted from price
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

  double _calculateBalanceReturned() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final exchange = double.tryParse(_exchangeController.text) ?? 0.0;
    final customerCredit =
        double.tryParse(_customerCreditController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;

    if (_selectedPurchaseMode == 'EMI') {
      final downPayment = double.tryParse(_downPaymentController.text) ?? 0.0;

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

      if (mode == 'Credit Card') {
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

  void _uploadPhoneSale() async {
    // First, check if shop info is available
    if (_shopId == null || _shopName == null) {
      _showMessage(
        'Shop information not found. Please check your profile setup.',
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

    // Show confirmation dialog before uploading
    final shouldUpload = await _showConfirmationDialog();
    if (!shouldUpload) {
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

      // Create phone sale item
      // final phoneSaleItem = {

      // };

      final salesData = {
        'userId': user.uid,
        'userEmail': user.email,
        'shopId': _shopId,
        'shopName': _shopName,
        'saleDate': _saleDate,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'brand': _selectedBrand ?? '',
        'productModel': _productModelController.text,
        'imei': _imeiController.text, // NEW: Include IMEI in data
        'price': price,
        'discount': discount,
        'effectivePrice': effectivePrice,
        'purchaseMode': _selectedPurchaseMode ?? '',
        'paymentBreakdown': _selectedPaymentBreakdown.toMap(),
        'financeType': _selectedFinanceType,
        'upgrade': _upgradeController.text,
        'support': _supportController.text,
        'disbursementAmount':
            double.tryParse(_disbursementAmountController.text) ?? 0.0,
        'downPayment': _selectedPurchaseMode == 'EMI'
            ? double.tryParse(_downPaymentController.text) ?? 0.0
            : 0.0,
        'exchangeValue': exchange,
        'customerCredit': customerCredit,
        'amountToPay': amountToPay > 0 ? amountToPay : 0.0,
        'balanceReturnedToCustomer': balanceReturned,
        'customerName': _customerNameController.text,
        'customerPhone': _customerPhoneController.text,
        'addedAt': DateTime.now(),

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('Uploading sale data with shopId: $_shopId, shopName: $_shopName');

      await _firestore.collection('phoneSales').add(salesData);

      _showMessage(
        'Phone sale uploaded successfully! Shop: $_shopName',
        isError: false,
      );
      _resetForm();
    } catch (e) {
      _showMessage('Failed to upload sale: $e');
      print('Upload error: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Sale Upload'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shop: $_shopName'),
                const SizedBox(height: 8),
                Text(
                  'Customer: ${_customerNameController.text.isNotEmpty ? _customerNameController.text : "N/A"}',
                ),
                const SizedBox(height: 8),
                Text('Brand: ${_selectedBrand?.toUpperCase() ?? "N/A"}'),
                const SizedBox(height: 8),
                Text('Model: ${_productModelController.text}'),
                const SizedBox(height: 8),
                if (_imeiController
                    .text
                    .isNotEmpty) // NEW: Show IMEI in confirmation
                  Text('IMEI: ${_imeiController.text}'),
                const SizedBox(height: 8),
                Text('Price: ₹${_getSelectedPrice().toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                Text('Purchase Mode: ${_selectedPurchaseMode ?? "N/A"}'),
                if (_calculateBalanceReturned() > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Balance to Return: ₹${_calculateBalanceReturned().toStringAsFixed(2)}',
                        style: TextStyle(color: _returnColor),
                      ),
                    ],
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                child: const Text(
                  'Confirm',
                  style: TextStyle(color: Colors.white),
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
      _customerNameController.clear();
      _customerPhoneController.clear();
      _productModelController.clear();
      _imeiController.clear(); // NEW: Clear IMEI field
      _priceController.clear();
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
    });
  }

  Future<void> _getUserShopId() async {
    try {
      setState(() {
        _loadingShopInfo = true;
      });

      final User? user = _auth.currentUser;
      if (user != null) {
        print('Fetching shop info for user: ${user.uid}');
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          print('User data: $userData');

          setState(() {
            _shopId = userData['shopId']?.toString();
            _shopName = userData['shopName']?.toString();
            _loadingShopInfo = false;
          });

          print('Shop ID: $_shopId, Shop Name: $_shopName');
        } else {
          print('User document not found or empty');
          setState(() {
            _loadingShopInfo = false;
          });
        }
      } else {
        print('No authenticated user');
        setState(() {
          _loadingShopInfo = false;
        });
      }
    } catch (e) {
      print('Error getting shop ID: $e');
      setState(() {
        _loadingShopInfo = false;
      });
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

  Widget _buildPhoneSaleForm() {
    final balanceReturned = _calculateBalanceReturned();
    final amountToPay = _calculateAmountToPay();
    final price = _getSelectedPrice();

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
            });
          },
          hint: 'Choose phone brand',
        ),
        const SizedBox(height: 12),

        // Product Model Text Field
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
          const SizedBox(height: 12),
        ],

        // IMEI Field (NEW: Added after product model)
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
              // Optional: Add IMEI validation here
              if (value.length > 15) {
                _imeiController.text = value.substring(0, 15);
                _imeiController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _imeiController.text.length),
                );
              }
            },
          ),
          const SizedBox(height: 12),
        ],

        // Price Field
        if (_selectedProductModel != null &&
            _selectedProductModel!.isNotEmpty) ...[
          _buildAdditionalField(
            label: 'Price *',
            controller: _priceController,
            hint: 'Enter phone price',
            icon: Icons.attach_money,
            iconColor: _accentColor,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
        ],

        // Price Display (if price is entered)
        if (price > 0) ...[
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
                  '₹${price.toStringAsFixed(2)}',
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
        if (price > 0) ...[
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
                      onChanged: (value) {},
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
                      onChanged: (value) {},
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
                      onChanged: (value) {},
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
                      onChanged: (value) {},
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
        if (_selectedPurchaseMode != null && price > 0) ...[
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
                              onChanged: (value) {},
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
                              onChanged: (value) {},
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
                              onChanged: (value) {},
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
                              onChanged: (value) {},
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
    final price = _getSelectedPrice();
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
                '₹${price.toStringAsFixed(2)}',
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
            value: value,
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
            child: Icon(Icons.phone_iphone, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Phone Sales Upload',
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
    if (_shopId == null || _shopName == null) {
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
              child: _loadingShopInfo
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
                          'Loading shop information...',
                          style: TextStyle(
                            fontSize: 12,
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
                            fontSize: 12,
                            color: _secondaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _getUserShopId,
                          child: Text(
                            'Tap to refresh',
                            style: TextStyle(
                              fontSize: 11,
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
                if (_shopId != null)
                  Text(
                    'ID: ${_shopId!.substring(0, min(8, _shopId!.length))}...',
                    style: TextStyle(fontSize: 9, color: _secondaryColor),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _getUserShopId,
            child: Icon(Icons.refresh, size: 16, color: _primaryColor),
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

  Widget _buildUploadButton() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        gradient: (_isLoading || _shopId == null)
            ? null
            : LinearGradient(
                colors: [_primaryColor, const Color(0xFF1D4ED8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        borderRadius: BorderRadius.circular(12),
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
                _shopId == null ? 'Waiting for Shop Info' : 'Upload Phone Sale',
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
        title: const Text('Phone Sales Upload'),
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
                    // Sale Date Picker
                    _buildDatePicker(),
                    const SizedBox(height: 20),

                    // Phone Sales Form
                    _buildPhoneSaleForm(),
                  ],
                ),
              ),
            ),
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
    _imeiController.dispose(); // NEW: Dispose IMEI controller
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
