import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccessoriesSaleUpload extends StatefulWidget {
  const AccessoriesSaleUpload({super.key});

  @override
  State<AccessoriesSaleUpload> createState() => _AccessoriesSaleUploadState();
}

class _AccessoriesSaleUploadState extends State<AccessoriesSaleUpload> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Form fields
  DateTime _selectedDate = DateTime.now();
  TextEditingController _accessoriesAmountController = TextEditingController();
  TextEditingController _serviceAmountController = TextEditingController();
  TextEditingController _cashAmountController = TextEditingController();
  TextEditingController _gpayAmountController = TextEditingController();
  TextEditingController _cardAmountController = TextEditingController();
  TextEditingController _notesController = TextEditingController();

  bool _isUploading = false;
  bool _checkingDate = false;
  bool _dateHasData = false;
  List<Map<String, dynamic>> _existingDateData = [];

  double _totalPayment = 0;
  double _calculatedTotal = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingDataForDate();
    });
  }

  void _calculateTotals() {
    setState(() {
      double accessories =
          double.tryParse(_accessoriesAmountController.text) ?? 0;
      double service = double.tryParse(_serviceAmountController.text) ?? 0;
      double cash = double.tryParse(_cashAmountController.text) ?? 0;
      double gpay = double.tryParse(_gpayAmountController.text) ?? 0;
      double card = double.tryParse(_cardAmountController.text) ?? 0;

      _calculatedTotal = accessories + service;
      _totalPayment = cash + gpay + card;
    });
  }

  Future<void> _checkExistingDataForDate() async {
    setState(() {
      _checkingDate = true;
      _dateHasData = false;
      _existingDateData.clear();
    });

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Create a date string for querying (simpler approach)
      String dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Query using composite key to avoid complex index requirements
      final querySnapshot = await _firestore
          .collection('accessories_service_sales')
          .where('compositeKey', isEqualTo: '${user.uid}_$dateString')
          .orderBy('uploadedAt', descending: true)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _dateHasData = true;
          _existingDateData = querySnapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  ...doc.data(),
                  'date': (doc.data()['date'] as Timestamp).toDate(),
                  'uploadedAt': (doc.data()['uploadedAt'] as Timestamp)
                      .toDate(),
                },
              )
              .toList();
        });
      } else {
        setState(() {
          _dateHasData = false;
          _existingDateData.clear();
        });
      }
    } catch (error) {
      print('Error checking date data: $error');
      // If there's an error, show a user-friendly message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Error checking existing data. Please try again.',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _checkingDate = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.green,
            colorScheme: const ColorScheme.light(primary: Colors.green),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // Clear form when date changes
        _accessoriesAmountController.clear();
        _serviceAmountController.clear();
        _cashAmountController.clear();
        _gpayAmountController.clear();
        _cardAmountController.clear();
        _notesController.clear();
        _calculatedTotal = 0;
        _totalPayment = 0;
      });
      await _checkExistingDataForDate();
    }
  }

  Future<void> _uploadToFirebase() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that payment breakdown equals calculated total
    if (_totalPayment != _calculatedTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment breakdown (₹$_totalPayment) must equal total (₹$_calculatedTotal)',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isUploading = false);
        return;
      }

      // Create a date string for querying
      String dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Check if data already exists using composite key
      final querySnapshot = await _firestore
          .collection('accessories_service_sales')
          .where('compositeKey', isEqualTo: '${user.uid}_$dateString')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Data already exists for this date
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Data already exists for ${DateFormat('dd/MM/yyyy').format(_selectedDate)}. Cannot upload again.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        // Refresh the UI to show existing data
        await _checkExistingDataForDate();
        setState(() => _isUploading = false);
        return;
      }

      // Prepare data for Firebase
      final saleData = {
        'date': Timestamp.fromDate(_selectedDate),
        'accessoriesAmount': double.parse(_accessoriesAmountController.text),
        'serviceAmount': double.parse(_serviceAmountController.text),
        'totalSaleAmount': _calculatedTotal,
        'cashAmount': double.parse(_cashAmountController.text),
        'gpayAmount': double.parse(_gpayAmountController.text),
        'cardAmount': double.parse(_cardAmountController.text),
        'notes': _notesController.text.trim(),
        'salesPersonId': user.uid,
        'salesPersonEmail': user.email,
        'salesPersonName': user.displayName ?? user.email!.split('@')[0],
        'uploadedAt': FieldValue.serverTimestamp(),
        'type': 'accessories_service_sale',
        'year': _selectedDate.year,
        'month': _selectedDate.month,
        'day': _selectedDate.day,
        'dateString': dateString,
        // Composite key for easy querying without complex indices
        'compositeKey': '${user.uid}_$dateString',
      };

      // Upload to Firestore
      await _firestore.collection('accessories_service_sales').add(saleData);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sale uploaded successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Clear form
      _formKey.currentState!.reset();
      setState(() {
        _accessoriesAmountController.clear();
        _serviceAmountController.clear();
        _cashAmountController.clear();
        _gpayAmountController.clear();
        _cardAmountController.clear();
        _notesController.clear();
        _totalPayment = 0;
        _calculatedTotal = 0;
      });

      // Refresh existing data
      await _checkExistingDataForDate();
    } on FirebaseException catch (firebaseError) {
      // Handle Firebase-specific errors
      String errorMessage = 'Upload failed';

      if (firebaseError.code == 'failed-precondition') {
        errorMessage = 'Index is building. Please try again in a moment.';
      } else if (firebaseError.code == 'permission-denied') {
        errorMessage = 'Permission denied. Please check your Firebase rules.';
      } else if (firebaseError.code.contains('index')) {
        errorMessage =
            'Database index required. Please wait a moment and try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firebase Error: $errorMessage'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading: ${error.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Widget _buildDateSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Sale Date',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200, width: 1.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEEE').format(_selectedDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.edit_calendar,
                        color: Colors.green.shade700,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_checkingDate)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.green.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Checking for existing entries...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
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

  Widget _buildDataExistsWarning() {
    return Card(
      elevation: 3,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.block,
                    color: Colors.red.shade700,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Data Already Exists',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    'Data already exists for this date',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You cannot upload new data for ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Please select a different date',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.green.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingDataPreview() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history,
                    color: Colors.green.shade700,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Existing Entries',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_existingDateData.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey.shade400,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No existing data found',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _existingDateData.length,
                itemBuilder: (context, index) {
                  final data = _existingDateData[index];
                  final uploadedTime = data['uploadedAt'] as DateTime;
                  final timeAgo = _getTimeAgo(uploadedTime);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Entry ${index + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Amounts Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoChip(
                                  'Accessories',
                                  '₹${(data['accessoriesAmount'] as num).toStringAsFixed(0)}',
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildInfoChip(
                                  'Service',
                                  '₹${(data['serviceAmount'] as num).toStringAsFixed(0)}',
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildInfoChip(
                                  'Total',
                                  '₹${(data['totalSaleAmount'] as num).toStringAsFixed(0)}',
                                  Colors.green,
                                  isTotal: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Payment Breakdown
                          Text(
                            'Payment Breakdown:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPaymentChip(
                                  'Cash',
                                  '₹${(data['cashAmount'] as num).toStringAsFixed(0)}',
                                  Icons.money,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildPaymentChip(
                                  'GPay',
                                  '₹${(data['gpayAmount'] as num).toStringAsFixed(0)}',
                                  Icons.phone_android,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildPaymentChip(
                                  'Card',
                                  '₹${(data['cardAmount'] as num).toStringAsFixed(0)}',
                                  Icons.credit_card,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),

                          if (data['notes'] != null &&
                              data['notes'].toString().isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  'Notes:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    data['notes'].toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade800,
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
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    String label,
    String value,
    Color color, {
    bool isTotal = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 12 : 11,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 30) return '${difference.inDays}d ago';
    if (difference.inDays < 365)
      return '${(difference.inDays / 30).floor()}mo ago';
    return '${(difference.inDays / 365).floor()}y ago';
  }

  Widget _buildAmountInput(
    String label,
    TextEditingController controller,
    IconData icon,
    Color color,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        floatingLabelStyle: TextStyle(fontSize: 14, color: color),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        prefixIcon: Icon(icon, color: color, size: 20),
        suffixText: '₹',
        suffixStyle: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade800,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter amount';
        }
        if (double.tryParse(value) == null) {
          return 'Enter valid amount';
        }
        if (double.parse(value) < 0) {
          return 'Amount cannot be negative';
        }
        return null;
      },
      onChanged: (value) => _calculateTotals(),
    );
  }

  Widget _buildPaymentInput(
    String label,
    TextEditingController controller,
    IconData icon,
    Color color,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        floatingLabelStyle: TextStyle(fontSize: 14, color: color),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        prefixIcon: Icon(icon, color: color, size: 20),
        suffixText: '₹',
        suffixStyle: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade800,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter amount';
        }
        if (double.tryParse(value) == null) {
          return 'Enter valid amount';
        }
        if (double.parse(value) < 0) {
          return 'Amount cannot be negative';
        }
        return null;
      },
      onChanged: (value) => _calculateTotals(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Sale Amounts Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.currency_rupee,
                          color: Colors.green.shade700,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Sale Components',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildAmountInput(
                    'Accessories Amount',
                    _accessoriesAmountController,
                    Icons.shopping_bag,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildAmountInput(
                    'Service Amount',
                    _serviceAmountController,
                    Icons.build,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),

                  // Total Display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.green.shade50, Colors.green.shade100],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL SALE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Accessories + Service',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹$_calculatedTotal',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade800,
                              ),
                            ),
                            Text(
                              'Must equal payment total',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade500,
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
          ),
          const SizedBox(height: 16),

          // Payment Breakdown Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.payment,
                              color: Colors.green.shade700,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Payment Breakdown',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _totalPayment == _calculatedTotal
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: _totalPayment == _calculatedTotal
                                ? Colors.green.shade300
                                : Colors.red.shade300,
                          ),
                        ),
                        child: Text(
                          '₹$_totalPayment',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _totalPayment == _calculatedTotal
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentInput(
                    'Cash Amount',
                    _cashAmountController,
                    Icons.money,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentInput(
                    'GPay Amount',
                    _gpayAmountController,
                    Icons.phone_android,
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentInput(
                    'Card Amount',
                    _cardAmountController,
                    Icons.credit_card,
                    Colors.orange,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notes Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.note,
                          color: Colors.green.shade700,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Additional Notes',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      hintText: 'Enter any notes or remarks (optional)...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.green, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Validation Status
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _totalPayment == _calculatedTotal
                    ? [Colors.green.shade50, Colors.green.shade100]
                    : [Colors.red.shade50, Colors.red.shade100],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _totalPayment == _calculatedTotal
                    ? Colors.green.shade200
                    : Colors.red.shade200,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _totalPayment == _calculatedTotal
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _totalPayment == _calculatedTotal
                        ? Icons.check_circle
                        : Icons.error,
                    color: _totalPayment == _calculatedTotal
                        ? Colors.green
                        : Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _totalPayment == _calculatedTotal
                            ? 'Ready to Upload!'
                            : 'Amounts Don\'t Match',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _totalPayment == _calculatedTotal
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _totalPayment == _calculatedTotal
                            ? 'Payment breakdown equals sale total'
                            : 'Payment total (₹$_totalPayment) ≠ Sale total (₹$_calculatedTotal)',
                        style: TextStyle(
                          fontSize: 11,
                          color: _totalPayment == _calculatedTotal
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Upload Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_totalPayment == _calculatedTotal && !_isUploading)
                  ? _uploadToFirebase
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isUploading
                  ? const Row(
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
                        SizedBox(width: 10),
                        Text(
                          'Uploading...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Upload Sale Record',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Accessories & Service Sales',
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Date Selection
            _buildDateSection(),
            const SizedBox(height: 16),

            if (_checkingDate)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.green.shade700),
                      strokeWidth: 2.5,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Checking for existing entries...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              )
            else if (_dateHasData)
              Column(
                children: [
                  // Warning that data exists
                  _buildDataExistsWarning(),
                  const SizedBox(height: 16),

                  // Existing Data Preview
                  _buildExistingDataPreview(),
                  const SizedBox(height: 16),

                  // Alternative Action Button
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Need to add more sales?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select a different date to add new sales data.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _selectDate,
                          icon: Icon(Icons.calendar_month, color: Colors.green),
                          label: Text(
                            'Choose Another Date',
                            style: TextStyle(fontSize: 13, color: Colors.green),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              _buildForm(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _accessoriesAmountController.dispose();
    _serviceAmountController.dispose();
    _cashAmountController.dispose();
    _gpayAmountController.dispose();
    _cardAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
