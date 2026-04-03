// screens/admin/reports/seconds_phone_report.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/sale.dart';

class SecondPhoneSaleReportScreen extends StatefulWidget {
  final List<Sale> allSales;
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  const SecondPhoneSaleReportScreen({
    super.key,
    required this.allSales,
    required this.formatNumber,
    required this.shops,
  });

  @override
  State<SecondPhoneSaleReportScreen> createState() =>
      _SecondPhoneSaleReportScreenState();
}

class _SecondPhoneSaleReportScreenState
    extends State<SecondPhoneSaleReportScreen> {
  String _timePeriod = 'monthly';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _showCustomDatePicker = false;
  String? _expandedShop;

  List<Sale> _getSecondPhoneSales() {
    return widget.allSales
        .where((sale) => sale.type == 'seconds_phone_sale')
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _debugCheckDates();
  }

  void _debugCheckDates() {
    final secondPhoneSales = _getSecondPhoneSales();
    print(
      '=== DEBUG: Total second phone sales received: ${secondPhoneSales.length} ===',
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Sale> filteredSales = _filterSales();

    Map<String, dynamic> stats = _calculateStats(filteredSales);

    Map<String, List<Sale>> shopWiseSales = {};
    for (var sale in filteredSales) {
      String shopName = _getShopName(sale.shopId);
      if (!shopWiseSales.containsKey(shopName)) {
        shopWiseSales[shopName] = [];
      }
      shopWiseSales[shopName]!.add(sale);
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Second Phone Sales',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          return Future.value();
        },
        color: const Color(0xFF0A4D2E),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildFilters(),
              _buildSummaryCards(stats),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: const Color(0xFF0A4D2E),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTimePeriodLabel(),
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF0A4D2E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (filteredSales.isEmpty)
                _buildEmptyState()
              else
                _buildShopWiseBreakdown(shopWiseSales),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTimePeriodChip('Today', 'today', Icons.today),
                  _buildTimePeriodChip('Yesterday', 'yesterday', Icons.history),
                  _buildTimePeriodChip(
                    'Previous Month',
                    'previous_month',
                    Icons.calendar_view_month,
                  ),
                  _buildTimePeriodChip(
                    'Current Month',
                    'monthly',
                    Icons.calendar_month,
                  ),
                  _buildTimePeriodChip(
                    'Yearly',
                    'yearly',
                    Icons.calendar_today,
                  ),
                  _buildTimePeriodChip(
                    'All Time',
                    'all_time',
                    Icons.all_inclusive,
                  ),
                  _buildTimePeriodChip('Custom', 'custom', Icons.date_range),
                ],
              ),
              if (_showCustomDatePicker) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Select Custom Date Range:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _selectStartDate(context),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _customStartDate != null
                                        ? DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(_customStartDate!)
                                        : 'Select Start Date',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _customStartDate != null
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: const Color(0xFF0A4D2E),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'To Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _selectEndDate(context),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _customEndDate != null
                                        ? DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(_customEndDate!)
                                        : 'Select End Date',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _customEndDate != null
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: const Color(0xFF0A4D2E),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _customStartDate = null;
                          _customEndDate = null;
                          _timePeriod = 'monthly';
                          _showCustomDatePicker = false;
                        });
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed:
                          _customStartDate != null && _customEndDate != null
                          ? () {
                              setState(() {
                                _timePeriod = 'custom';
                                _showCustomDatePicker = false;
                              });
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A4D2E),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Apply Filter'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePeriodChip(String label, String value, IconData icon) {
    bool isSelected = _timePeriod == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : const Color(0xFF0A4D2E),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (value == 'custom') {
          setState(() {
            if (_timePeriod == 'custom') {
              _showCustomDatePicker = !_showCustomDatePicker;
            } else {
              _timePeriod = value;
              _showCustomDatePicker = true;
              _customStartDate = null;
              _customEndDate = null;
            }
          });
        } else {
          setState(() {
            _timePeriod = value;
            _showCustomDatePicker = false;
            _customStartDate = null;
            _customEndDate = null;
          });
        }
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: const Color(0xFF0A4D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    'Total Revenue',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${widget.formatNumber(stats['totalRevenue'] as double)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A4D2E),
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'Total Units',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stats['totalQuantity']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A7D4A),
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'Average Price',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${widget.formatNumber(stats['averagePrice'] as double)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9800),
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

  Widget _buildShopWiseBreakdown(Map<String, List<Sale>> shopWiseSales) {
    if (shopWiseSales.isEmpty) {
      return const SizedBox();
    }

    var sortedShops = shopWiseSales.entries.toList();
    sortedShops.sort((a, b) {
      double totalA = a.value.fold(
        0.0,
        (sum, sale) => sum + (sale.amount ?? 0),
      );
      double totalB = b.value.fold(
        0.0,
        (sum, sale) => sum + (sale.amount ?? 0),
      );
      return totalB.compareTo(totalA);
    });

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      const Icon(
                        Icons.store,
                        size: 20,
                        color: Color(0xFF0A4D2E),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Shop-wise Breakdown',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A4D2E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${shopWiseSales.length} Shops',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0A4D2E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...sortedShops.map((entry) {
                String shopName = entry.key;
                List<Sale> shopSales = entry.value;
                double shopTotal = shopSales.fold(
                  0.0,
                  (sum, sale) => sum + (sale.amount ?? 0),
                );
                int totalUnits = shopSales.length;
                double averagePrice = shopTotal / totalUnits;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedShop = _expandedShop == shopName
                          ? null
                          : shopName;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
                                  child: Text(
                                    shopName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF1A7D4A,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$totalUnits units',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF1A7D4A),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      _expandedShop == shopName
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: const Color(0xFF0A4D2E),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total: ₹${widget.formatNumber(shopTotal)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0A4D2E),
                                      ),
                                    ),
                                    Text(
                                      'Avg: ₹${widget.formatNumber(averagePrice)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (_expandedShop == shopName) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text(
                                'Sale Details:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF0A4D2E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...shopSales
                                  .map((sale) => _buildSaleItemCard(sale))
                                  .toList(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaleItemCard(Sale sale) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  sale.itemName ?? 'Second Hand Phone',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D2E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SECOND PHONE',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.purple[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${widget.formatNumber(sale.amount ?? 0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A4D2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if ((sale.customerName ?? '').isNotEmpty)
            _buildInfoRow('Customer:', sale.customerName ?? ''),
          if ((sale.customerPhone ?? '').isNotEmpty)
            _buildInfoRow('Phone:', sale.customerPhone ?? ''),
          if ((sale.imei ?? '').isNotEmpty)
            _buildInfoRow('IMEI:', sale.imei ?? ''),
          if ((sale.defect ?? '').isNotEmpty && sale.defect != 'No defects')
            _buildInfoRow('Defect:', sale.defect ?? ''),
          const SizedBox(height: 8),
          _buildPaymentInfo(sale),
          if ((sale.salesPersonEmail ?? '').isNotEmpty)
            _buildInfoRow('Uploaded By:', sale.salesPersonEmail ?? ''),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                _formatDate(sale.date),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo(Sale sale) {
    List<Widget> paymentMethods = [];

    double cashAmount = sale.cashAmount ?? 0;
    double cardAmount = sale.cardAmount ?? 0;
    double gpayAmount = sale.gpayAmount ?? 0;

    if (cashAmount > 0) {
      paymentMethods.add(
        Chip(
          label: Text('Cash: ₹${widget.formatNumber(cashAmount)}'),
          backgroundColor: Colors.green[50],
          labelStyle: const TextStyle(fontSize: 10),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    if (cardAmount > 0) {
      paymentMethods.add(
        Chip(
          label: Text('Card: ₹${widget.formatNumber(cardAmount)}'),
          backgroundColor: Colors.blue[50],
          labelStyle: const TextStyle(fontSize: 10),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    if (gpayAmount > 0) {
      paymentMethods.add(
        Chip(
          label: Text('GPay: ₹${widget.formatNumber(gpayAmount)}'),
          backgroundColor: Colors.blue[50],
          labelStyle: const TextStyle(fontSize: 10),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    if (paymentMethods.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Methods:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        Wrap(spacing: 4, runSpacing: 4, children: paymentMethods),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No second phone sales found',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'No second phone sales available for ${_getTimePeriodLabel().toLowerCase()}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _timePeriod = 'previous_month';
                    _customStartDate = null;
                    _customEndDate = null;
                    _showCustomDatePicker = false;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous Month'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A4D2E),
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _timePeriod = 'yearly';
                    _customStartDate = null;
                    _customEndDate = null;
                    _showCustomDatePicker = false;
                  });
                },
                icon: const Icon(Icons.calendar_today),
                label: const Text('Yearly'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A4D2E),
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _timePeriod = 'all_time';
                    _customStartDate = null;
                    _customEndDate = null;
                    _showCustomDatePicker = false;
                  });
                },
                icon: const Icon(Icons.all_inclusive),
                label: const Text('All Time'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A4D2E),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats(List<Sale> sales) {
    double totalRevenue = 0;
    int totalQuantity = 0;

    for (var sale in sales) {
      totalRevenue += sale.amount ?? 0;
      totalQuantity++;
    }

    return {
      'totalRevenue': totalRevenue,
      'totalQuantity': totalQuantity,
      'averagePrice': totalQuantity > 0 ? totalRevenue / totalQuantity : 0,
    };
  }

  List<Sale> _filterSales() {
    List<Sale> secondPhoneSales = _getSecondPhoneSales();

    List<Sale> filteredSales = List.from(secondPhoneSales);

    if (filteredSales.isEmpty) {
      return [];
    }

    if (_timePeriod == 'all_time') {
      return filteredSales;
    }

    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_timePeriod) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day);
        break;

      case 'yesterday':
        DateTime yesterday = DateTime(now.year, now.month, now.day - 1);
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        break;

      case 'previous_month':
        DateTime firstDayCurrentMonth = DateTime(now.year, now.month, 1);
        DateTime lastDayPreviousMonth = firstDayCurrentMonth.subtract(
          const Duration(days: 1),
        );
        startDate = DateTime(
          lastDayPreviousMonth.year,
          lastDayPreviousMonth.month,
          1,
        );
        endDate = DateTime(
          lastDayPreviousMonth.year,
          lastDayPreviousMonth.month,
          lastDayPreviousMonth.day,
        );
        break;

      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
        break;

      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31);
        break;

      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          startDate = DateTime(
            _customStartDate!.year,
            _customStartDate!.month,
            _customStartDate!.day,
          );
          endDate = DateTime(
            _customEndDate!.year,
            _customEndDate!.month,
            _customEndDate!.day,
          );
        } else {
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0);
        }
        break;

      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
    }

    List<Sale> dateFilteredSales = filteredSales.where((sale) {
      DateTime saleDate = sale.date;

      DateTime saleDateOnly = DateTime(
        saleDate.year,
        saleDate.month,
        saleDate.day,
      );
      DateTime startDateOnly = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      DateTime endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

      bool isInRange =
          saleDateOnly.isAfter(
            startDateOnly.subtract(const Duration(days: 1)),
          ) &&
          saleDateOnly.isBefore(endDateOnly.add(const Duration(days: 1)));

      return isInRange;
    }).toList();

    return dateFilteredSales;
  }

  String _getTimePeriodLabel() {
    switch (_timePeriod) {
      case 'today':
        return 'Today\'s Sales';
      case 'yesterday':
        return 'Yesterday\'s Sales';
      case 'previous_month':
        final now = DateTime.now();
        final previousMonth = DateTime(now.year, now.month - 1);
        return 'Previous Month Sales (${DateFormat('MMM yyyy').format(previousMonth)})';
      case 'monthly':
        return 'Current Month Sales (${DateFormat('MMM yyyy').format(DateTime.now())})';
      case 'yearly':
        return 'Yearly Sales (${DateTime.now().year})';
      case 'all_time':
        return 'All Time Sales';
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          return 'Custom Period: ${DateFormat('dd/MM/yyyy').format(_customStartDate!)} - ${DateFormat('dd/MM/yyyy').format(_customEndDate!)}';
        }
        return 'Custom Period';
      default:
        return 'Current Month Sales (${DateFormat('MMM yyyy').format(DateTime.now())})';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';

    try {
      if (date is DateTime) {
        return DateFormat('dd/MM/yyyy').format(date);
      } else if (date is Timestamp) {
        return DateFormat('dd/MM/yyyy').format(date.toDate());
      }
      return 'Invalid Date';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _getShopName(String? shopId) {
    final shop = widget.shops.firstWhere(
      (s) => s['id'] == shopId,
      orElse: () => {'name': shopId ?? 'Unknown Shop'},
    );
    return shop['name'];
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _customStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF0A4D2E),
            colorScheme: const ColorScheme.light(primary: Color(0xFF0A4D2E)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked;
        if (_customEndDate != null) {
          _timePeriod = 'custom';
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _customEndDate ?? DateTime.now(),
      firstDate: _customStartDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF0A4D2E),
            colorScheme: const ColorScheme.light(primary: Color(0xFF0A4D2E)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customEndDate = picked;
        if (_customStartDate != null) {
          _timePeriod = 'custom';
        }
      });
    }
  }
}
