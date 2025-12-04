import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _allSales = [];
  List<Map<String, dynamic>> _filteredPhoneSales = [];
  List<Map<String, dynamic>> _filteredAccessoriesServiceSales = [];
  bool _isLoading = true;
  String? _selectedEmiType;
  String _filterStatus = 'all'; // 'all', 'pending', 'approved', 'overdue'
  DateTime? _selectedDateRangeStart;
  DateTime? _selectedDateRangeEnd;

  // Tab Controller
  late TabController _tabController;

  // Statistics
  int _totalSales = 0;
  int _pendingVerification = 0;
  int _overduePayments = 0;
  double _totalAmountPending = 0.0;
  double _totalAmountApproved = 0.0;

  // Accessories & Service Statistics
  int _pendingAccessoriesServiceVerification = 0;
  double _totalAccessoriesServiceAmountPending = 0.0;
  double _totalAccessoriesServiceAmountApproved = 0.0;

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
  final Color _greenColor = const Color(0xFF10B981);
  final Color _yellowColor = const Color(0xFFFBBC05);
  final Color _orangeColor = const Color(0xFFF97316);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSalesData();
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

      int pendingAccessoriesServiceCount = 0;
      double pendingAccessoriesServiceAmount = 0.0;
      double approvedAccessoriesServiceAmount = 0.0;

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
          } else if (purchaseMode == 'Ready Cash' ||
              purchaseMode == 'Credit Card') {
            final verified = phoneSale['verified'] ?? false;
            final paymentBreakdown =
                phoneSale['paymentBreakdown'] as Map<String, dynamic>? ?? {};

            // Fixed calculation with proper parentheses
            final totalPayment =
                ((paymentBreakdown['cash'] as num?)?.toDouble() ?? 0.0) +
                ((paymentBreakdown['gpay'] as num?)?.toDouble() ?? 0.0) +
                ((paymentBreakdown['card'] as num?)?.toDouble() ?? 0.0) +
                ((paymentBreakdown['credit'] as num?)?.toDouble() ?? 0.0);

            if (!verified && totalPayment > 0) {
              needsVerification = true;
              pendingAmount += totalPayment;
            } else if (verified) {
              approvedAmount += totalPayment;
            }

            // Check for overdue
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

        // Check accessories and service payment verification
        final accessoriesSaleAmount =
            (saleData['accessoriesSaleAmount'] as num?)?.toDouble() ?? 0.0;
        final serviceAmount =
            (saleData['serviceAmount'] as num?)?.toDouble() ?? 0.0;
        final accessoriesServiceVerified =
            saleData['accessoriesServiceVerified'] ?? false;
        final accessoriesServiceTotal = accessoriesSaleAmount + serviceAmount;

        if (accessoriesServiceTotal > 0 && !accessoriesServiceVerified) {
          pendingAccessoriesServiceCount++;
          pendingAccessoriesServiceAmount += accessoriesServiceTotal;
        } else if (accessoriesServiceVerified) {
          approvedAccessoriesServiceAmount += accessoriesServiceTotal;
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
          'needsAccessoriesServiceVerification':
              accessoriesServiceTotal > 0 && !accessoriesServiceVerified,
          'accessoriesServiceTotal': accessoriesServiceTotal,
        });
      }

      setState(() {
        _allSales = sales;
        _filteredPhoneSales = List.from(sales);
        _filteredAccessoriesServiceSales = List.from(sales);
        _totalSales = sales.length;
        _pendingVerification = pendingCount;
        _overduePayments = overdueCount;
        _totalAmountPending = pendingAmount;
        _totalAmountApproved = approvedAmount;
        _pendingAccessoriesServiceVerification = pendingAccessoriesServiceCount;
        _totalAccessoriesServiceAmountPending = pendingAccessoriesServiceAmount;
        _totalAccessoriesServiceAmountApproved =
            approvedAccessoriesServiceAmount;
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
    List<Map<String, dynamic>> filteredPhoneSales = List.from(_allSales);
    List<Map<String, dynamic>> filteredAccessoriesServiceSales = List.from(
      _allSales,
    );

    // Filter by EMI type (for phone sales only)
    if (_selectedEmiType != null && _selectedEmiType != 'All EMI Types') {
      filteredPhoneSales = filteredPhoneSales.where((sale) {
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

    // Filter by status (for phone sales only)
    if (_filterStatus == 'pending') {
      filteredPhoneSales = filteredPhoneSales
          .where((sale) => sale['needsVerification'] == true)
          .toList();
      filteredAccessoriesServiceSales = filteredAccessoriesServiceSales
          .where((sale) => sale['needsAccessoriesServiceVerification'] == true)
          .toList();
    } else if (_filterStatus == 'approved') {
      filteredPhoneSales = filteredPhoneSales.where((sale) {
        final phoneSales = List<Map<String, dynamic>>.from(
          sale['phoneSales'] ?? [],
        );
        return phoneSales.every((phoneSale) => phoneSale['verified'] == true);
      }).toList();
      filteredAccessoriesServiceSales = filteredAccessoriesServiceSales
          .where((sale) => sale['accessoriesServiceVerified'] == true)
          .toList();
    } else if (_filterStatus == 'overdue') {
      filteredPhoneSales = filteredPhoneSales
          .where((sale) => sale['hasOverdue'] == true)
          .toList();
      // Accessories/Service don't have overdue concept yet
    }

    // Filter by date range
    if (_selectedDateRangeStart != null && _selectedDateRangeEnd != null) {
      filteredPhoneSales = filteredPhoneSales.where((sale) {
        final saleDate = (sale['saleDate'] as Timestamp?)?.toDate();
        if (saleDate == null) return false;
        return saleDate.isAfter(_selectedDateRangeStart!) &&
            saleDate.isBefore(
              _selectedDateRangeEnd!.add(const Duration(days: 1)),
            );
      }).toList();

      filteredAccessoriesServiceSales = filteredAccessoriesServiceSales.where((
        sale,
      ) {
        final saleDate = (sale['saleDate'] as Timestamp?)?.toDate();
        if (saleDate == null) return false;
        return saleDate.isAfter(_selectedDateRangeStart!) &&
            saleDate.isBefore(
              _selectedDateRangeEnd!.add(const Duration(days: 1)),
            );
      }).toList();
    }

    setState(() {
      _filteredPhoneSales = filteredPhoneSales;
      _filteredAccessoriesServiceSales = filteredAccessoriesServiceSales;
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

      _showMessage('All phone payments approved!', isError: false);
      await _fetchSalesData();
    } catch (e) {
      _showMessage('Failed to approve payments: $e');
    }
  }

  Future<void> _approveAccessoriesService(String saleId) async {
    try {
      final currentUser = _auth.currentUser;
      final currentTime = DateTime.now();

      await _firestore.collection('sales').doc(saleId).update({
        'accessoriesServiceVerified': true,
        'accessoriesServiceVerifiedBy': currentUser?.email,
        'accessoriesServiceVerifiedAt': currentTime.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _showMessage('Accessories & Service amount approved!', isError: false);
      await _fetchSalesData();
    } catch (e) {
      _showMessage('Failed to approve accessories & service amount: $e');
    }
  }

  Future<void> _showPaymentBreakdownExplanation(
    BuildContext context,
    String purchaseMode,
  ) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '$purchaseMode Payment Breakdown',
          style: TextStyle(color: _primaryColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (purchaseMode == 'Ready Cash')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready Cash Payment Calculation:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('• Total Payment = Cash + GPay + Card + Credit'),
                  Text('• Each payment type is verified separately'),
                  Text(
                    '• All payment types must be received to mark as verified',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Example:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _secondaryColor,
                    ),
                  ),
                  Text('Phone Price: ₹10,000'),
                  Text('Exchange Value: ₹3,000'),
                  Text('Balance Returned: ₹1,000 (if any)'),
                  Text('Effective Price: ₹6,000'),
                  Text('Payment Breakdown:'),
                  Text('  - Cash: ₹2,000'),
                  Text('  - GPay: ₹2,000'),
                  Text('  - Card: ₹2,000'),
                  Text('  - Credit: ₹0'),
                  const SizedBox(height: 8),
                  Text(
                    'Verification:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                    ),
                  ),
                  Text(
                    'Each payment type (Cash, GPay, Card) must be marked as received separately.',
                  ),
                ],
              )
            else if (purchaseMode == 'EMI')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EMI Payment Calculation:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('• Down Payment: Initial payment made by customer'),
                  Text(
                    '• Disbursement Amount: Amount received from finance company',
                  ),
                  Text('• Both payments must be received to mark as verified'),
                  const SizedBox(height: 8),
                  Text(
                    'Example:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _secondaryColor,
                    ),
                  ),
                  Text('Phone Price: ₹20,000'),
                  Text('Down Payment: ₹5,000 (paid by customer)'),
                  Text('Disbursement: ₹15,000 (from finance company)'),
                  Text('Finance Company: Bajaj Finance'),
                  const SizedBox(height: 8),
                  Text(
                    'Verification Process:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                    ),
                  ),
                  Text('1. Verify Down Payment when customer pays'),
                  Text(
                    '2. Verify Disbursement when finance company releases funds',
                  ),
                  Text(
                    '3. Sale is marked verified only when BOTH payments are received',
                  ),
                ],
              )
            else if (purchaseMode == 'Credit Card')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Credit Card Payment Calculation:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('• Full payment made through credit card'),
                  Text('• Card payment must be received to mark as verified'),
                  Text('• Usually processed through POS machine'),
                  const SizedBox(height: 8),
                  Text(
                    'Verification:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                    ),
                  ),
                  Text(
                    'Card payment receipt must be verified to mark sale as completed.',
                  ),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: _primaryColor)),
          ),
        ],
      ),
    );
  }

  // NEW FUNCTION: Show Downpayment Breakdown
  Future<void> _showDownPaymentBreakdown(
    BuildContext context,
    Map<String, dynamic> phoneSaleData,
  ) async {
    print(phoneSaleData);
    final purchaseMode = phoneSaleData['purchaseMode'] ?? '';
    final price = (phoneSaleData['price'] as num?)?.toDouble() ?? 0.0;
    final effectivePrice =
        (phoneSaleData['effectivePrice'] as num?)?.toDouble() ?? 0.0;
    final exchangeValue =
        (phoneSaleData['exchangeValue'] as num?)?.toDouble() ?? 0.0;
    final discount = (phoneSaleData['discount'] as num?)?.toDouble() ?? 0.0;
    final downPayment =
        (phoneSaleData['downPayment'] as num?)?.toDouble() ?? 0.0;
    final disbursementAmount =
        (phoneSaleData['disbursementAmount'] as num?)?.toDouble() ?? 0.0;
    final amountToPay =
        (phoneSaleData['amountToPay'] as num?)?.toDouble() ?? 0.0;
    final balanceReturned =
        (phoneSaleData['balanceReturnedToCustomer'] as num?)?.toDouble() ?? 0.0;
    final customerCredit =
        (phoneSaleData['customerCredit'] as num?)?.toDouble() ?? 0.0;
    final financeType = phoneSaleData['financeType'] ?? '';

    // For Ready Cash/Regular payments
    final paymentBreakdown =
        phoneSaleData['paymentBreakdown'] as Map<String, dynamic>? ?? {};
    final cashAmount = (paymentBreakdown['cash'] as num?)?.toDouble() ?? 0.0;
    final gpayAmount = (paymentBreakdown['gpay'] as num?)?.toDouble() ?? 0.0;
    final cardAmount = (paymentBreakdown['card'] as num?)?.toDouble() ?? 0.0;
    final creditAmount =
        (paymentBreakdown['credit'] as num?)?.toDouble() ?? 0.0;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              'Payment Breakdown',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (purchaseMode == 'EMI') ...[
                Text(
                  'EMI Payment Breakdown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _secondaryColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Price Calculation
                Text(
                  'Price Calculation:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _secondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                _buildBreakdownRow(
                  label: 'Phone Price',
                  value: price,
                  color: _secondaryColor,
                ),
                _buildBreakdownRow(
                  label: 'Downpayment',
                  value: downPayment,
                  color: const Color(0xFF34A853),
                ),
                if (exchangeValue > 0)
                  _buildBreakdownRow(
                    label: 'Exchange Value',
                    value: -exchangeValue,
                    color: _infoColor,
                    isNegative: true,
                  ),
                if (discount > 0)
                  _buildBreakdownRow(
                    label: 'Discount',
                    value: -discount,
                    color: _accentColor,
                    isNegative: true,
                  ),

                // Finance Details

                // Payment Calculation
                Divider(color: _secondaryColor.withOpacity(0.3)),
                _buildBreakdownRow(
                  label: 'Total Payment',
                  value: downPayment - discount - exchangeValue,
                  color: _primaryColor,
                  isBold: true,
                ),

                if (balanceReturned > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _greenColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Balance Returned to Customer:',
                            style: TextStyle(
                              fontSize: 12,
                              color: _greenColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹${balanceReturned.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _greenColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (customerCredit > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _purpleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Customer Credit:',
                            style: TextStyle(
                              fontSize: 12,
                              color: _purpleColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹${customerCredit.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _purpleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Divider(color: _secondaryColor.withOpacity(0.3)),

                Text(
                  'Payment Method:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _secondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                if (cashAmount > 0)
                  _buildBreakdownRow(
                    label: 'Cash',
                    value: cashAmount,
                    color: const Color(0xFF34A853),
                  ),
                if (gpayAmount > 0)
                  _buildBreakdownRow(
                    label: 'GPay',
                    value: gpayAmount,
                    color: const Color(0xFF4285F4),
                  ),
                if (cardAmount > 0)
                  _buildBreakdownRow(
                    label: 'Card',
                    value: cardAmount,
                    color: const Color(0xFFFBBC05),
                  ),
                if (creditAmount > 0)
                  _buildBreakdownRow(
                    label: 'Credit',
                    value: creditAmount,
                    color: const Color(0xFF8B5CF6),
                  ),
              ] else if (purchaseMode == 'Ready Cash') ...[
                Text(
                  'Ready Cash Payment Breakdown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _secondaryColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Price Calculation
                Text(
                  'Price Calculation:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _secondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                _buildBreakdownRow(
                  label: 'Phone Price',
                  value: price,
                  color: _secondaryColor,
                ),
                if (exchangeValue > 0)
                  _buildBreakdownRow(
                    label: 'Exchange Value',
                    value: -exchangeValue,
                    color: _infoColor,
                    isNegative: true,
                  ),
                if (discount > 0)
                  _buildBreakdownRow(
                    label: 'Discount',
                    value: -discount,
                    color: _accentColor,
                    isNegative: true,
                  ),
                Divider(color: _secondaryColor.withOpacity(0.3)),
                _buildBreakdownRow(
                  label: 'Effective Price',
                  value: effectivePrice,
                  color: _primaryColor,
                  isBold: true,
                ),
                const SizedBox(height: 16),

                // Payment Methods
                Text(
                  'Payment Methods:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _secondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                if (cashAmount > 0)
                  _buildBreakdownRow(
                    label: 'Cash',
                    value: cashAmount,
                    color: const Color(0xFF34A853),
                  ),
                if (gpayAmount > 0)
                  _buildBreakdownRow(
                    label: 'GPay',
                    value: gpayAmount,
                    color: const Color(0xFF4285F4),
                  ),
                if (cardAmount > 0)
                  _buildBreakdownRow(
                    label: 'Card',
                    value: cardAmount,
                    color: const Color(0xFFFBBC05),
                  ),
                if (creditAmount > 0)
                  _buildBreakdownRow(
                    label: 'Credit',
                    value: creditAmount,
                    color: const Color(0xFF8B5CF6),
                  ),
                Divider(color: _secondaryColor.withOpacity(0.3)),
                _buildBreakdownRow(
                  label: 'Total Payment',
                  value: cashAmount + gpayAmount + cardAmount + creditAmount,
                  color: _primaryColor,
                  isBold: true,
                ),

                // Additional Information
                if (amountToPay > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Remaining to Pay:',
                            style: TextStyle(
                              fontSize: 12,
                              color: _warningColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹${amountToPay.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _warningColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (balanceReturned > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _greenColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Balance Returned to Customer:',
                            style: TextStyle(
                              fontSize: 12,
                              color: _greenColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹${balanceReturned.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _greenColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Formula
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
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
                          'Calculation Formula:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Effective Price = Phone Price - Exchange Value - Discount',
                          style: TextStyle(
                            fontSize: 11,
                            color: _secondaryColor,
                          ),
                        ),
                        Text(
                          'Total Payment = Cash + GPay + Card + Credit',
                          style: TextStyle(
                            fontSize: 11,
                            color: _secondaryColor,
                          ),
                        ),
                        Text(
                          'Balance Returned = (Exchange Value + Total Payment) - Effective Price',
                          style: TextStyle(
                            fontSize: 11,
                            color: _secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: _primaryColor)),
          ),
        ],
      ),
    );
  }

  // Helper function for breakdown rows
  Widget _buildBreakdownRow({
    required String label,
    required double value,
    required Color color,
    bool isNegative = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _secondaryColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${isNegative ? '-' : ''}₹${value.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      // Navigate to login screen - you need to replace with your actual login route
      // Navigator.pushReplacementNamed(context, '/login');
      _showMessage('Logged out successfully!', isError: false);

      // Show a dialog that logout was successful
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logged Out'),
          content: const Text('You have been successfully logged out.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // You can add navigation to login screen here
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showMessage('Failed to logout: $e');
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
            // Phone Sales Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  label: 'Phone Sales',
                  value: _totalSales.toString(),
                  icon: Icons.smartphone,
                  color: _primaryColor,
                ),
                _buildStatItem(
                  label: 'Pending Phone',
                  value: _pendingVerification.toString(),
                  icon: Icons.pending_actions,
                  color: _warningColor,
                ),
                _buildStatItem(
                  label: 'Overdue Phone',
                  value: _overduePayments.toString(),
                  icon: Icons.warning,
                  color: _errorColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Accessories & Service Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // _buildStatItem(
                //   label: 'Pending A&S',
                //   value: _pendingAccessoriesServiceVerification.toString(),
                //   icon: Icons.shopping_bag,
                //   color: _orangeColor,
                // ),
                _buildAmountStat(
                  label: 'Pending Phone Amount',
                  amount: _totalAmountPending,
                  color: _warningColor,
                ),
                // _buildAmountStat(
                //   label: 'Pending A&S Amount',
                //   amount: _totalAccessoriesServiceAmountPending,
                //   color: _orangeColor,
                // ),
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
        Text(
          label,
          style: TextStyle(fontSize: 10, color: _secondaryColor),
          textAlign: TextAlign.center,
        ),
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
        Text(
          label,
          style: TextStyle(fontSize: 11, color: _secondaryColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
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

            // EMI Type Filter (only for phone sales tab)
            if (_tabController.index == 0)
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
                      border: Border.all(
                        color: _secondaryColor.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedEmiType ?? 'All EMI Types',
                      items: _emiTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            type,
                            style: const TextStyle(fontSize: 14),
                          ),
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
            if (_tabController.index == 0) const SizedBox(height: 12),

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
                    if (_tabController.index == 0)
                      _buildStatusChip('Approved', 'approved'),
                    if (_tabController.index == 0)
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

    // New fields
    final balanceReturnedToCustomer =
        (phoneSale['balanceReturnedToCustomer'] as num?)?.toDouble() ?? 0.0;
    final exchangeValue =
        (phoneSale['exchangeValue'] as num?)?.toDouble() ?? 0.0;
    final amountToPay = (phoneSale['amountToPay'] as num?)?.toDouble() ?? 0.0;
    final customerCredit =
        (phoneSale['customerCredit'] as num?)?.toDouble() ?? 0.0;

    final paymentBreakdown =
        phoneSale['paymentBreakdown'] as Map<String, dynamic>? ?? {};
    final cashAmount = (paymentBreakdown['cash'] as num?)?.toDouble() ?? 0.0;
    final gpayAmount = (paymentBreakdown['gpay'] as num?)?.toDouble() ?? 0.0;
    final cardAmount = (paymentBreakdown['card'] as num?)?.toDouble() ?? 0.0;
    final creditAmount =
        (paymentBreakdown['credit'] as num?)?.toDouble() ?? 0.0;

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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getPurchaseModeColor(
                          purchaseMode,
                        ).withOpacity(0.1),
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
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: _infoColor,
                      ),
                      onPressed: () => _showPaymentBreakdownExplanation(
                        context,
                        purchaseMode,
                      ),
                      tooltip: 'Payment Breakdown Explanation',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Price Information with Balance Returned
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price: ₹${(phoneSale['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _secondaryColor,
                          ),
                        ),
                        if (exchangeValue > 0)
                          Text(
                            'Exchange Value: ₹${exchangeValue.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 11, color: _infoColor),
                          ),
                        if (phoneSale['discount'] != null &&
                            (phoneSale['discount'] as num).toDouble() > 0)
                          Text(
                            'Discount: -₹${(phoneSale['discount'] as num).toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 11, color: _infoColor),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Effective: ₹${(phoneSale['effectivePrice'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _accentColor,
                          ),
                        ),
                        if (amountToPay > 0)
                          Text(
                            'To Pay: ₹${amountToPay.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: _warningColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Balance Returned and Customer Credit
                if (balanceReturnedToCustomer > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _greenColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _greenColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Balance Returned to Customer:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _greenColor,
                          ),
                        ),
                        Text(
                          '₹${balanceReturnedToCustomer.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _greenColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (customerCredit > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _purpleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _purpleColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Customer Credit:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _purpleColor,
                          ),
                        ),
                        Text(
                          '₹${customerCredit.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _purpleColor,
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
                  Row(
                    children: [
                      Text(
                        'Finance: $financeType',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _purpleColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.info_outline,
                          size: 14,
                          color: _infoColor,
                        ),
                        onPressed: () => _showPaymentBreakdownExplanation(
                          context,
                          purchaseMode,
                        ),
                        tooltip: 'EMI Payment Explanation',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
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
                          isDownPayment: true,
                          phoneSaleData: phoneSale,
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
                  Row(
                    children: [
                      Text(
                        'Payment Breakdown',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.info_outline,
                          size: 14,
                          color: _infoColor,
                        ),
                        onPressed: () => _showPaymentBreakdownExplanation(
                          context,
                          purchaseMode,
                        ),
                        tooltip: 'Ready Cash Payment Explanation',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Show Payment Breakdown Summary
                  if (cashAmount > 0 ||
                      gpayAmount > 0 ||
                      cardAmount > 0 ||
                      creditAmount > 0)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _secondaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (cashAmount > 0)
                            _buildPaymentBreakdownRow(
                              label: 'Cash',
                              amount: cashAmount,
                              color: const Color(0xFF34A853),
                              received: cashReceived,
                            ),
                          if (gpayAmount > 0)
                            _buildPaymentBreakdownRow(
                              label: 'GPay',
                              amount: gpayAmount,
                              color: const Color(0xFF4285F4),
                              received: gpayReceived,
                            ),
                          if (cardAmount > 0)
                            _buildPaymentBreakdownRow(
                              label: 'Card',
                              amount: cardAmount,
                              color: const Color(0xFFFBBC05),
                              received: cardReceived,
                            ),
                          if (creditAmount > 0)
                            _buildPaymentBreakdownRow(
                              label: 'Credit',
                              amount: creditAmount,
                              color: const Color(0xFF8B5CF6),
                              received:
                                  true, // Credit is always considered received
                            ),
                        ],
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildPaymentVerificationCard(
                          label: 'Credit Card Payment',
                          amount:
                              (phoneSale['price'] as num?)?.toDouble() ?? 0.0,
                          received: cardReceived,
                          color: const Color(0xFFFBBC05),
                          onVerify: () =>
                              _verifyPayment(saleId, phoneSaleId, 'card'),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.info_outline,
                          size: 16,
                          color: _infoColor,
                        ),
                        onPressed: () => _showPaymentBreakdownExplanation(
                          context,
                          purchaseMode,
                        ),
                        tooltip: 'Credit Card Payment Explanation',
                        padding: const EdgeInsets.only(left: 8),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
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

  // UPDATED: Payment Verification Card with downpayment breakdown icon
  Widget _buildPaymentVerificationCard({
    required String label,
    required double amount,
    required bool received,
    required Color color,
    required VoidCallback onVerify,
    bool isDownPayment = false,
    Map<String, dynamic>? phoneSaleData,
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
              Row(
                children: [
                  // Add info icon for downpayment breakdown
                  if (isDownPayment && phoneSaleData != null)
                    IconButton(
                      icon: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: _infoColor,
                      ),
                      onPressed: () =>
                          _showDownPaymentBreakdown(context, phoneSaleData),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Show Payment Breakdown',
                    ),
                  if (received)
                    Icon(Icons.check_circle, size: 16, color: color),
                  // else
                  //   Icon(Icons.pending, size: 16, color: _warningColor),
                ],
              ),
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

  Widget _buildAccessoriesServiceItem(Map<String, dynamic> sale) {
    final saleId = sale['id'] ?? '';
    final shopName = sale['shopName'] ?? 'Unknown Shop';
    final saleDate = (sale['saleDate'] as Timestamp?)?.toDate();
    final accessoriesSaleAmount =
        (sale['accessoriesSaleAmount'] as num?)?.toDouble() ?? 0.0;
    final serviceAmount = (sale['serviceAmount'] as num?)?.toDouble() ?? 0.0;
    final accessoriesServiceVerified =
        sale['accessoriesServiceVerified'] ?? false;
    final accessoriesServiceVerifiedBy =
        sale['accessoriesServiceVerifiedBy'] ?? '';
    final accessoriesServiceVerifiedAt =
        sale['accessoriesServiceVerifiedAt'] ?? '';
    final totalAmount = (sale['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final paymentTotal = (sale['paymentTotal'] as num?)?.toDouble() ?? 0.0;
    final cashAmount = (sale['cashAmount'] as num?)?.toDouble() ?? 0.0;
    final cardAmount = (sale['cardAmount'] as num?)?.toDouble() ?? 0.0;
    final gpayAmount = (sale['gpayAmount'] as num?)?.toDouble() ?? 0.0;

    final saleCreatedAt = _parseDateTime(sale['createdAt']);
    final saleUpdatedAt = _parseDateTime(sale['updatedAt']);
    final userEmail = sale['userEmail'] ?? 'Unknown';

    // Calculate days since sale
    int daysSinceSale = 0;
    if (saleDate != null) {
      daysSinceSale = DateTime.now().difference(saleDate).inDays;
    }

    final accessoriesServiceTotal = accessoriesSaleAmount + serviceAmount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: !accessoriesServiceVerified,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _orangeColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.shopping_bag, color: _orangeColor, size: 20),
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
                  'A&S Total: ₹${accessoriesServiceTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _orangeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${daysSinceSale} day${daysSinceSale == 1 ? '' : 's'} ago',
                  style: TextStyle(
                    fontSize: 12,
                    color: daysSinceSale > 7 ? _errorColor : _secondaryColor,
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
            if (!accessoriesServiceVerified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Sale Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _secondaryColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Accessories & Service Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Accessories Sale Amount',
                        '₹${accessoriesSaleAmount.toStringAsFixed(2)}',
                        _secondaryColor,
                      ),
                      _buildSummaryRow(
                        'Service Amount',
                        '₹${serviceAmount.toStringAsFixed(2)}',
                        _secondaryColor,
                      ),
                      _buildSummaryRow(
                        'Total A&S Amount',
                        '₹${accessoriesServiceTotal.toStringAsFixed(2)}',
                        _orangeColor,
                        isBold: true,
                      ),
                      const Divider(color: Colors.grey),
                      _buildSummaryRow(
                        'Total Sale Amount',
                        '₹${totalAmount.toStringAsFixed(2)}',
                        _accentColor,
                      ),
                    ],
                  ),
                ),

                // Payment Breakdown
                if (paymentTotal > 0)
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
                          'Payment Breakdown',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (cashAmount > 0)
                          _buildPaymentRow(
                            'Cash',
                            cashAmount,
                            const Color(0xFF34A853),
                          ),
                        if (gpayAmount > 0)
                          _buildPaymentRow(
                            'GPay',
                            gpayAmount,
                            const Color(0xFF4285F4),
                          ),
                        if (cardAmount > 0)
                          _buildPaymentRow(
                            'Card',
                            cardAmount,
                            const Color(0xFFFBBC05),
                          ),
                        const Divider(color: Colors.grey),
                        _buildPaymentRow(
                          'Total Received',
                          paymentTotal,
                          _accentColor,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),

                // Verification details
                if (accessoriesServiceVerified &&
                    accessoriesServiceVerifiedBy.isNotEmpty &&
                    accessoriesServiceVerifiedAt.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _accentColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified, color: _accentColor, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Verified by $accessoriesServiceVerifiedBy on ${_formatDateTime(accessoriesServiceVerifiedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Approve Button
                if (!accessoriesServiceVerified)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    child: ElevatedButton(
                      onPressed: () => _approveAccessoriesService(saleId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orangeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Approve Accessories & Service Amount',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Sale Information
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _secondaryColor.withOpacity(0.2)),
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
                            accessoriesServiceVerified
                                ? 'Verified'
                                : 'Pending Verification',
                            style: TextStyle(
                              fontSize: 12,
                              color: accessoriesServiceVerified
                                  ? _accentColor
                                  : _warningColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Salesperson:',
                            style: TextStyle(
                              fontSize: 12,
                              color: _secondaryColor,
                            ),
                          ),
                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: 12,
                              color: _primaryColor,
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
    );
  }

  Widget _buildPaymentBreakdownRow({
    required String label,
    required double amount,
    required Color color,
    required bool received,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: _secondaryColor),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                received ? Icons.check_circle : Icons.pending,
                size: 14,
                color: received ? color : _warningColor,
              ),
            ],
          ),
        ],
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

  Color _getPurchaseModeColor(String mode) {
    switch (mode) {
      case 'Ready Cash':
        return _accentColor;
      case 'Credit Card':
        return _yellowColor;
      case 'EMI':
        return _purpleColor;
      default:
        return _primaryColor;
    }
  }

  Widget _buildPhoneSalesList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: 16),
            Text(
              'Loading phone sales data...',
              style: TextStyle(fontSize: 14, color: _secondaryColor),
            ),
          ],
        ),
      );
    }

    if (_filteredPhoneSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smartphone, size: 64, color: _secondaryColor),
            const SizedBox(height: 16),
            Text(
              'No phone sales found',
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
      itemCount: _filteredPhoneSales.length,
      itemBuilder: (context, index) {
        final sale = _filteredPhoneSales[index];
        final saleId = sale['id'] ?? '';
        final shopName = sale['shopName'] ?? 'Unknown Shop';
        final saleDate = (sale['saleDate'] as Timestamp?)?.toDate();
        final phoneSales = List<Map<String, dynamic>>.from(
          sale['phoneSales'] ?? [],
        );
        final needsVerification = sale['needsVerification'] ?? false;
        final hasOverdue = sale['hasOverdue'] ?? false;

        // New fields for total summary
        final totalAmount = (sale['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final totalAmountToPay =
            (sale['totalAmountToPay'] as num?)?.toDouble() ?? 0.0;
        final totalBalanceReturned =
            (sale['totalBalanceReturned'] as num?)?.toDouble() ?? 0.0;
        final totalCustomerCredit =
            (sale['totalCustomerCredit'] as num?)?.toDouble() ?? 0.0;
        final totalDisbursementAmount =
            (sale['totalDisbursementAmount'] as num?)?.toDouble() ?? 0.0;
        final totalExchangeValue =
            (sale['totalExchangeValue'] as num?)?.toDouble() ?? 0.0;
        final totalPhoneDiscount =
            (sale['totalPhoneDiscount'] as num?)?.toDouble() ?? 0.0;
        final totalPhoneSalesValue =
            (sale['totalPhoneSalesValue'] as num?)?.toDouble() ?? 0.0;
        final totalPhonesSold = (sale['totalPhonesSold'] as num?)?.toInt() ?? 0;

        final saleCreatedAt = _parseDateTime(sale['createdAt']);
        final saleUpdatedAt = _parseDateTime(sale['updatedAt']);
        final userEmail = sale['userEmail'] ?? 'Unknown';

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
                // Quick summary
                Text(
                  '$totalPhonesSold phone${totalPhonesSold == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: _secondaryColor),
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
                    // Sale Summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _secondaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Sale Summary',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            'Total Phones Sold',
                            '$totalPhonesSold',
                            _secondaryColor,
                          ),
                          _buildSummaryRow(
                            'Total Phone Sales Value',
                            '₹${totalPhoneSalesValue.toStringAsFixed(2)}',
                            _primaryColor,
                          ),
                          if (totalExchangeValue > 0)
                            _buildSummaryRow(
                              'Total Exchange Value',
                              '₹${totalExchangeValue.toStringAsFixed(2)}',
                              _infoColor,
                            ),
                          if (totalPhoneDiscount > 0)
                            _buildSummaryRow(
                              'Total Discount',
                              '₹${totalPhoneDiscount.toStringAsFixed(2)}',
                              _accentColor,
                            ),
                          // _buildSummaryRow(
                          //   'Total Amount to Pay',
                          //   '₹${totalAmountToPay.toStringAsFixed(2)}',
                          //   _warningColor,
                          // ),
                          if (totalDisbursementAmount > 0)
                            _buildSummaryRow(
                              'Total Disbursement Amount',
                              '₹${totalDisbursementAmount.toStringAsFixed(2)}',
                              _purpleColor,
                            ),
                          if (totalBalanceReturned > 0)
                            _buildSummaryRow(
                              'Total Balance Returned',
                              '₹${totalBalanceReturned.toStringAsFixed(2)}',
                              _greenColor,
                              isBold: true,
                            ),
                          if (totalCustomerCredit > 0)
                            _buildSummaryRow(
                              'Total Customer Credit',
                              '₹${totalCustomerCredit.toStringAsFixed(2)}',
                              _purpleColor,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Phone Sales ($totalPhonesSold)',
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
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Salesperson:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _secondaryColor,
                                ),
                              ),
                              Text(
                                userEmail,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _primaryColor,
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

  Widget _buildAccessoriesServiceList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: 16),
            Text(
              'Loading accessories & service data...',
              style: TextStyle(fontSize: 14, color: _secondaryColor),
            ),
          ],
        ),
      );
    }

    // Filter sales that have accessories or service amount
    final accessoriesServiceSales = _filteredAccessoriesServiceSales.where((
      sale,
    ) {
      final accessoriesSaleAmount =
          (sale['accessoriesSaleAmount'] as num?)?.toDouble() ?? 0.0;
      final serviceAmount = (sale['serviceAmount'] as num?)?.toDouble() ?? 0.0;
      return accessoriesSaleAmount > 0 || serviceAmount > 0;
    }).toList();

    if (accessoriesServiceSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag, size: 64, color: _secondaryColor),
            const SizedBox(height: 16),
            Text(
              'No accessories or service sales found',
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
      itemCount: accessoriesServiceSales.length,
      itemBuilder: (context, index) {
        return _buildAccessoriesServiceItem(accessoriesServiceSales[index]);
      },
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: _secondaryColor)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(
    String label,
    double amount,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: _secondaryColor),
              ),
            ],
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
              tooltip: 'Refresh Data',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                } else if (value == 'help') {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Payment Breakdown Help'),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Payment Calculation Formulas:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '📱 Ready Cash:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _accentColor,
                              ),
                            ),
                            Text('Total Payment = Cash + GPay + Card + Credit'),
                            Text(
                              'Amount to Pay = Effective Price - Total Payment',
                            ),
                            Text(
                              'Balance Returned = Exchange Value + Payments - Effective Price',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '🏦 EMI:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _purpleColor,
                              ),
                            ),
                            Text('Total Payment = Down Payment + Disbursement'),
                            Text(
                              'Amount to Pay = Effective Price - Total Payment',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '💳 Credit Card:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _yellowColor,
                              ),
                            ),
                            Text('Total Payment = Card Payment'),
                            const SizedBox(height: 12),
                            Text(
                              'Verification Process:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                            Text(
                              '• Each payment type must be marked as received',
                            ),
                            Text(
                              '• Sale is verified only when ALL payments are received',
                            ),
                            Text(
                              '• Finance team verifies actual money received vs. sale amount',
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(Icons.help_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Payment Help'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            unselectedLabelColor: const Color.fromARGB(255, 151, 148, 147),
            labelColor: const Color.fromARGB(255, 221, 243, 235),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.smartphone), text: 'Phone Sales'),
              Tab(
                icon: Icon(Icons.shopping_bag),
                text: 'Accessories & Service',
              ),
            ],
            onTap: (index) {
              setState(() {
                // Reset filters when switching tabs
                if (index == 1) {
                  _selectedEmiType = null;
                  _filterStatus = 'all';
                }
                _applyFilters();
              });
            },
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Phone Sales
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
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
                        'Phone Sales',
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
                          '${_filteredPhoneSales.length} sales',
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

                  _buildPhoneSalesList(),
                  const SizedBox(height: 20),

                  // Legend
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _secondaryColor.withOpacity(0.2),
                      ),
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
                            _buildLegendItem('Credit Card', _yellowColor),
                            _buildLegendItem('Balance Returned', _greenColor),
                            _buildLegendItem('Customer Credit', _purpleColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab 2: Accessories & Service
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Statistics for Accessories & Service
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem(
                                label: 'Pending A&S',
                                value: _pendingAccessoriesServiceVerification
                                    .toString(),
                                icon: Icons.pending_actions,
                                color: _warningColor,
                              ),
                              _buildStatItem(
                                label: 'Total A&S',
                                value: _allSales
                                    .where((sale) {
                                      final accessoriesSaleAmount =
                                          (sale['accessoriesSaleAmount']
                                                  as num?)
                                              ?.toDouble() ??
                                          0.0;
                                      final serviceAmount =
                                          (sale['serviceAmount'] as num?)
                                              ?.toDouble() ??
                                          0.0;
                                      return accessoriesSaleAmount > 0 ||
                                          serviceAmount > 0;
                                    })
                                    .length
                                    .toString(),
                                icon: Icons.shopping_bag,
                                color: _orangeColor,
                              ),
                              _buildAmountStat(
                                label: 'Pending A&S Amount',
                                amount: _totalAccessoriesServiceAmountPending,
                                color: _warningColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildAmountStat(
                                label: 'Approved A&S Amount',
                                amount: _totalAccessoriesServiceAmountApproved,
                                color: _accentColor,
                              ),
                              _buildAmountStat(
                                label: 'Total A&S Amount',
                                amount:
                                    _totalAccessoriesServiceAmountPending +
                                    _totalAccessoriesServiceAmountApproved,
                                color: _orangeColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filters
                  _buildFilters(),
                  const SizedBox(height: 16),

                  // Sales List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Accessories & Service',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _orangeColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _orangeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_filteredAccessoriesServiceSales.where((sale) {
                            final accessoriesSaleAmount = (sale['accessoriesSaleAmount'] as num?)?.toDouble() ?? 0.0;
                            final serviceAmount = (sale['serviceAmount'] as num?)?.toDouble() ?? 0.0;
                            return accessoriesSaleAmount > 0 || serviceAmount > 0;
                          }).length} sales',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _orangeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildAccessoriesServiceList(),
                  const SizedBox(height: 20),

                  // Legend
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _secondaryColor.withOpacity(0.2),
                      ),
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
                            _buildLegendItem(
                              'Accessories & Service',
                              _orangeColor,
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
    _tabController.dispose();
    super.dispose();
  }
}
