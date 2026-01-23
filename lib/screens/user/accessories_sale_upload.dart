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

  // Shop information
  String? _shopId;
  String? _shopName;
  bool _isLoadingShopData = true;

  bool _isUploading = false;
  bool _checkingDate = false;
  bool _dateHasDataForThisShop = false;
  List<Map<String, dynamic>> _existingDateData = [];

  double _totalPayment = 0;
  double _calculatedTotal = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getUserShopData();
    });
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
          // DON'T check for existing data on init
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

  Future<QuerySnapshot> _executeQueryWithRetry(
    Query query, {
    int maxRetries = 3,
    int initialDelay = 1000,
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        return await query.get();
      } on FirebaseException catch (e) {
        if (e.code == 'failed-precondition' &&
            e.message?.contains('index') == true) {
          attempt++;
          if (attempt == maxRetries) {
            rethrow;
          }

          // Exponential backoff
          int delay = initialDelay * (1 << (attempt - 1)); // 1, 2, 4 seconds
          await Future.delayed(Duration(milliseconds: delay));
          continue;
        } else {
          rethrow;
        }
      }
    }
    throw Exception('Max retries exceeded');
  }

  // Check if data exists only during upload
  Future<bool> _checkIfDataExistsForUpload() async {
    if (_shopId == null || _shopId!.isEmpty) {
      return false;
    }

    setState(() {
      _checkingDate = true;
    });

    try {
      final startOfDay = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final endOfDay = startOfDay
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));

      // Try primary query with retry logic
      try {
        final querySnapshot = await _executeQueryWithRetry(
          _firestore
              .collection('accessories_service_sales')
              .where('shopId', isEqualTo: _shopId)
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where('date', isLessThan: Timestamp.fromDate(endOfDay)),
        );

        if (querySnapshot.docs.isNotEmpty) {
          return true;
        }
      } on FirebaseException catch (firebaseError) {
        // If index error persists, try alternative query
        if (firebaseError.code == 'failed-precondition' &&
            firebaseError.message?.contains('index') == true) {
          return await _checkWithAlternativeQueryForUpload();
        } else {
          rethrow;
        }
      }
    } catch (error) {
      print('Error checking date data: $error');
      // If we can't check, allow upload anyway (fail-safe)
      return false;
    } finally {
      setState(() {
        _checkingDate = false;
      });
    }

    return false;
  }

  // Alternative query for upload check
  Future<bool> _checkWithAlternativeQueryForUpload() async {
    try {
      final querySnapshot = await _firestore
          .collection('accessories_service_sales')
          .where('shopId', isEqualTo: _shopId)
          .where(
            'dateString',
            isEqualTo: DateFormat('yyyy-MM-dd').format(_selectedDate),
          )
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Alternative query failed: $e');
      return false;
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

        // Reset data exists flag when date changes
        _dateHasDataForThisShop = false;
        _existingDateData.clear();
      });
    }
  }

  Future<void> _uploadToFirebase() async {
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

    // Check if data exists ONLY during upload
    setState(() => _checkingDate = true);
    bool dataExists = await _checkIfDataExistsForUpload();

    if (dataExists) {
      // Show warning that data already exists
      _showDataExistsWarning();
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

      // Prepare data for Firebase
      final accessoriesAmount = double.parse(_accessoriesAmountController.text);
      final serviceAmount = double.parse(_serviceAmountController.text);
      final cashAmount = double.parse(_cashAmountController.text);
      final gpayAmount = double.parse(_gpayAmountController.text);
      final cardAmount = double.parse(_cardAmountController.text);
      final notes = _notesController.text.trim();

      final saleData = {
        'date': Timestamp.fromDate(_selectedDate),
        'accessoriesAmount': accessoriesAmount,
        'serviceAmount': serviceAmount,
        'totalSaleAmount': _calculatedTotal,
        'cashAmount': cashAmount,
        'gpayAmount': gpayAmount,
        'cardAmount': cardAmount,
        'notes': notes,
        'salesPersonId': user.uid,
        'salesPersonEmail': user.email,
        'salesPersonName': user.displayName ?? user.email!.split('@')[0],
        'shopId': _shopId,
        'shopName': _shopName,
        'uploadedAt': FieldValue.serverTimestamp(),
        'type': 'accessories_service_sale',
        'year': _selectedDate.year,
        'month': _selectedDate.month,
        'day': _selectedDate.day,
        'dateString': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'shopId_date_composite':
            '${_shopId}_${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
        'paymentVerified': false,
        'paymentBreakdownVerified': {
          'cash': false,
          'gpay': false,
          'card': false,
        },
      };

      // Upload to Firestore
      await _firestore.collection('accessories_service_sales').add(saleData);

      // Show success message
      if (mounted) {
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
      }

      // Clear form and update state
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

        // Set that data now exists for this shop and date
        _dateHasDataForThisShop = true;

        // Add the uploaded data to existing data list
        _existingDateData = [
          {
            'date': _selectedDate,
            'accessoriesAmount': accessoriesAmount,
            'serviceAmount': serviceAmount,
            'totalSaleAmount': _calculatedTotal,
            'cashAmount': cashAmount,
            'gpayAmount': gpayAmount,
            'cardAmount': cardAmount,
            'notes': notes,
            'shopName': _shopName,
            'shopId': _shopId,
            'uploadedAt': DateTime.now(),
          },
        ];
      });
    } on FirebaseException catch (firebaseError) {
      String errorMessage = 'Upload failed';

      if (firebaseError.code == 'failed-precondition') {
        errorMessage = 'Database is updating. Please try again in a moment.';
      } else if (firebaseError.code == 'permission-denied') {
        errorMessage = 'Permission denied. Please check your Firebase rules.';
      } else if (firebaseError.code.contains('index')) {
        errorMessage = 'Database index required. Please wait and try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase Error: $errorMessage'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _uploadToFirebase,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading: ${error.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showDataExistsWarning() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('Data Already Exists'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shop: $_shopName',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Data already exists for ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
            SizedBox(height: 8),
            Text(
              'Each shop can only upload once per day.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please select a different date to add new sales data.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Colors.green)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _selectDate();
            },
            child: Text('Change Date', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  // Widget for Shop Information section
  Widget _buildShopInfoSection() {
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
                Icon(Icons.store, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Shop Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoadingShopData)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            else if (_shopId != null && _shopName != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    // Shop ID Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.badge,
                            size: 16,
                            color: Colors.blue.shade700,
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
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                _shopId!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800,
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
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.storefront,
                            size: 16,
                            color: Colors.blue.shade700,
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
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                _shopName!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800,
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
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Shop information not found. Please update your profile.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
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

  Widget _buildSuccessPreview() {
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
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Successfully Uploaded',
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
                      Icons.cloud_done,
                      color: Colors.green.shade400,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No data uploaded yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shop info
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.store,
                              size: 12,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _shopName ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        'Uploaded Successfully',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Amounts Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoChip(
                              'Accessories',
                              '₹${(_existingDateData[0]['accessoriesAmount'] as num).toStringAsFixed(0)}',
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildInfoChip(
                              'Service',
                              '₹${(_existingDateData[0]['serviceAmount'] as num).toStringAsFixed(0)}',
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildInfoChip(
                              'Total',
                              '₹${(_existingDateData[0]['totalSaleAmount'] as num).toStringAsFixed(0)}',
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
                              '₹${(_existingDateData[0]['cashAmount'] as num).toStringAsFixed(0)}',
                              Icons.money,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildPaymentChip(
                              'GPay',
                              '₹${(_existingDateData[0]['gpayAmount'] as num).toStringAsFixed(0)}',
                              Icons.phone_android,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildPaymentChip(
                              'Card',
                              '₹${(_existingDateData[0]['cardAmount'] as num).toStringAsFixed(0)}',
                              Icons.credit_card,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),

                      if (_existingDateData[0]['notes'] != null &&
                          _existingDateData[0]['notes'].toString().isNotEmpty)
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
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                _existingDateData[0]['notes'].toString(),
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

          // Upload Button - ALWAYS SHOW when form is valid
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed:
                  (_totalPayment == _calculatedTotal &&
                      !_isUploading &&
                      !_checkingDate &&
                      _shopId != null &&
                      _shopName != null)
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
            // Shop Information
            _buildShopInfoSection(),
            const SizedBox(height: 16),

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
            else if (_dateHasDataForThisShop)
              // Show success preview after upload
              Column(
                children: [
                  _buildSuccessPreview(),
                  const SizedBox(height: 16),
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
                          'Want to add more sales?',
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
              // Show form for new upload
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
