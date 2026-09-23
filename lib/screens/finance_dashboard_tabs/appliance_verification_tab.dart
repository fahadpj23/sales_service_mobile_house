// lib/screens/admin/reports/appliance_verification_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ApplianceVerificationTab extends StatefulWidget {
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

  const ApplianceVerificationTab({
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
  State<ApplianceVerificationTab> createState() =>
      _ApplianceVerificationTabState();
}

class _ApplianceVerificationTabState extends State<ApplianceVerificationTab> {
  // ── Internal date filter state ──
  String? _selectedDateRange;

  /// In-flight operations. Key format:
  ///   "$docId:downPayment:*"        → verifying the whole Down Payment row
  ///   "$docId:downPayment:cash"     → toggling a single method
  ///   "$docId:disbursement:*"       → verifying the Disbursement row
  final Set<String> _busyKeys = {};

  /// Local overrides for per-method flags (Down Payment only).
  /// docId -> field -> method -> bool
  final Map<String, Map<String, Map<String, bool>>> _localMethodFlags = {};

  /// Local overrides for parent-row flags.
  /// docId -> field -> bool
  final Map<String, Map<String, bool>> _localEmiFlags = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Date parser ──
  DateTime? _parseSaleDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  // ── Apply date filter to widget.filteredData ──
  List<Map<String, dynamic>> get _displayData {
    if (_selectedDateRange == null) return widget.filteredData;

    final now = DateTime.now();
    return widget.filteredData.where((sale) {
      final date = _parseSaleDate(
        sale['saleDate'] ??
            sale['createdAt'] ??
            sale['date'] ??
            sale['timestamp'] ??
            sale['billDate'],
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
        _buildVerificationSummary('Appliances', data, widget.allData),
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
                      Icon(Icons.kitchen, size: 40, color: Colors.grey[400]),
                      const SizedBox(height: 10),
                      const Text(
                        'No appliance sales found',
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
                      child: _buildApplianceSaleCard(data[index], context),
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

  /// Per-method verified flags for Down Payment.
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

  /// Only methods with amount > 0, in a fixed order.
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

      await _firestore.collection('applianceSales').doc(docId).update(updates);

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

      await _firestore.collection('applianceSales').doc(docId).update(updates);

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

      await _firestore.collection('applianceSales').doc(docId).update(updates);

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
        await _firestore.collection('applianceSales').doc(docId).update({
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
                    Icon(Icons.kitchen, size: 16, color: Colors.green[900]),
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
  Widget _buildApplianceSaleCard(
    Map<String, dynamic> sale,
    BuildContext context,
  ) {
    bool paymentVerified = sale['paymentVerified'] ?? false;

    final paymentBreakdown =
        sale['paymentBreakdownVerified'] ??
        {'cash': false, 'card': false, 'gpay': false, 'credit': false};

    bool cashVerified = widget.convertToBool(paymentBreakdown['cash']);
    bool cardVerified = widget.convertToBool(paymentBreakdown['card']);
    bool gpayVerified = widget.convertToBool(paymentBreakdown['gpay']);
    bool creditVerified = widget.convertToBool(paymentBreakdown['credit']);

    // ── Customer / Basic ──
    String customerName = sale['customerName'] ?? 'Walk-in Customer';
    String customerPhone =
        sale['customerPhone']?.toString() ?? sale['customerMobile'] ?? '';
    String shopName = widget.getShopName(sale);
    String billNumber = sale['billNumber'] ?? sale['invoiceNumber'] ?? '';
    dynamic saleDate =
        sale['saleDate'] ??
        sale['billDate'] ??
        sale['createdAt'] ??
        sale['date'];
    String purchaseMode = sale['purchaseMode'] ?? sale['paymentMode'] ?? '';

    // ── Product fields ──
    String brand = sale['brand'] ?? sale['applianceBrand'] ?? '';
    String productModel =
        sale['productModel'] ?? sale['applianceProductName'] ?? '';
    String imei = sale['imei'] ?? sale['applianceModelId'] ?? '';

    double price = (sale['price'] as num?)?.toDouble() ?? 0;
    double discount = (sale['discount'] as num?)?.toDouble() ?? 0;
    double effectivePrice = (sale['effectivePrice'] as num?)?.toDouble() ?? 0;
    double exchangeValue = (sale['exchangeValue'] as num?)?.toDouble() ?? 0;
    double customerCredit = (sale['customerCredit'] as num?)?.toDouble() ?? 0;
    double amountToPay = (sale['amountToPay'] as num?)?.toDouble() ?? 0;
    double balanceReturned =
        (sale['balanceReturnedToCustomer'] as num?)?.toDouble() ?? 0;

    // ── EMI fields ──
    String? financeType = sale['financeType']?.toString();
    double downPayment = (sale['downPayment'] as num?)?.toDouble() ?? 0;
    int numberOfEmi = (sale['numberOfEmi'] as num?)?.toInt() ?? 0;
    double perMonthEmi = (sale['perMonthEmi'] as num?)?.toDouble() ?? 0;
    String? loanId = sale['loanId']?.toString();
    bool autoDebit = sale['autoDebit'] == true;
    bool insurance = sale['insurance'] == true;
    double disbursementAmount =
        (sale['disbursementAmount'] as num?)?.toDouble() ?? 0;

    // ── Gifts ──
    int giftsCount = (sale['giftsCount'] as num?)?.toInt() ?? 0;
    List<String> gifts = [];
    if (sale['gifts'] is List) {
      gifts = List<String>.from(
        (sale['gifts'] as List).map((e) => e.toString()),
      );
    }

    // ── Payment breakdown amounts (top-level, non-EMI display) ──
    final pbd = sale['paymentBreakdown'] as Map<String, dynamic>? ?? {};
    double cashAmt = (pbd['cash'] as num?)?.toDouble() ?? 0;
    double gpayAmt = (pbd['gpay'] as num?)?.toDouble() ?? 0;
    double cardAmt = (pbd['card'] as num?)?.toDouble() ?? 0;
    double creditAmt = (pbd['credit'] as num?)?.toDouble() ?? 0;

    double totalAmount = widget.getTotalAmount(sale);

    final bool isEmi = purchaseMode == 'EMI';

    // Build description
    String description = productModel;
    if (brand.isNotEmpty && brand != productModel) {
      description = '$brand - $description';
    }
    if (imei.isNotEmpty && imei != productModel) {
      description = '$description (ID: $imei)';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Row ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customerName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (customerPhone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 6.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: 9,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      customerPhone,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description.isNotEmpty ? description : 'Appliance Sale',
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
                // Status chip (info only, no verify button)
                _buildVerificationChip(paymentVerified),
              ],
            ),
            const SizedBox(height: 6),
            Divider(color: Colors.grey.shade300, height: 1),
            const SizedBox(height: 6),

            // ── Bill No. & Shop ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill No.',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        billNumber.isNotEmpty ? billNumber : 'N/A',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
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
              ],
            ),
            const SizedBox(height: 6),

            // ── Amount & Price/Discount ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '₹${widget.formatNumber(totalAmount)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
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
                        'Price / Discount',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '₹${widget.formatNumber(price)}'
                        '${discount > 0 ? '  − ₹${widget.formatNumber(discount)}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
                        'Sale Date',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.formatDate(saleDate),
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

            // ── Adjustments (Exchange / Credit / Balance Returned) ──
            if (exchangeValue > 0 ||
                customerCredit > 0 ||
                balanceReturned > 0 ||
                amountToPay > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    if (amountToPay > 0)
                      _buildInfoRow(
                        'Amount To Pay',
                        '₹${widget.formatNumber(amountToPay)}',
                        Colors.green.shade800,
                      ),
                    if (exchangeValue > 0)
                      _buildInfoRow(
                        'Exchange Value',
                        '- ₹${widget.formatNumber(exchangeValue)}',
                        Colors.teal.shade700,
                      ),
                    if (customerCredit > 0)
                      _buildInfoRow(
                        'Customer Credit',
                        '- ₹${widget.formatNumber(customerCredit)}',
                        Colors.orange.shade700,
                      ),
                    if (balanceReturned > 0)
                      _buildInfoRow(
                        'Balance Returned',
                        '₹${widget.formatNumber(balanceReturned)}',
                        Colors.red.shade700,
                      ),
                  ],
                ),
              ),
            ],

            // ── EMI: Down Payment + Disbursement (tappable verify) ──
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
                    const SizedBox(height: 6),

                    // Non-verifiable info: finance, EMI count, per-month, etc.
                    if (financeType != null && financeType.isNotEmpty)
                      _buildInfoRow(
                        'Finance Company',
                        financeType,
                        Colors.purple.shade700,
                      ),
                    if (numberOfEmi > 0)
                      _buildInfoRow(
                        'Number of EMI',
                        numberOfEmi.toString(),
                        Colors.purple.shade700,
                      ),
                    if (perMonthEmi > 0)
                      _buildInfoRow(
                        'Per Month EMI',
                        '₹${widget.formatNumber(perMonthEmi)}',
                        Colors.purple.shade700,
                      ),
                    if (loanId != null && loanId.isNotEmpty)
                      _buildInfoRow('Loan ID', loanId, Colors.purple.shade700),

                    const SizedBox(height: 8),

                    // Down Payment (with conditional methods)
                    if (downPayment > 0) _buildDownPaymentBlock(sale),

                    if (downPayment > 0 && disbursementAmount > 0)
                      const SizedBox(height: 8),

                    // Disbursement (simple verify)
                    if (disbursementAmount > 0) _buildDisbursementRow(sale),

                    if (autoDebit || insurance) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (autoDebit)
                            _buildSmallTag('Auto Debit: Yes', Colors.teal),
                          if (autoDebit && insurance) const SizedBox(width: 6),
                          if (insurance)
                            _buildSmallTag('Insurance: Yes', Colors.orange),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // ── Top-level Payment Methods (only for non-EMI) ──
            if (!isEmi) ...[
              const SizedBox(height: 10),
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
                    'UPI/GPay',
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

            // ── Tags Row ──
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (brand.isNotEmpty) _buildTag('Brand: $brand', Colors.blue),
                if (productModel.isNotEmpty)
                  _buildTag('Model: $productModel', Colors.green),
                if (purchaseMode.isNotEmpty)
                  _buildTag(purchaseMode, Colors.amber),
                if (discount > 0)
                  _buildTag(
                    'Discount: ₹${widget.formatNumber(discount)}',
                    Colors.red,
                  ),
                if (imei.isNotEmpty) _buildSerialTag(imei, context),
                if (giftsCount > 0) _buildGiftTag(giftsCount, gifts, context),
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

    double downPaymentAmount = (sale['downPayment'] as num?)?.toDouble() ?? 0;

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

          // Conditional methods row
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
        (sale['disbursementAmount'] as num?)?.toDouble() ?? 0;

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

  // ── Per-method toggle (only inside Down Payment block) ──
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

  // ══════════════════════════════════════════════════════════════════════
  // Small widgets
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
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

  Widget _buildSerialTag(String serial, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'S/N: $serial',
            style: TextStyle(
              fontSize: 9,
              color: Colors.purple.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: serial));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Serial number copied'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Icon(Icons.copy, size: 11, color: Colors.purple.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftTag(int count, List<String> gifts, BuildContext context) {
    final giftText = gifts.isNotEmpty
        ? gifts.join(', ')
        : '$count gift${count > 1 ? 's' : ''}';

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.pink.shade400),
                const SizedBox(width: 8),
                Text(
                  'Gifts Provided ($count)',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            content: gifts.isEmpty
                ? const Text('No gift names recorded')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: gifts
                        .map(
                          (g) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 13,
                                  color: Colors.pink.shade400,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    g,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.pink.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.pink.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_giftcard, size: 11, color: Colors.pink.shade700),
            const SizedBox(width: 4),
            Text(
              'Gifts: $giftText',
              style: TextStyle(
                fontSize: 9,
                color: Colors.pink.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
}
