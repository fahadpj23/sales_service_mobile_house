import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SecondPhoneSaleUpload extends StatefulWidget {
  const SecondPhoneSaleUpload({super.key});

  @override
  State<SecondPhoneSaleUpload> createState() => _SecondPhoneSaleUploadState();
}

class _SecondPhoneSaleUploadState extends State<SecondPhoneSaleUpload> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isUploading = false;

  // Form controllers
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _imeiController = TextEditingController();
  final TextEditingController _defectController = TextEditingController();
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _cardController = TextEditingController();
  final TextEditingController _gpayController = TextEditingController();
  final TextEditingController _payLaterController = TextEditingController();

  // Safe parsing helper method
  double _safeParse(String text) {
    if (text.trim().isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }

  // Update payment summary when price changes
  void _updatePaymentSummary() {
    setState(() {});
  }

  // Date picker function
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
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

  // Validate payment breakdown
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
    if (_formKey.currentState!.validate()) {
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
          'date': _dateController.text,
          'productName': _productNameController.text,
          'price': totalPrice,
          'imei': _imeiController.text,
          'defect': _defectController.text.isNotEmpty
              ? _defectController.text
              : 'No defects',
          'cash': _safeParse(_cashController.text),
          'card': _safeParse(_cardController.text),
          'gpay': _safeParse(_gpayController.text),
          'payLater': _safeParse(_payLaterController.text),
          'totalPayment': _calculateTotalPayment(),
          'paymentStatus': _getPaymentStatus(totalPrice),
          'uploadedAt': FieldValue.serverTimestamp(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        // Upload to Firebase Firestore
        await _firestore.collection('seconds_phone_sale').add(saleData);

        // Show success dialog
        _showSuccessDialog(context);
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

  void _showSuccessDialog(BuildContext context) {
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
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green[700],
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Phone sale uploaded to Firebase',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Collection: seconds_phone_sale',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _clearForm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'New Sale',
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
                    child: Text(
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
    _productNameController.clear();
    _priceController.clear();
    _imeiController.clear();
    _defectController.clear();
    _cashController.clear();
    _cardController.clear();
    _gpayController.clear();
    _payLaterController.clear();

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
              borderSide: const BorderSide(color: Colors.green, width: 1.5),
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
              _updatePaymentSummary();
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
          'Phone Sale Upload',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green[700],
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
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.phone_iphone,
                                color: Colors.green[700],
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Phone Sale Record',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Record a new used phone sale',
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

                  // Phone Information Section
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
                                Icons.phone_android,
                                color: Colors.green,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Phone Details',
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
                              if (value == null || value.isEmpty) {
                                return 'Please select a date';
                              }
                              return null;
                            },
                            isRequired: true,
                          ),
                          const SizedBox(height: 12),

                          // Product Name
                          _buildTextField(
                            controller: _productNameController,
                            label: 'Product Name',
                            prefixIcon: Icons.devices,
                            hintText: 'e.g., iPhone 13 Pro, Samsung Galaxy S22',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter product name';
                              }
                              return null;
                            },
                            isRequired: true,
                          ),
                          const SizedBox(height: 12),

                          // Price
                          _buildTextField(
                            controller: _priceController,
                            label: 'Sale Price',
                            prefixIcon: Icons.attach_money,
                            keyboardType: TextInputType.number,
                            hintText: 'Enter total sale price',
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
                            onChanged: _updatePaymentSummary,
                          ),
                          const SizedBox(height: 12),

                          // IMEI
                          _buildTextField(
                            controller: _imeiController,
                            label: 'IMEI Number',
                            prefixIcon: Icons.qr_code_scanner,
                            hintText: 'Enter 15-digit IMEI number',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter IMEI number';
                              }
                              if (value.replaceAll(RegExp(r'\s+'), '').length <
                                  15) {
                                return 'IMEI must be at least 15 digits';
                              }
                              return null;
                            },
                            isRequired: true,
                          ),
                          const SizedBox(height: 12),

                          // Defects
                          _buildTextField(
                            controller: _defectController,
                            label: 'Defects / Notes (Optional)',
                            prefixIcon: Icons.note_add,
                            hintText:
                                'Describe any defects or additional notes...',
                            maxLines: 3,
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
                                color: Colors.green,
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

                          // Payment Summary
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: paymentStatus == 'balanced'
                                  ? Colors.green[50]
                                  : paymentStatus == 'short'
                                  ? Colors.orange[50]
                                  : Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: paymentStatus == 'balanced'
                                    ? Colors.green[200]!
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
                                  color: Colors.green,
                                ),
                                const SizedBox(height: 10),

                                // Total Payment
                                _buildSummaryRow(
                                  label: 'Total Payment',
                                  value: '\$${totalPayment.toStringAsFixed(2)}',
                                  icon: Icons.payments,
                                  color: paymentStatus == 'balanced'
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(height: 10),

                                // Status Row
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: paymentStatus == 'balanced'
                                        ? Colors.green[100]
                                        : paymentStatus == 'short'
                                        ? Colors.orange[100]
                                        : Colors.red[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        paymentStatus == 'balanced'
                                            ? Icons.check_circle
                                            : paymentStatus == 'short'
                                            ? Icons.warning
                                            : Icons.error,
                                        color: paymentStatus == 'balanced'
                                            ? Colors.green
                                            : paymentStatus == 'short'
                                            ? Colors.orange
                                            : Colors.red,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              paymentStatus == 'balanced'
                                                  ? 'Payment Complete'
                                                  : paymentStatus == 'short'
                                                  ? 'Payment Incomplete'
                                                  : 'Payment Error',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    paymentStatus == 'balanced'
                                                    ? Colors.green[800]
                                                    : paymentStatus == 'short'
                                                    ? Colors.orange[800]
                                                    : Colors.red[800],
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              paymentStatus == 'balanced'
                                                  ? 'All payments match sale price'
                                                  : paymentStatus == 'short'
                                                  ? 'Short by \$${difference.toStringAsFixed(2)}'
                                                  : 'Exceeds by \$${difference.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    paymentStatus == 'balanced'
                                                    ? Colors.green[700]
                                                    : paymentStatus == 'short'
                                                    ? Colors.orange[700]
                                                    : Colors.red[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Progress Indicator
                                if (paymentStatus != 'balanced')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 14),
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
                                        const SizedBox(height: 6),
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
                          onPressed: _isUploading ? null : _uploadSale,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 1,
                            shadowColor: Colors.green.withOpacity(0.2),
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
                                      'Upload ',
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
                        'Uploads to Firebase collection: seconds_phone_sale',
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
                      'Cash + Card + GPay + Pay Later = Sale Price',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
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
    _productNameController.dispose();
    _priceController.dispose();
    _imeiController.dispose();
    _defectController.dispose();
    _cashController.dispose();
    _cardController.dispose();
    _gpayController.dispose();
    _payLaterController.dispose();
    super.dispose();
  }
}
