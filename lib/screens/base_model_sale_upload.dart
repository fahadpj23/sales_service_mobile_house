import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BaseModelSaleUpload extends StatefulWidget {
  const BaseModelSaleUpload({super.key});

  @override
  State<BaseModelSaleUpload> createState() => _BaseModelSaleUploadState();
}

class _BaseModelSaleUploadState extends State<BaseModelSaleUpload> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isUploading = false;

  // Shop information
  String? _shopId;
  String? _shopName;
  bool _isLoadingShopData = true;

  // Form controllers
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _modelNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _cardController = TextEditingController();
  final TextEditingController _gpayController = TextEditingController();
  final TextEditingController _payLaterController = TextEditingController();

  // Selected values
  String? _selectedBrand;

  // Date variable for Timestamp
  DateTime? _selectedDate;

  // Keypad Phone Brands
  final List<String> _keypadBrands = [
    'Nokia',
    'Itel',
    'Samsung',
    'Micromax',
    'Lava',
    'Karbonn',
    'Intex',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _getUserShopData();
    // Set default date to today
    _selectedDate = DateTime.now();
    _dateController.text =
        "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
  }

  // Get shop data from current user's document
  void _getUserShopData() async {
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
            _shopId = userData['shopId'] ?? '';
            _shopName = userData['shopName'] ?? '';
            _isLoadingShopData = false;
          });
        } else {
          setState(() {
            _isLoadingShopData = false;
          });
          _showShopDataError('User profile not found');
        }
      } else {
        setState(() {
          _isLoadingShopData = false;
        });
        _showShopDataError('User not logged in');
      }
    } catch (e) {
      print('Error getting shop data: $e');
      setState(() {
        _isLoadingShopData = false;
      });
      _showShopDataError('Failed to load shop information');
    }
  }

  void _showShopDataError(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Shop Information Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  // Safe parsing helper method
  double _safeParse(String text) {
    if (text.trim().isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }

  // Auto-calculate payments when price changes
  void _autoCalculatePayments() {
    final priceText = _priceController.text.trim();
    if (priceText.isEmpty) return;

    final totalPrice = _safeParse(priceText);
    if (totalPrice <= 0) return;

    // Removed auto-fill cash logic - user must manually enter payment breakdown
    setState(() {});
  }

  // Date picker function
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  // Calculate total payment
  double _calculateTotalPayment() {
    double cash = _safeParse(_cashController.text);
    double card = _safeParse(_cardController.text);
    double gpay = _safeParse(_gpayController.text);
    double payLater = _safeParse(_payLaterController.text);
    return cash + card + gpay + payLater;
  }

  // Validate payment breakdown - Checks if Cash + Card + GPay + Pay Later = Sale Price
  bool _validatePaymentBreakdown(double totalPrice) {
    if (totalPrice <= 0) return false;
    final totalPayment = _calculateTotalPayment();
    return (totalPayment - totalPrice).abs() < 0.01;
  }

  // Get payment breakdown status
  String _getPaymentStatus(double totalPrice) {
    if (totalPrice <= 0) return 'pending';
    final totalPayment = _calculateTotalPayment();
    if (_validatePaymentBreakdown(totalPrice)) return 'balanced';
    if (totalPayment < totalPrice) return 'short';
    return 'excess';
  }

  // Upload function to Firebase
  Future<void> _uploadSale() async {
    if (_shopId == null ||
        _shopName == null ||
        _shopId!.isEmpty ||
        _shopName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Shop information is required. Please update your profile.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      // Validate date is selected
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a date'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final totalPrice = _safeParse(_priceController.text);

      if (!_validatePaymentBreakdown(totalPrice)) {
        final totalPayment = _calculateTotalPayment();
        final difference = (totalPrice - totalPayment).abs();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              totalPayment < totalPrice
                  ? 'Payment is short by \$${difference.toStringAsFixed(2)}'
                  : 'Payment exceeds by \$${difference.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      setState(() {
        _isUploading = true;
      });

      try {
        // Prepare sale data for Firebase
        final saleData = {
          'date': Timestamp.fromDate(_selectedDate!), // Store as Timestamp
          'dateString': _dateController.text, // Keep string format for display
          'customerName': _customerNameController.text.trim(),
          'customerPhone': _customerPhoneController.text.trim(),
          'brand': _selectedBrand,
          'modelName': _modelNameController.text,
          'price': totalPrice,
          'cash': _safeParse(_cashController.text),
          'card': _safeParse(_cardController.text),
          'gpay': _safeParse(_gpayController.text),
          'payLater': _safeParse(_payLaterController.text),
          'totalPayment': _calculateTotalPayment(),
          'paymentStatus': _getPaymentStatus(totalPrice),
          // User information
          'salesPersonId': _auth.currentUser?.uid,
          'salesPersonEmail': _auth.currentUser?.email,
          'salesPersonName':
              _auth.currentUser?.displayName ??
              _auth.currentUser?.email?.split('@')[0] ??
              '',
          // Shop information
          'shopId': _shopId,
          'shopName': _shopName,
          'uploadedAt': FieldValue.serverTimestamp(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        // Upload to Firebase Firestore
        await _firestore.collection('base_model_sale').add(saleData);

        // Store customer info for success dialog before clearing
        final customerName = _customerNameController.text;
        final customerPhone = _customerPhoneController.text;

        // Clear the form immediately after successful upload
        _clearForm();

        // Show success dialog
        _showSuccessDialog(
          context,
          customerName: customerName,
          customerPhone: customerPhone,
        );
      } catch (error) {
        // Show error dialog
        _showErrorDialog(context, error.toString());
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showSuccessDialog(
    BuildContext context, {
    String? customerName,
    String? customerPhone,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.purple[700],
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.purple[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Base model sale uploaded to Firebase',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shop: $_shopName',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                Text(
                  'Collection: base_model_sale',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),

                // Show customer info in success dialog if available
                if (customerName != null && customerName.isNotEmpty ||
                    customerPhone != null && customerPhone.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        if (customerName != null && customerName.isNotEmpty)
                          Text(
                            'Customer: $customerName',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (customerPhone != null && customerPhone.isNotEmpty)
                          Text(
                            'Phone: $customerPhone',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[800],
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error, color: Colors.red[700], size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload Failed',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.red[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Error uploading to Firebase',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error.length > 100
                        ? '${error.substring(0, 100)}...'
                        : error,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearForm() {
    // Clear all text controllers
    _dateController.clear();
    _customerNameController.clear();
    _customerPhoneController.clear();
    _modelNameController.clear();
    _priceController.clear();
    _cashController.clear();
    _cardController.clear();
    _gpayController.clear();
    _payLaterController.clear();

    // Reset dropdown
    _selectedBrand = null;

    // Reset date to today
    _selectedDate = DateTime.now();
    _dateController.text =
        "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

    // Reset form state
    _formKey.currentState?.reset();

    // Update UI
    setState(() {});
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? prefixIcon,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    int? maxLines = 1,
    bool isRequired = false,
    String? hintText,
    VoidCallback? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            children: isRequired
                ? [
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          validator: validator,
          maxLines: maxLines,
          onChanged: (value) {
            onChanged?.call();
            setState(() {});
          },
          decoration: InputDecoration(
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.grey[600], size: 20)
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.purple, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildPaymentCard({
    required String title,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    String hintText = '0.00',
  }) {
    final amount = _safeParse(controller.text);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {});
            },
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: const TextStyle(fontSize: 13, color: Colors.black87),
              hintText: hintText,
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final amount = double.tryParse(value);
                if (amount == null) {
                  return 'Enter valid number';
                }
                if (amount < 0) {
                  return 'Cannot be negative';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // Widget for Shop Information section
  Widget _buildShopInfoSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.store, color: Colors.blue, size: 18),
                SizedBox(width: 6),
                Text(
                  'Shop Information',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoadingShopData)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Loading shop information...',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else if (_shopId != null && _shopName != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    // Shop ID Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.badge,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shop ID',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                _shopId!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    // Shop Name Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.storefront,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shop Name',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                _shopName!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: Colors.red[700]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Shop information not found. Please update your profile.',
                        style: TextStyle(fontSize: 12, color: Colors.red[700]),
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

  @override
  Widget build(BuildContext context) {
    final priceText = _priceController.text.trim();
    final totalPrice = priceText.isNotEmpty
        ? double.tryParse(priceText) ?? 0.0
        : 0.0;
    final totalPayment = _calculateTotalPayment();
    final paymentStatus = _getPaymentStatus(totalPrice);
    final difference = (totalPrice - totalPayment).abs();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Base Model Sale Upload',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.purple[700],
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _isUploading ? null : _clearForm,
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Clear form',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.phone_android,
                                color: Colors.purple[700],
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Base Model Sale Record',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Record base/keypad phone sales',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Shop Information Section
                  _buildShopInfoSection(),

                  const SizedBox(height: 20),

                  // Product Information Section
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.smartphone,
                                color: Colors.purple,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Product Details',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Date
                          _buildTextField(
                            controller: _dateController,
                            label: 'Sale Date',
                            prefixIcon: Icons.calendar_today,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_month, size: 20),
                              onPressed: () => _selectDate(context),
                            ),
                            readOnly: true,
                            onTap: () => _selectDate(context),
                            validator: (value) {
                              if (_selectedDate == null) {
                                return 'Please select a date';
                              }
                              return null;
                            },
                            isRequired: true,
                          ),
                          const SizedBox(height: 12),

                          // Customer Name
                          _buildTextField(
                            controller: _customerNameController,
                            label: 'Customer Name',
                            prefixIcon: Icons.person_outline,
                            hintText: 'Enter customer name',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter customer name';
                              }
                              return null;
                            },
                            isRequired: true,
                          ),
                          const SizedBox(height: 12),

                          // Customer Phone
                          _buildTextField(
                            controller: _customerPhoneController,
                            label: 'Customer Phone',
                            prefixIcon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            hintText: 'Enter phone number',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter phone number';
                              }
                              // Simple phone validation (at least 10 digits)
                              final phoneRegex = RegExp(r'^[0-9]{10,}$');
                              final digitsOnly = value.replaceAll(
                                RegExp(r'\D'),
                                '',
                              );
                              if (!phoneRegex.hasMatch(digitsOnly)) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                            isRequired: true,
                          ),
                          const SizedBox(height: 12),

                          // Brand Dropdown
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Phone Brand *',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _selectedBrand,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Colors.purple,
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                                items: _keypadBrands.map((String brand) {
                                  return DropdownMenuItem<String>(
                                    value: brand,
                                    child: Text(
                                      brand,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedBrand = newValue;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select brand';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Model Name
                          _buildTextField(
                            controller: _modelNameController,
                            label: 'Model Name',
                            prefixIcon: Icons.devices,
                            hintText: 'e.g., Nokia 105, Samsung Guru',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter model name';
                              }
                              return null;
                            },
                            isRequired: true,
                          ),
                          const SizedBox(height: 12),

                          // Price (Sale Price)
                          _buildTextField(
                            controller: _priceController,
                            label: 'Sale Price',
                            prefixIcon: Icons.attach_money,
                            keyboardType: TextInputType.number,
                            hintText: 'Enter sale price',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter sale price';
                              }
                              final parsed = double.tryParse(value);
                              if (parsed == null) {
                                return 'Please enter a valid number';
                              }
                              if (parsed <= 0) {
                                return 'Price must be greater than 0';
                              }
                              return null;
                            },
                            isRequired: true,
                            onChanged: _autoCalculatePayments,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Payment Breakdown Section
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.payments,
                                color: Colors.purple,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Payment Breakdown',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Padding(
                            padding: EdgeInsets.only(left: 24),
                            child: Text(
                              'Split payment across different methods',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Payment Methods Grid
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildPaymentCard(
                                      title: 'Cash',
                                      icon: Icons.money,
                                      color: Colors.green,
                                      controller: _cashController,
                                      hintText: 'Cash amount',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildPaymentCard(
                                      title: 'Card',
                                      icon: Icons.credit_card,
                                      color: Colors.blue,
                                      controller: _cardController,
                                      hintText: 'Card amount',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildPaymentCard(
                                      title: 'GPay',
                                      icon: Icons.payment,
                                      color: Colors.purple,
                                      controller: _gpayController,
                                      hintText: 'GPay amount',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildPaymentCard(
                                      title: 'Pay Later',
                                      icon: Icons.schedule,
                                      color: Colors.orange,
                                      controller: _payLaterController,
                                      hintText: 'Pay later amount',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Payment Summary with Validation
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: paymentStatus == 'balanced'
                                  ? Colors.purple[50]
                                  : paymentStatus == 'short'
                                  ? Colors.orange[50]
                                  : Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: paymentStatus == 'balanced'
                                    ? Colors.purple[200]!
                                    : paymentStatus == 'short'
                                    ? Colors.orange[200]!
                                    : Colors.red[200]!,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Sale Price
                                _buildSummaryRow(
                                  label: 'Sale Price',
                                  value: '\$${totalPrice.toStringAsFixed(2)}',
                                  icon: Icons.price_check,
                                  color: Colors.purple,
                                ),
                                const SizedBox(height: 12),

                                // Total Payment
                                _buildSummaryRow(
                                  label: 'Total Payment',
                                  value: '\$${totalPayment.toStringAsFixed(2)}',
                                  icon: Icons.payments,
                                  color: paymentStatus == 'balanced'
                                      ? Colors.purple
                                      : Colors.orange,
                                ),
                                const SizedBox(height: 12),

                                // Status Row with Validation
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: paymentStatus == 'balanced'
                                        ? Colors.purple[100]
                                        : paymentStatus == 'short'
                                        ? Colors.orange[100]
                                        : Colors.red[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            paymentStatus == 'balanced'
                                                ? Icons.check_circle
                                                : paymentStatus == 'short'
                                                ? Icons.warning
                                                : Icons.error,
                                            color: paymentStatus == 'balanced'
                                                ? Colors.purple
                                                : paymentStatus == 'short'
                                                ? Colors.orange
                                                : Colors.red,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  paymentStatus == 'balanced'
                                                      ? 'Payment Breakdown ✓'
                                                      : paymentStatus == 'short'
                                                      ? 'Payment Incomplete'
                                                      : 'Payment Error',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        paymentStatus ==
                                                            'balanced'
                                                        ? Colors.purple[800]
                                                        : paymentStatus ==
                                                              'short'
                                                        ? Colors.orange[800]
                                                        : Colors.red[800],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  paymentStatus == 'balanced'
                                                      ? 'Cash + Card + GPay + Pay Later = Sale Price'
                                                      : paymentStatus == 'short'
                                                      ? 'Short by \$${difference.toStringAsFixed(2)}'
                                                      : 'Exceeds by \$${difference.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        paymentStatus ==
                                                            'balanced'
                                                        ? Colors.purple[700]
                                                        : paymentStatus ==
                                                              'short'
                                                        ? Colors.orange[700]
                                                        : Colors.red[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                  ),
                                ),

                                // Progress Indicator
                                if (paymentStatus != 'balanced')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Column(
                                      children: [
                                        LinearProgressIndicator(
                                          value: totalPrice > 0
                                              ? totalPayment / totalPrice
                                              : 0,
                                          backgroundColor: Colors.grey[200],
                                          color: paymentStatus == 'short'
                                              ? Colors.orange
                                              : Colors.red,
                                          minHeight: 6,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Paid: \$${totalPayment.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              'Remaining: \$${(totalPrice - totalPayment).abs().toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: paymentStatus == 'short'
                                                    ? Colors.orange[700]
                                                    : Colors.red[700],
                                                fontWeight: FontWeight.w600,
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isUploading ? null : _clearForm,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Clear All',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              (_isUploading ||
                                  _shopId == null ||
                                  _shopName == null ||
                                  _shopId!.isEmpty ||
                                  _shopName!.isEmpty)
                              ? null
                              : _uploadSale,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 1,
                            shadowColor: Colors.purple.withOpacity(0.2),
                          ),
                          child: _isUploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_upload_outlined, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Upload',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Uploads to Firebase collection: base_model_sale',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Payment Validation: Cash + Card + GPay + Pay Later = Sale Price',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_shopName != null)
                    Center(
                      child: Text(
                        'Shop: $_shopName',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Clean up controllers
    _dateController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _modelNameController.dispose();
    _priceController.dispose();
    _cashController.dispose();
    _cardController.dispose();
    _gpayController.dispose();
    _payLaterController.dispose();
    super.dispose();
  }
}
