import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _allSales = [];
  List<Map<String, dynamic>> _filteredSales = [];
  bool _isLoading = true;
  String? _selectedEmiType;
  String _filterStatus = 'all'; // 'all', 'pending', 'approved', 'overdue'
  DateTime? _selectedDateRangeStart;
  DateTime? _selectedDateRangeEnd;

  // Statistics
  int _totalSales = 0;
  int _pendingVerification = 0;
  int _overduePayments = 0;
  double _totalAmountPending = 0.0;
  double _totalAmountApproved = 0.0;

  // Finance company filter list
  final List<String> _emiTypes = [
    'All EMI Types',
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

  // Color scheme
  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _secondaryColor = const Color(0xFF64748B);
  final Color _accentColor = const Color(0xFF10B981);
  final Color _backgroundColor = const Color(0xFFF8FAFC);
  final Color _errorColor = const Color(0xFFEF4444);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _infoColor = const Color(0xFF3B82F6);
  final Color _purpleColor = const Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _fetchSalesData();
    // Refresh data every 30 seconds
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _fetchSalesData();
        _startAutoRefresh();
      }
    });
  }

  Future<void> _fetchSalesData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final salesSnapshot = await _firestore
          .collection('sales')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> sales = [];
      int pendingCount = 0;
      int overdueCount = 0;
      double pendingAmount = 0.0;
      double approvedAmount = 0.0;

      for (var doc in salesSnapshot.docs) {
        final saleData = doc.data();
        final id = doc.id;

        // Process phone sales for payment verification
        final phoneSales = List<Map<String, dynamic>>.from(
          saleData['phoneSales'] ?? [],
        );

        // Check if any phone sale needs verification
        bool needsVerification = false;
        bool hasOverdue = false;

        for (var phoneSale in phoneSales) {
          // Check for payment verification status
          final purchaseMode = phoneSale['purchaseMode'] ?? '';
          final financeType = phoneSale['financeType'] ?? '';
          final downPayment =
              (phoneSale['downPayment'] as num?)?.toDouble() ?? 0.0;
          final disbursementAmount =
              (phoneSale['disbursementAmount'] as num?)?.toDouble() ?? 0.0;

          // Check if verification is needed
          if (purchaseMode == 'EMI') {
            final downPaymentReceived =
                phoneSale['downPaymentReceived'] ?? false;
            final disbursementReceived =
                phoneSale['disbursementReceived'] ?? false;
            final verified = phoneSale['verified'] ?? false;

            if (!verified) {
              needsVerification = true;
              pendingAmount += downPayment + disbursementAmount;
            } else {
              approvedAmount += downPayment + disbursementAmount;
            }

            // Check for overdue (more than 7 days without verification)
            final saleDate = (saleData['saleDate'] as Timestamp?)?.toDate();
            if (saleDate != null) {
              final daysSinceSale = DateTime.now().difference(saleDate).inDays;
              if (daysSinceSale > 7 && !verified) {
                hasOverdue = true;
                overdueCount++;
              }
            }
          }
        }

        if (needsVerification) {
          pendingCount++;
        }

        sales.add({
          'id': id,
          ...saleData,
          'needsVerification': needsVerification,
          'hasOverdue': hasOverdue,
          'phoneSales': phoneSales,
        });
      }

      setState(() {
        _allSales = sales;
        _filteredSales = List.from(sales);
        _totalSales = sales.length;
        _pendingVerification = pendingCount;
        _overduePayments = overdueCount;
        _totalAmountPending = pendingAmount;
        _totalAmountApproved = approvedAmount;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching sales data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allSales);

    // Filter by EMI type
    if (_selectedEmiType != null && _selectedEmiType != 'All EMI Types') {
      filtered = filtered.where((sale) {
        final phoneSales = List<Map<String, dynamic>>.from(
          sale['phoneSales'] ?? [],
        );
        return phoneSales.any((phoneSale) {
          final financeType = phoneSale['financeType'] ?? '';
          final purchaseMode = phoneSale['purchaseMode'] ?? '';
          return purchaseMode == 'EMI' && financeType == _selectedEmiType;
        });
      }).toList();
    }

    // Filter by status
    if (_filterStatus == 'pending') {
      filtered = filtered
          .where((sale) => sale['needsVerification'] == true)
          .toList();
    } else if (_filterStatus == 'approved') {
      filtered = filtered.where((sale) {
        final phoneSales = List<Map<String, dynamic>>.from(
          sale['phoneSales'] ?? [],
        );
        return phoneSales.every((phoneSale) => phoneSale['verified'] == true);
      }).toList();
    } else if (_filterStatus == 'overdue') {
      filtered = filtered.where((sale) => sale['hasOverdue'] == true).toList();
    }

    // Filter by date range
    if (_selectedDateRangeStart != null && _selectedDateRangeEnd != null) {
      filtered = filtered.where((sale) {
        final saleDate = (sale['saleDate'] as Timestamp?)?.toDate();
        if (saleDate == null) return false;
        return saleDate.isAfter(_selectedDateRangeStart!) &&
            saleDate.isBefore(
              _selectedDateRangeEnd!.add(const Duration(days: 1)),
            );
      }).toList();
    }

    setState(() {
      _filteredSales = filtered;
    });
  }

  Future<void> _verifyPayment(
    String saleId,
    String phoneSaleId,
    String
    paymentType, // 'downPayment' or 'disbursement' or 'cash' or 'gpay' or 'card'
  ) async {
    try {
      // Find the sale document
      final saleDoc = await _firestore.collection('sales').doc(saleId).get();
      if (!saleDoc.exists) return;

      final saleData = saleDoc.data() as Map<String, dynamic>;
      final phoneSales = List<Map<String, dynamic>>.from(
        saleData['phoneSales'] ?? [],
      );

      // Get current user and timestamp
      final currentUser = _auth.currentUser;
      final currentTime = DateTime.now();

      // Find and update the specific phone sale
      final updatedPhoneSales = phoneSales.map((phoneSale) {
        if (phoneSale['id'] == phoneSaleId) {
          final updatedPhoneSale = Map<String, dynamic>.from(phoneSale);

          if (paymentType == 'downPayment') {
            updatedPhoneSale['downPaymentReceived'] = true;
          } else if (paymentType == 'disbursement') {
            updatedPhoneSale['disbursementReceived'] = true;
          } else if (paymentType == 'cash') {
            updatedPhoneSale['cashReceived'] = true;
          } else if (paymentType == 'gpay') {
            updatedPhoneSale['gpayReceived'] = true;
          } else if (paymentType == 'card') {
            updatedPhoneSale['cardReceived'] = true;
          }

          // Check if all payments are received based on purchase mode
          final purchaseMode = updatedPhoneSale['purchaseMode'] ?? '';

          if (purchaseMode == 'EMI') {
            final downPaymentReceived =
                updatedPhoneSale['downPaymentReceived'] ?? false;
            final disbursementReceived =
                updatedPhoneSale['disbursementReceived'] ?? false;
            final verified = downPaymentReceived && disbursementReceived;

            updatedPhoneSale['verified'] = verified;

            if (verified) {
              updatedPhoneSale['verifiedBy'] = currentUser?.email;
              updatedPhoneSale['verifiedAt'] = currentTime.toIso8601String();
            }
          } else if (purchaseMode == 'Ready Cash') {
            final paymentBreakdown =
                updatedPhoneSale['paymentBreakdown'] as Map<String, dynamic>? ??
                {};
            final cashAmount =
                (paymentBreakdown['cash'] as num?)?.toDouble() ?? 0.0;
            final gpayAmount =
                (paymentBreakdown['gpay'] as num?)?.toDouble() ?? 0.0;
            final cardAmount =
                (paymentBreakdown['card'] as num?)?.toDouble() ?? 0.0;

            final cashReceived = updatedPhoneSale['cashReceived'] ?? false;
            final gpayReceived = updatedPhoneSale['gpayReceived'] ?? false;
            final cardReceived = updatedPhoneSale['cardReceived'] ?? false;

            bool allReceived = true;
            if (cashAmount > 0 && !cashReceived) allReceived = false;
            if (gpayAmount > 0 && !gpayReceived) allReceived = false;
            if (cardAmount > 0 && !cardReceived) allReceived = false;

            updatedPhoneSale['verified'] = allReceived;

            if (allReceived) {
              updatedPhoneSale['verifiedBy'] = currentUser?.email;
              updatedPhoneSale['verifiedAt'] = currentTime.toIso8601String();
            }
          } else if (purchaseMode == 'Credit Card') {
            final cardReceived = updatedPhoneSale['cardReceived'] ?? false;
            updatedPhoneSale['verified'] = cardReceived;

            if (cardReceived) {
              updatedPhoneSale['verifiedBy'] = currentUser?.email;
              updatedPhoneSale['verifiedAt'] = currentTime.toIso8601String();
            }
          }

          return updatedPhoneSale;
        }
        return phoneSale;
      }).toList();

      // Update the sale document with current timestamp
      await _firestore.collection('sales').doc(saleId).update({
        'phoneSales': updatedPhoneSales,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _showMessage('Payment verified successfully!', isError: false);
      await _fetchSalesData(); // Refresh data
    } catch (e) {
      _showMessage('Failed to verify payment: $e');
    }
  }

  Future<void> _approveAllPayments(String saleId) async {
    try {
      final saleDoc = await _firestore.collection('sales').doc(saleId).get();
      if (!saleDoc.exists) return;

      final saleData = saleDoc.data() as Map<String, dynamic>;
      final phoneSales = List<Map<String, dynamic>>.from(
        saleData['phoneSales'] ?? [],
      );

      // Get current user and timestamp
      final currentUser = _auth.currentUser;
      final currentTime = DateTime.now();

      // Update all phone sales in this sale
      final updatedPhoneSales = phoneSales.map((phoneSale) {
        final updatedPhoneSale = Map<String, dynamic>.from(phoneSale);
        final purchaseMode = updatedPhoneSale['purchaseMode'] ?? '';

        // Mark all payments as received based on purchase mode
        if (purchaseMode == 'EMI') {
          updatedPhoneSale['downPaymentReceived'] = true;
          updatedPhoneSale['disbursementReceived'] = true;
        } else if (purchaseMode == 'Ready Cash') {
          updatedPhoneSale['cashReceived'] = true;
          updatedPhoneSale['gpayReceived'] = true;
          updatedPhoneSale['cardReceived'] = true;
        } else if (purchaseMode == 'Credit Card') {
          updatedPhoneSale['cardReceived'] = true;
        }

        updatedPhoneSale['verified'] = true;
        updatedPhoneSale['verifiedBy'] = currentUser?.email;
        updatedPhoneSale['verifiedAt'] = currentTime.toIso8601String();

        return updatedPhoneSale;
      }).toList();

      // Update the sale document
      await _firestore.collection('sales').doc(saleId).update({
        'phoneSales': updatedPhoneSales,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _showMessage('All payments approved!', isError: false);
      await _fetchSalesData();
    } catch (e) {
      _showMessage('Failed to approve payments: $e');
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

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start:
            _selectedDateRangeStart ??
            DateTime.now().subtract(const Duration(days: 30)),
        end: _selectedDateRangeEnd ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRangeStart = picked.start;
        _selectedDateRangeEnd = picked.end;
      });
      _applyFilters();
    }
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  label: 'Total Sales',
                  value: _totalSales.toString(),
                  icon: Icons.shopping_cart,
                  color: _primaryColor,
                ),
                _buildStatItem(
                  label: 'Pending Verification',
                  value: _pendingVerification.toString(),
                  icon: Icons.pending_actions,
                  color: _warningColor,
                ),
                _buildStatItem(
                  label: 'Overdue (>7 days)',
                  value: _overduePayments.toString(),
                  icon: Icons.warning,
                  color: _errorColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAmountStat(
                  label: 'Pending Amount',
                  amount: _totalAmountPending,
                  color: _warningColor,
                ),
                _buildAmountStat(
                  label: 'Approved Amount',
                  amount: _totalAmountApproved,
                  color: _accentColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: _secondaryColor)),
      ],
    );
  }

  Widget _buildAmountStat({
    required String label,
    required double amount,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: _secondaryColor)),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 12),

            // EMI Type Filter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EMI Type',
                  style: TextStyle(
                    fontSize: 14,
                    color: _secondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _secondaryColor.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedEmiType ?? 'All EMI Types',
                    items: _emiTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedEmiType = value;
                      });
                      _applyFilters();
                    },
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      border: InputBorder.none,
                    ),
                    isExpanded: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status Filter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 14,
                    color: _secondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildStatusChip('All', 'all'),
                    _buildStatusChip('Pending', 'pending'),
                    _buildStatusChip('Approved', 'approved'),
                    _buildStatusChip('Overdue', 'overdue'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date Range Filter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date Range',
                  style: TextStyle(
                    fontSize: 14,
                    color: _secondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _selectDateRange(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _secondaryColor.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: _primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedDateRangeStart == null
                                ? 'Select date range'
                                : '${DateFormat('dd/MM/yyyy').format(_selectedDateRangeStart!)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRangeEnd!)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: _secondaryColor,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: _primaryColor,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedDateRangeStart != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedDateRangeStart = null;
                                _selectedDateRangeEnd = null;
                              });
                              _applyFilters();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _secondaryColor.withOpacity(0.1),
                              foregroundColor: _secondaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Clear Date Filter'),
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
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final bool isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = selected ? value : 'all';
        });
        _applyFilters();
      },
      selectedColor: _primaryColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : _secondaryColor),
    );
  }

  Widget _buildPhoneSaleItem(Map<String, dynamic> phoneSale, String saleId) {
    final purchaseMode = phoneSale['purchaseMode'] ?? '';
    final financeType = phoneSale['financeType'] ?? '';
    final downPayment = (phoneSale['downPayment'] as num?)?.toDouble() ?? 0.0;
    final disbursementAmount =
        (phoneSale['disbursementAmount'] as num?)?.toDouble() ?? 0.0;
    final downPaymentReceived = phoneSale['downPaymentReceived'] ?? false;
    final disbursementReceived = phoneSale['disbursementReceived'] ?? false;
    final cashReceived = phoneSale['cashReceived'] ?? false;
    final gpayReceived = phoneSale['gpayReceived'] ?? false;
    final cardReceived = phoneSale['cardReceived'] ?? false;
    final verified = phoneSale['verified'] ?? false;
    final verifiedBy = phoneSale['verifiedBy'] ?? '';
    final verifiedAt = phoneSale['verifiedAt'] ?? '';
    final phoneSaleId = phoneSale['id'] ?? '';

    final paymentBreakdown =
        phoneSale['paymentBreakdown'] as Map<String, dynamic>? ?? {};
    final cashAmount = (paymentBreakdown['cash'] as num?)?.toDouble() ?? 0.0;
    final gpayAmount = (paymentBreakdown['gpay'] as num?)?.toDouble() ?? 0.0;
    final cardAmount = (paymentBreakdown['card'] as num?)?.toDouble() ?? 0.0;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${phoneSale['productName'] ?? ''} - ${phoneSale['variant'] ?? ''}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                      Text(
                        'Brand: ${phoneSale['brand'] ?? ''}'.toUpperCase(),
                        style: TextStyle(fontSize: 10, color: _secondaryColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getPurchaseModeColor(purchaseMode).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    purchaseMode,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getPurchaseModeColor(purchaseMode),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Price Information
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price: ₹${(phoneSale['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                      style: TextStyle(fontSize: 12, color: _secondaryColor),
                    ),
                    if (phoneSale['discount'] != null &&
                        (phoneSale['discount'] as num).toDouble() > 0)
                      Text(
                        'Discount: -₹${(phoneSale['discount'] as num).toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 11, color: _infoColor),
                      ),
                    Text(
                      'Effective: ₹${(phoneSale['effectivePrice'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _accentColor,
                      ),
                    ),
                  ],
                ),
                if (verified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified, size: 12, color: _accentColor),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 12,
                            color: _accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Verification details
            if (verified && verifiedBy.isNotEmpty && verifiedAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Verified by $verifiedBy on ${_formatDateTime(verifiedAt)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: _secondaryColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Payment Verification Section
            if (purchaseMode == 'EMI') ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finance: $financeType',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _purpleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPaymentVerificationCard(
                          label: 'Down Payment',
                          amount: downPayment,
                          received: downPaymentReceived,
                          color: const Color(0xFF34A853),
                          onVerify: () => _verifyPayment(
                            saleId,
                            phoneSaleId,
                            'downPayment',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPaymentVerificationCard(
                          label: 'Disbursement',
                          amount: disbursementAmount,
                          received: disbursementReceived,
                          color: const Color(0xFF4285F4),
                          onVerify: () => _verifyPayment(
                            saleId,
                            phoneSaleId,
                            'disbursement',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ] else if (purchaseMode == 'Ready Cash') ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Breakdown',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (cashAmount > 0)
                        Expanded(
                          child: _buildPaymentVerificationCard(
                            label: 'Cash',
                            amount: cashAmount,
                            received: cashReceived,
                            color: const Color(0xFF34A853),
                            onVerify: () =>
                                _verifyPayment(saleId, phoneSaleId, 'cash'),
                          ),
                        ),
                      if (cashAmount > 0 && gpayAmount > 0)
                        const SizedBox(width: 8),
                      if (gpayAmount > 0)
                        Expanded(
                          child: _buildPaymentVerificationCard(
                            label: 'GPay',
                            amount: gpayAmount,
                            received: gpayReceived,
                            color: const Color(0xFF4285F4),
                            onVerify: () =>
                                _verifyPayment(saleId, phoneSaleId, 'gpay'),
                          ),
                        ),
                      if ((cashAmount > 0 || gpayAmount > 0) && cardAmount > 0)
                        const SizedBox(width: 8),
                      if (cardAmount > 0)
                        Expanded(
                          child: _buildPaymentVerificationCard(
                            label: 'Card',
                            amount: cardAmount,
                            received: cardReceived,
                            color: const Color(0xFFFBBC05),
                            onVerify: () =>
                                _verifyPayment(saleId, phoneSaleId, 'card'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ] else if (purchaseMode == 'Credit Card') ...[
              _buildPaymentVerificationCard(
                label: 'Credit Card Payment',
                amount: (phoneSale['price'] as num?)?.toDouble() ?? 0.0,
                received: cardReceived,
                color: const Color(0xFFFBBC05),
                onVerify: () => _verifyPayment(saleId, phoneSaleId, 'card'),
              ),
            ],

            // Verification Status and Action
            if (!verified)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _approveAllPayments(saleId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_user, size: 16),
                            SizedBox(width: 8),
                            Text('Verify All Payments in this Sale'),
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
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('dd/MM/yyyy hh:mm a').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  Widget _buildPaymentVerificationCard({
    required String label,
    required double amount,
    required bool received,
    required Color color,
    required VoidCallback onVerify,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: received
            ? color.withOpacity(0.1)
            : _warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: received
              ? color.withOpacity(0.3)
              : _warningColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: received ? color : _warningColor,
                  ),
                ),
              ),
              if (received)
                Icon(Icons.check_circle, size: 16, color: color)
              else
                Icon(Icons.pending, size: 16, color: _warningColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: received ? color : _warningColor,
            ),
          ),
          if (!received)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(0, 30),
                  ),
                  child: Text(
                    'Mark as Received',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getPurchaseModeColor(String mode) {
    switch (mode) {
      case 'Ready Cash':
        return _accentColor;
      case 'Credit Card':
        return const Color(0xFFFBBC05);
      case 'EMI':
        return _purpleColor;
      default:
        return _primaryColor;
    }
  }

  Widget _buildSalesList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: 16),
            Text(
              'Loading sales data...',
              style: TextStyle(fontSize: 14, color: _secondaryColor),
            ),
          ],
        ),
      );
    }

    if (_filteredSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: _secondaryColor),
            const SizedBox(height: 16),
            Text(
              'No sales found',
              style: TextStyle(fontSize: 18, color: _secondaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(
                fontSize: 14,
                color: _secondaryColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _filteredSales.length,
      itemBuilder: (context, index) {
        final sale = _filteredSales[index];
        final saleId = sale['id'] ?? '';
        final shopName = sale['shopName'] ?? 'Unknown Shop';
        final saleDate = (sale['saleDate'] as Timestamp?)?.toDate();
        final phoneSales = List<Map<String, dynamic>>.from(
          sale['phoneSales'] ?? [],
        );
        final needsVerification = sale['needsVerification'] ?? false;
        final hasOverdue = sale['hasOverdue'] ?? false;
        final totalAmount = (sale['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final saleCreatedAt = _parseDateTime(sale['createdAt']);
        final saleUpdatedAt = _parseDateTime(sale['updatedAt']);

        // Calculate days since sale
        int daysSinceSale = 0;
        if (saleDate != null) {
          daysSinceSale = DateTime.now().difference(saleDate).inDays;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            initiallyExpanded: needsVerification || hasOverdue,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.store, color: _primaryColor, size: 20),
            ),
            title: Text(
              shopName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saleDate != null
                      ? DateFormat('dd MMM yyyy, hh:mm a').format(saleDate)
                      : 'Date not available',
                  style: TextStyle(fontSize: 12, color: _secondaryColor),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Total: ₹${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${daysSinceSale} day${daysSinceSale == 1 ? '' : 's'} ago',
                      style: TextStyle(
                        fontSize: 12,
                        color: daysSinceSale > 7
                            ? _errorColor
                            : _secondaryColor,
                        fontWeight: daysSinceSale > 7
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, size: 12, color: _errorColor),
                        const SizedBox(width: 4),
                        Text(
                          'Overdue',
                          style: TextStyle(
                            fontSize: 12,
                            color: _errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (needsVerification && !hasOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.pending, size: 12, color: _warningColor),
                        const SizedBox(width: 4),
                        Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 12,
                            color: _warningColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.expand_more),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    // Sale Details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Phone Sales (${phoneSales.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _secondaryColor,
                          ),
                        ),
                        if (needsVerification)
                          ElevatedButton(
                            onPressed: () => _approveAllPayments(saleId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified_user, size: 16),
                                SizedBox(width: 4),
                                Text('Approve All'),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Phone Sales List
                    ...phoneSales
                        .map(
                          (phoneSale) => _buildPhoneSaleItem(phoneSale, saleId),
                        )
                        .toList(),

                    // Sale Information
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _secondaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sale Information',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _secondaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sale ID:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _secondaryColor,
                                ),
                              ),
                              Text(
                                saleId.substring(0, 8),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (saleCreatedAt != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Created:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _secondaryColor,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy, hh:mm a',
                                  ).format(saleCreatedAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          if (saleUpdatedAt != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Updated:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _secondaryColor,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy, hh:mm a',
                                  ).format(saleUpdatedAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Status:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _secondaryColor,
                                ),
                              ),
                              Text(
                                needsVerification
                                    ? 'Pending Verification'
                                    : 'Verified',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: needsVerification
                                      ? _warningColor
                                      : _accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Overdue Warning
                    if (hasOverdue)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _errorColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: _errorColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment Overdue!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _errorColor,
                                    ),
                                  ),
                                  Text(
                                    'This sale is $daysSinceSale days old and payments are still pending verification.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _errorColor.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () =>
                                        _approveAllPayments(saleId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _errorColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text(
                                      'Urgent: Approve All Payments',
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
              ),
            ],
          ),
        );
      },
    );
  }

  DateTime? _parseDateTime(dynamic dateTimeValue) {
    try {
      if (dateTimeValue == null) return null;

      if (dateTimeValue is Timestamp) {
        return dateTimeValue.toDate();
      } else if (dateTimeValue is String) {
        return DateTime.parse(dateTimeValue);
      } else if (dateTimeValue is DateTime) {
        return dateTimeValue;
      }
      return null;
    } catch (e) {
      return null;
    }
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
            child: Icon(Icons.monetization_on, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Finance Team Dashboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Monitor and verify all shop payments',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Finance Dashboard'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSalesData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 20),

            // Statistics
            _buildStatsCard(),
            const SizedBox(height: 16),

            // Filters
            _buildFilters(),
            const SizedBox(height: 16),

            // Sales List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Shop Sales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredSales.length} sales',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildSalesList(),
            const SizedBox(height: 20),

            // Legend
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _secondaryColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Legend',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildLegendItem('Pending', _warningColor),
                      _buildLegendItem('Verified', _accentColor),
                      _buildLegendItem('Overdue', _errorColor),
                      _buildLegendItem('EMI', _purpleColor),
                      _buildLegendItem('Ready Cash', _accentColor),
                      _buildLegendItem('Credit Card', Color(0xFFFBBC05)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: _secondaryColor)),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
