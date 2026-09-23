// lib/screens/admin/reports/tv_verification_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class TvVerificationTab extends StatefulWidget {
  final List<Map<String, dynamic>> filteredData;
  final List<Map<String, dynamic>> allData;
  final String? selectedShop;
  final List<String> availableShops;
  final Function(String?) onShopChanged;
  final Function(Map<String, dynamic>) onVerifyPayment;
  final String Function(Map<String, dynamic>) getShopName;
  final double Function(Map<String, dynamic>) getTotalAmount;
  final String Function(double) formatNumber;
  final String Function(dynamic) formatDate;
  final bool Function(dynamic) convertToBool;
  final Map<String, dynamic> Function(Map<String, dynamic>) createTransaction;

  const TvVerificationTab({
    Key? key,
    required this.filteredData,
    required this.allData,
    required this.selectedShop,
    required this.availableShops,
    required this.onShopChanged,
    required this.onVerifyPayment,
    required this.getShopName,
    required this.getTotalAmount,
    required this.formatNumber,
    required this.formatDate,
    required this.convertToBool,
    required this.createTransaction,
  }) : super(key: key);

  @override
  State<TvVerificationTab> createState() => _TvVerificationTabState();
}

class _TvVerificationTabState extends State<TvVerificationTab> {
  String? _selectedDateRange;

  /// In-flight operations. Key format:
  ///   "$docId:downPayment:*"        → verifying the whole Down Payment row
  ///   "$docId:downPayment:cash"     → toggling a single method
  ///   "$docId:disbursement:*"       → verifying the Disbursement row
  final Set<String> _busyKeys = {};

  /// Local overrides for per-method flags (only used for Down Payment).
  /// docId -> field -> method -> bool
  final Map<String, Map<String, Map<String, bool>>> _localMethodFlags = {};

