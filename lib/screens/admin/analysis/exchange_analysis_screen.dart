import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sales_stock/models/sale.dart';

class ExchangeAnalysisScreen extends StatefulWidget {
  final List<Sale> allSales;
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  const ExchangeAnalysisScreen({
    Key? key,
    required this.allSales,
    required this.formatNumber,
    required this.shops,
  }) : super(key: key);

  @override
  State<ExchangeAnalysisScreen> createState() => _ExchangeAnalysisScreenState();
}

class _ExchangeAnalysisScreenState extends State<ExchangeAnalysisScreen> {
  List<Sale> _filteredSales = [];
  double _totalExchangeValue = 0.0;
  int _totalExchangeTransactions = 0;
  String _selectedPeriod = 'monthly';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Colors
  final Color primaryGreen = Color(0xFF0A4D2E);
  final Color secondaryGreen = Color(0xFF1A7D4A);
  final Color lightGreen = Color(0xFFE8F5E9);
  final Color warningColor = Color(0xFFFFC107);

  @override
  void initState() {
    super.initState();
    _filterAndCalculateData();
  }

  void _filterAndCalculateData() {
    DateTime startDate;
    DateTime endDate;

    // Calculate date range based on selected period
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'yesterday':
        final yesterday = now.subtract(Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
        );
        break;
      case 'last_month':
        final firstDayOfLastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = firstDayOfLastMonth;
        endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          startDate = _customStartDate!;
          endDate = _customEndDate!;
        } else {
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        }
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }

    // Filter phone sales with exchange value > 0 within date range
    _filteredSales = widget.allSales.where((sale) {
      if (sale.type != 'phone_sale') return false;
      if ((sale.exchangeValue ?? 0) == 0) return false;

      return sale.date.isAfter(startDate) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
    }).toList();

    // Calculate totals
    _totalExchangeValue = _filteredSales.fold(
      0.0,
      (sum, sale) => sum + (sale.exchangeValue ?? 0),
    );
    _totalExchangeTransactions = _filteredSales.length;

    setState(() {});
  }

  Future<void> _showCustomDateRangePicker() async {
    DateTime startDate =
        _customStartDate ?? DateTime.now().subtract(Duration(days: 30));
    DateTime endDate = _customEndDate ?? DateTime.now();

    // Pick start date
    final DateTime? pickedStartDate = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: endDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: secondaryGreen,
            colorScheme: ColorScheme.light(primary: secondaryGreen),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedStartDate == null) return;

    // Pick end date
    final DateTime? pickedEndDate = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: pickedStartDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: secondaryGreen,
            colorScheme: ColorScheme.light(primary: secondaryGreen),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedEndDate == null) return;

    setState(() {
      _customStartDate = DateTime(
        pickedStartDate.year,
        pickedStartDate.month,
        pickedStartDate.day,
        0,
        0,
        0,
        0,
      );
      _customEndDate = DateTime(
        pickedEndDate.year,
        pickedEndDate.month,
        pickedEndDate.day,
        23,
        59,
        59,
        999,
      );
      _selectedPeriod = 'custom';
    });

    _filterAndCalculateData();
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryGreen, secondaryGreen],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exchange Analysis',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _getPeriodLabel(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white, size: 22),
                onPressed: _filterAndCalculateData,
                tooltip: 'Refresh',
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompactStatCard(
                'Total Exchange',
                '₹${widget.formatNumber(_totalExchangeValue)}',
                Icons.currency_rupee,
              ),
              _buildCompactStatCard(
                'Transactions',
                '$_totalExchangeTransactions',
                Icons.swap_horiz,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    final periods = [
      {'label': 'Daily', 'value': 'daily'},
      {'label': 'Yesterday', 'value': 'yesterday'},
      {'label': 'Last Month', 'value': 'last_month'},
      {'label': 'Monthly', 'value': 'monthly'},
      {'label': 'Yearly', 'value': 'yearly'},
      {'label': 'Custom', 'value': 'custom'},
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: primaryGreen, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Select Period',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: periods.map((period) {
                  bool isSelected = _selectedPeriod == period['value'];
                  bool isCustom = period['value'] == 'custom';

                  return GestureDetector(
                    onTap: () {
                      if (isCustom) {
                        _showCustomDateRangePicker();
                      } else {
                        setState(() {
                          _selectedPeriod = period['value']!;
                          _customStartDate = null;
                          _customEndDate = null;
                        });
                        _filterAndCalculateData();
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? secondaryGreen.withOpacity(0.2)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? secondaryGreen
                              : Colors.grey[300]!,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            period['label']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? secondaryGreen
                                  : Colors.grey[700],
                            ),
                          ),
                          if (isCustom &&
                              _customStartDate != null &&
                              _customEndDate != null)
                            Row(
                              children: [
                                SizedBox(width: 4),
                                Icon(
                                  Icons.check_circle,
                                  size: 10,
                                  color: secondaryGreen,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_selectedPeriod == 'custom' &&
                  _customStartDate != null &&
                  _customEndDate != null)
                Container(
                  margin: EdgeInsets.only(top: 8),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: secondaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, color: secondaryGreen, size: 14),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${DateFormat('dd MMM yyyy').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}',
                          style: TextStyle(fontSize: 12, color: secondaryGreen),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExchangeList() {
    if (_filteredSales.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.swap_horiz, size: 48, color: Colors.grey[400]),
            SizedBox(height: 12),
            Text(
              'No exchange transactions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              'for the selected period',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Sort by date (newest first)
    _filteredSales.sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _filteredSales.length,
      itemBuilder: (context, index) {
        final sale = _filteredSales[index];
        final exchangeValue = sale.exchangeValue ?? 0;

        // Get sales person name or default
        final salesPersonName = sale.salesPersonName ?? 'Unknown';
        final firstName = salesPersonName.split(' ').first;

        // Get customer phone or default
        final customerPhone = sale.customerPhone ?? 'No phone';

        // Get product description
        final brand = sale.brand ?? '';
        final model = sale.model ?? '';
        final productDesc = '${brand} ${model}'.trim();

        // Get customer name or default
        final customerName = sale.customerName;

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
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
                            customerName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: primaryGreen,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            customerPhone,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '₹${widget.formatNumber(exchangeValue)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Divider(height: 1, color: Colors.grey[200]),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product Purchased',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            productDesc.isNotEmpty
                                ? productDesc
                                : 'Unknown Product',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Shop',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            sale.shopName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(sale.date),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      firstName,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShopWiseSummary() {
    if (_filteredSales.isEmpty) return SizedBox();

    // Calculate shop-wise totals
    Map<String, double> shopTotals = {};
    for (var sale in _filteredSales) {
      String shopName = sale.shopName;
      double exchangeValue = sale.exchangeValue ?? 0;
      shopTotals[shopName] = (shopTotals[shopName] ?? 0.0) + exchangeValue;
    }

    // Sort by value (highest first)
    var sortedShops = shopTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: primaryGreen, size: 16),
                SizedBox(width: 6),
                Text(
                  'Shop-wise Exchange',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryGreen,
                  ),
                ),
                Spacer(),
                Text(
                  '₹${widget.formatNumber(_totalExchangeValue)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            ...sortedShops.take(3).map((entry) {
              String shopName = entry.key;
              double total = entry.value;

              return Container(
                margin: EdgeInsets.only(bottom: 6),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        shopName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '₹${widget.formatNumber(total)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (sortedShops.length > 3)
              Center(
                child: Text(
                  '+ ${sortedShops.length - 3} more shops',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 'daily':
        return 'Today\'s Exchange';
      case 'yesterday':
        return 'Yesterday\'s Exchange';
      case 'last_month':
        return 'Last Month Exchange';
      case 'monthly':
        return 'This Month Exchange';
      case 'yearly':
        return 'Yearly Exchange';
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          return 'Custom Period Exchange';
        }
        return 'Monthly Exchange';
      default:
        return 'Monthly Exchange';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        title: Text('Exchange Analysis'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildPeriodSelector(),
            _buildShopWiseSummary(),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.list, color: primaryGreen, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Exchange Transactions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${_filteredSales.length} items',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            _buildExchangeList(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