  /// Local overrides for the parent-row flags.
  /// docId -> field -> bool
  final Map<String, Map<String, bool>> _localEmiFlags = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Date helpers ──
  DateTime? _parseSaleDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  List<Map<String, dynamic>> get _displayData {
    if (_selectedDateRange == null) return widget.filteredData;

    final now = DateTime.now();
    return widget.filteredData.where((sale) {
      final date = _parseSaleDate(
        sale['saleDate'] ??
            sale['createdAt'] ??
            sale['date'] ??
            sale['timestamp'],
      );
      if (date == null) return false;

      switch (_selectedDateRange) {
        case 'thisMonth':
          return date.year == now.year && date.month == now.month;
        case 'lastMonth':
          final lm = DateTime(now.year, now.month - 1);
          return date.year == lm.year && date.month == lm.month;
        case 'thisYear':
          return date.year == now.year;
        case 'lastYear':
          return date.year == now.year - 1;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = _displayData;

    return Column(
      children: [
        _buildVerificationSummary('TV Verification', data, widget.allData),
        const SizedBox(height: 8),
        _buildDateRangeFilter(),
        const SizedBox(height: 8),
        _buildShopFilter(
          widget.selectedShop,
          widget.availableShops,
          widget.onShopChanged,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: data.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tv_off, size: 40, color: Colors.grey[400]),
                      const SizedBox(height: 10),
                      const Text(
                        'No TV sales found for verification',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10.0),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: _buildTvSaleCard(data[index], context),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // State readers
  // ══════════════════════════════════════════════════════════════════════

  bool _isEmiRowVerified(Map<String, dynamic> sale, String field) {
    final docId = sale['id']?.toString() ?? '';
    final local = _localEmiFlags[docId];
    if (local != null && local.containsKey(field)) return local[field]!;

    if (field == 'downPayment') {
      return widget.convertToBool(sale['downPaymentVerified']) ||
          widget.convertToBool(sale['downPaymentReceived']);
    }
    return widget.convertToBool(sale['disbursementVerified']) ||
        widget.convertToBool(sale['disbursementReceived']);
  }

  /// Per-method verified flags for Down Payment only.
  Map<String, bool> _downPaymentMethodFlags(Map<String, dynamic> sale) {
    final docId = sale['id']?.toString() ?? '';
    final local = _localMethodFlags[docId]?['downPayment'];
    if (local != null) return local;

    final raw = sale['downPaymentPaymentBreakdownVerified'];
    final out = <String, bool>{
      'cash': false,
      'card': false,
      'gpay': false,
      'credit': false,
    };
    if (raw is Map) {
      out['cash'] = widget.convertToBool(raw['cash']);
      out['card'] = widget.convertToBool(raw['card']);
      out['gpay'] = widget.convertToBool(raw['gpay']);
      out['credit'] = widget.convertToBool(raw['credit']);
    }
    return out;
  }

  /// Payment amounts per method for Down Payment.
  Map<String, double> _downPaymentMethodAmounts(Map<String, dynamic> sale) {
    final pb = sale['paymentBreakdown'] as Map<String, dynamic>? ?? {};
    return {
      'cash': (pb['cash'] as num?)?.toDouble() ?? 0,
      'card': (pb['card'] as num?)?.toDouble() ?? 0,
      'gpay': (pb['gpay'] as num?)?.toDouble() ?? 0,
      'credit': (pb['credit'] as num?)?.toDouble() ?? 0,
    };
  }

  /// Returns the list of methods that have amount > 0, in a fixed order.
  List<String> _visibleMethodsForDownPayment(Map<String, dynamic> sale) {
    final amounts = _downPaymentMethodAmounts(sale);
    const order = ['cash', 'card', 'gpay', 'credit'];
    return order.where((m) => (amounts[m] ?? 0) > 0).toList();
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'gpay':
        return 'UPI';
      case 'credit':
        return 'Credit';
      default:
        return method;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // State writers
  // ══════════════════════════════════════════════════════════════════════

  /// Verify the entire Down Payment row (all visible methods true).
  Future<void> _verifyDownPaymentRow(Map<String, dynamic> sale) async {
    final docId = sale['id']?.toString() ?? '';
    if (docId.isEmpty) return;
    if (_isEmiRowVerified(sale, 'downPayment')) return;

    final key = '$docId:downPayment:*';
    setState(() => _busyKeys.add(key));

    try {
      final visible = _visibleMethodsForDownPayment(sale);
      final allTrue = {
        'cash': visible.contains('cash'),
        'card': visible.contains('card'),
        'gpay': visible.contains('gpay'),
        'credit': visible.contains('credit'),
      };

      final updates = <String, dynamic>{
        'downPaymentPaymentBreakdownVerified': allTrue,
        'downPaymentVerified': true,
        'downPaymentReceived': true,
      };

      await _firestore.collection('tvSales').doc(docId).update(updates);

      _localMethodFlags.putIfAbsent(docId, () => {})['downPayment'] = allTrue;
      _localEmiFlags.putIfAbsent(docId, () => {})['downPayment'] = true;
      sale.addAll(updates);

      await _maybeFinalizePayment(sale);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Down Payment verified',
              style: TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  /// Verify the Disbursement row (simple, no method breakdown).
  Future<void> _verifyDisbursementRow(Map<String, dynamic> sale) async {
    final docId = sale['id']?.toString() ?? '';
    if (docId.isEmpty) return;
    if (_isEmiRowVerified(sale, 'disbursement')) return;

    final key = '$docId:disbursement:*';
    setState(() => _busyKeys.add(key));

    try {
      final updates = <String, dynamic>{
        'disbursementVerified': true,
        'disbursementReceived': true,
      };

      await _firestore.collection('tvSales').doc(docId).update(updates);

      _localEmiFlags.putIfAbsent(docId, () => {})['disbursement'] = true;
      sale.addAll(updates);

      await _maybeFinalizePayment(sale);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Disbursement verified',
              style: TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  /// Toggle a single Down Payment method.
  Future<void> _toggleDownPaymentMethod(
    Map<String, dynamic> sale,
    String method,
  ) async {
    final docId = sale['id']?.toString() ?? '';
    if (docId.isEmpty) return;

    final key = '$docId:downPayment:$method';
    if (_busyKeys.contains(key)) return;
    setState(() => _busyKeys.add(key));

    try {
      final current = Map<String, bool>.from(_downPaymentMethodFlags(sale));
      final newValue = !(current[method] ?? false);
      current[method] = newValue;

      final updates = <String, dynamic>{
        'downPaymentPaymentBreakdownVerified': current,
      };

      // Only auto-flag the row when all *visible* methods are true.
      final visible = _visibleMethodsForDownPayment(sale);
      final allVisibleTrue =
          visible.isNotEmpty && visible.every((m) => current[m] == true);

      if (allVisibleTrue) {
        updates['downPaymentVerified'] = true;
        updates['downPaymentReceived'] = true;
        _localEmiFlags.putIfAbsent(docId, () => {})['downPayment'] = true;
      } else {
        updates['downPaymentVerified'] = false;
        updates['downPaymentReceived'] = false;
        _localEmiFlags.putIfAbsent(docId, () => {})['downPayment'] = false;
      }

      await _firestore.collection('tvSales').doc(docId).update(updates);

      _localMethodFlags.putIfAbsent(docId, () => {})['downPayment'] = current;
      sale.addAll(updates);

      await _maybeFinalizePayment(sale);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Future<void> _maybeFinalizePayment(Map<String, dynamic> sale) async {
    final docId = sale['id']?.toString() ?? '';
    if (docId.isEmpty) return;

    final downOk = _isEmiRowVerified(sale, 'downPayment');
    final disbOk = _isEmiRowVerified(sale, 'disbursement');
    if (downOk && disbOk && sale['paymentVerified'] != true) {
      try {
        await _firestore.collection('tvSales').doc(docId).update({
          'paymentVerified': true,
        });
        sale['paymentVerified'] = true;
      } catch (_) {}
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Failed to update: $e',
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // Filters
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildDateRangeFilter() {
    final options = <Map<String, String?>>[
      {'label': 'All Time', 'value': null},
      {'label': 'This Month', 'value': 'thisMonth'},
      {'label': 'Last Month', 'value': 'lastMonth'},
      {'label': 'This Year', 'value': 'thisYear'},
      {'label': 'Last Year', 'value': 'lastYear'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Report Period',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[900],
                    ),
                  ),
                  if (_selectedDateRange != null)
                    GestureDetector(
                      onTap: () => setState(() => _selectedDateRange = null),
                      child: const Row(
                        children: [
                          Icon(Icons.clear, size: 12, color: Colors.grey),
                          SizedBox(width: 2),
                          Text(
                            'Clear',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: options.map((opt) {
                    final isSelected = _selectedDateRange == opt['value'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(
                          opt['label']!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : Colors.green[900],
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.green[700],
                        backgroundColor: Colors.green.withOpacity(0.08),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.green[700]!
                              : Colors.green.withOpacity(0.3),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          setState(() => _selectedDateRange = opt['value']);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShopFilter(
    String? selectedShop,
    List<String> availableShops,
    Function(String?) onShopChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter by Shop',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[900],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedShop ?? 'All Shops',
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            onChanged: (String? newValue) {
                              onShopChanged(
                                newValue == 'All Shops' ? null : newValue,
                              );
                            },
                            items: availableShops.map<DropdownMenuItem<String>>(
                              (String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              },
                            ).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (selectedShop != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => onShopChanged(null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationSummary(
    String title,
    List<Map<String, dynamic>> filteredData,
    List<Map<String, dynamic>> allData,
  ) {
    int total = filteredData.length;
    int verified = filteredData
        .where((sale) => sale['paymentVerified'] == true)
        .length;
    int pending = total - verified;
    double verifiedPercentage = total > 0 ? (verified / total * 100) : 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(10.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.tv, size: 16, color: Colors.green[900]),
                    const SizedBox(width: 6),
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[900],
                      ),
                    ),
                  ],
                ),
                if (widget.selectedShop != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.store, size: 10, color: Colors.green),
                        const SizedBox(width: 3),
                        Text(
                          widget.selectedShop!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Total',
                  total.toString(),
                  Icons.list,
                  Colors.blue,
                ),
                _buildSummaryItem(
                  'Verified',
                  verified.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildSummaryItem(
                  'Pending',
                  pending.toString(),
                  Icons.pending,
                  Colors.orange,
                ),
                _buildSummaryItem(
                  '%',
                  '${verifiedPercentage.toStringAsFixed(0)}%',
                  Icons.percent,
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // MAIN CARD
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildTvSaleCard(Map<String, dynamic> sale, BuildContext context) {
    bool paymentVerified = sale['paymentVerified'] ?? false;

    final paymentBreakdown =
        sale['paymentBreakdownVerified'] ??
        {'cash': false, 'card': false, 'gpay': false, 'credit': false};

    bool cashVerified = widget.convertToBool(paymentBreakdown['cash']);
    bool cardVerified = widget.convertToBool(paymentBreakdown['card']);
    bool gpayVerified = widget.convertToBool(paymentBreakdown['gpay']);
    bool creditVerified = widget.convertToBool(paymentBreakdown['credit']);

    String shopName = widget.getShopName(sale);
    double amount = widget.getTotalAmount(sale);

    Map<String, dynamic> displayData = _getTvDisplayData(sale);

    // ── EMI detection ──
    String purchaseMode = sale['purchaseMode']?.toString() ?? '';
    bool isEmi = purchaseMode.toLowerCase() == 'emi';

    double downPaymentAmount =
        (sale['downPayment'] as num?)?.toDouble() ??
        (sale['downPaymentAmount'] as num?)?.toDouble() ??
        0;
    double disbursementAmount =
        (sale['disbursementAmount'] as num?)?.toDouble() ??
        (sale['disbursement'] as num?)?.toDouble() ??
        0;

    // ── Top-level payment amounts (for non-EMI display) ──
    final pbd = sale['paymentBreakdown'] as Map<String, dynamic>? ?? {};
    double cashAmt =
        (pbd['cash'] as num?)?.toDouble() ??
        (sale['cash'] as num?)?.toDouble() ??
        0;
    double cardAmt =
        (pbd['card'] as num?)?.toDouble() ??
        (sale['card'] as num?)?.toDouble() ??
        0;
    double gpayAmt =
        (pbd['gpay'] as num?)?.toDouble() ??
        (sale['gpay'] as num?)?.toDouble() ??
        0;
    double creditAmt =
        (pbd['credit'] as num?)?.toDouble() ??
        (sale['credit'] as num?)?.toDouble() ??
        0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayData['customer']?.isNotEmpty == true
                            ? displayData['customer']
                            : 'Walk-in Customer',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayData['description'] ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildVerificationChip(paymentVerified),
              ],
            ),
            const SizedBox(height: 6),
            Divider(color: Colors.grey.shade300, height: 1),
            const SizedBox(height: 6),

            // ── Shop / Amount ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shop',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '₹${widget.formatNumber(amount)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── Date ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.formatDate(displayData['date']),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: const SizedBox.shrink()),
              ],
            ),

            // ── EMI block ──
            if (isEmi) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.credit_score,
                          size: 12,
                          color: Colors.purple.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'EMI Verification',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Down Payment (with conditional methods)
                    if (downPaymentAmount > 0) _buildDownPaymentBlock(sale),

                    if (downPaymentAmount > 0 && disbursementAmount > 0)
                      const SizedBox(height: 8),

                    // Disbursement (simple verify — no method row)
                    if (disbursementAmount > 0) _buildDisbursementRow(sale),
                  ],
                ),
              ),
            ],

            // ── Top-level Payment Methods (only for non-EMI) ──
            if (!isEmi) ...[
              const SizedBox(height: 8),
              Text(
                'Payment Methods',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[900],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPaymentMethodIndicator(
                    'Cash',
                    cashVerified,
                    amount: cashAmt,
                  ),
                  _buildPaymentMethodIndicator(
                    'Card',
                    cardVerified,
                    amount: cardAmt,
                  ),
                  _buildPaymentMethodIndicator(
                    'UPI',
                    gpayVerified,
                    amount: gpayAmt,
                  ),
                  _buildPaymentMethodIndicator(
                    'Credit',
                    creditVerified,
                    amount: creditAmt,
                  ),
                ],
              ),
            ],

            // ── Serial Number ──
            if (sale['serialNumber']?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.confirmation_number,
                      size: 12,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Serial: ${sale['serialNumber']}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: sale['serialNumber']),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Serial number copied'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Icon(
                        Icons.copy,
                        size: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Model / Brand tags ──
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (sale['modelBrand']?.isNotEmpty == true)
                  _buildTag('Brand: ${sale['modelBrand']}', Colors.blue),
                if (sale['modelName']?.isNotEmpty == true)
                  _buildTag('Model: ${sale['modelName']}', Colors.green),
                if (purchaseMode.isNotEmpty)
                  _buildTag(purchaseMode, Colors.amber),
              ],
            ),

            // ── Created By ──
            if (sale['createdByName'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  'Added by: ${sale['createdByName']}',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Down Payment block (parent + conditional methods row) ──
  Widget _buildDownPaymentBlock(Map<String, dynamic> sale) {
    final docId = sale['id']?.toString() ?? '';
    final parentKey = '$docId:downPayment:*';
    final parentBusy = _busyKeys.contains(parentKey);
    final rowVerified = _isEmiRowVerified(sale, 'downPayment');
    final rowColor = rowVerified ? Colors.green : Colors.orange;

    final methodFlags = _downPaymentMethodFlags(sale);
    final methodAmounts = _downPaymentMethodAmounts(sale);
    final visibleMethods = _visibleMethodsForDownPayment(sale);

    double downPaymentAmount =
        (sale['downPayment'] as num?)?.toDouble() ??
        (sale['downPaymentAmount'] as num?)?.toDouble() ??
        0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: rowColor.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          // Parent row
          Material(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              onTap: (rowVerified || parentBusy)
                  ? null
                  : () => _verifyDownPaymentRow(sale),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.payments, size: 13, color: rowColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Down Payment',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: rowColor,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '₹${widget.formatNumber(downPaymentAmount)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: rowColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (parentBusy)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      )
                    else if (rowVerified)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 13, color: rowColor),
                          const SizedBox(width: 3),
                          Text(
                            'Verified',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: rowColor,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, size: 12, color: rowColor),
                          const SizedBox(width: 3),
                          Text(
                            'Verify All',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: rowColor,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Conditional methods row (only when at least one method exists)
          if (visibleMethods.isNotEmpty) ...[
            Divider(height: 1, color: rowColor.withOpacity(0.2)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: visibleMethods.map((method) {
                  return _buildMethodToggle(
                    sale: sale,
                    method: method,
                    label: _methodLabel(method),
                    verified: methodFlags[method] ?? false,
                    amount: methodAmounts[method] ?? 0,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Disbursement row (simple, no method breakdown) ──
  Widget _buildDisbursementRow(Map<String, dynamic> sale) {
    final docId = sale['id']?.toString() ?? '';
    final key = '$docId:disbursement:*';
    final isBusy = _busyKeys.contains(key);
    final verified = _isEmiRowVerified(sale, 'disbursement');
    final color = verified ? Colors.green : Colors.orange;

    double disbursementAmount =
        (sale['disbursementAmount'] as num?)?.toDouble() ??
        (sale['disbursement'] as num?)?.toDouble() ??
        0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: (verified || isBusy) ? null : () => _verifyDisbursementRow(sale),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet, size: 13, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disbursement',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '₹${widget.formatNumber(disbursementAmount)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (isBusy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                )
              else if (verified)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 13, color: color),
                    const SizedBox(width: 3),
                    Text(
                      'Verified',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, size: 12, color: color),
                    const SizedBox(width: 3),
                    Text(
                      'Tap to Verify',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Per-method toggle (only used inside Down Payment block) ──
  Widget _buildMethodToggle({
    required Map<String, dynamic> sale,
    required String method,
    required String label,
    required bool verified,
    required double amount,
  }) {
    final docId = sale['id']?.toString() ?? '';
    final busyKey = '$docId:downPayment:$method';
    final isBusy = _busyKeys.contains(busyKey);

    final color = verified ? Colors.green : Colors.grey;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: isBusy ? null : () => _toggleDownPaymentMethod(sale, method),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: verified
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.2),
                ),
                child: Center(
                  child: isBusy
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.4),
                        )
                      : Icon(
                          verified ? Icons.check : Icons.add,
                          size: 13,
                          color: color,
                        ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: verified ? Colors.green : Colors.grey.shade700,
                ),
              ),
              if (amount > 0)
                Text(
                  '₹${widget.formatNumber(amount)}',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: verified
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: color.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildVerificationChip(bool verified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: verified
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: verified ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.check_circle : Icons.pending,
            size: 10,
            color: verified ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 3),
          Text(
            verified ? 'Verified' : 'Pending',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: verified ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodIndicator(
    String method,
    bool verified, {
    double amount = 0,
  }) {
    final showAmount = amount > 0;
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: verified
                ? Colors.green.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: verified ? Colors.green : Colors.grey,
              width: 1.2,
            ),
          ),
          child: Center(
            child: Icon(
              verified ? Icons.check : Icons.close,
              size: 13,
              color: verified ? Colors.green : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          method,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: verified ? Colors.green : Colors.grey,
          ),
        ),
        if (showAmount)
          Text(
            '₹${widget.formatNumber(amount)}',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: verified ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
      ],
    );
  }

  Map<String, dynamic> _getTvDisplayData(Map<String, dynamic> sale) {
    return {
      'customer': sale['customerName'] ?? '',
      'description':
          sale['modelName'] ?? sale['productName'] ?? sale['modelBrand'] ?? '',
      'amount': (sale['totalAmount'] as num?)?.toDouble() ?? 0,
      'date':
          sale['saleDate'] ??
          sale['billDate'] ??
          sale['createdAt'] ??
          sale['date'] ??
          sale['timestamp'],
    };
  }
}
