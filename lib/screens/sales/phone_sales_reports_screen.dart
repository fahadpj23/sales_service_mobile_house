import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sale.dart';

class PhoneSalesReportsScreen extends StatefulWidget {
  final List<Sale> allSales;
  final List<Sale> phoneSales;
  final String Function(double) formatNumber;

  PhoneSalesReportsScreen({
    required this.allSales,
    required this.phoneSales,
    required this.formatNumber,
  });

  @override
  _PhoneSalesReportsScreenState createState() =>
      _PhoneSalesReportsScreenState();
}

class _PhoneSalesReportsScreenState extends State<PhoneSalesReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Sale> _filteredPhoneSales = [];
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  final List<String> _timePeriods = [
    'monthly',
    'today',
    'yesterday',
    'last_monthly',
    'yearly',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this, initialIndex: 0);
    _filteredPhoneSales = _filterByTimePeriod('monthly');
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _handleTabChange(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange(int index) {
    final period = _timePeriods[index];
    if (period == 'custom') {
      _showCustomDateRangePicker();
    } else {
      setState(() {
        _filteredPhoneSales = _filterByTimePeriod(period);
      });
    }
  }

  List<Sale> _filterByTimePeriod(String period) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (period) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'yesterday':
        final yesterday = now.subtract(Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
        break;
      case 'last_monthly':
        final firstDayOfLastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = firstDayOfLastMonth;
        endDate = DateTime(now.year, now.month, 1).add(Duration(seconds: -1));
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1).add(Duration(seconds: -1));
        break;
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          startDate = _customStartDate!;
          endDate = _customEndDate!.add(Duration(days: 1, seconds: -1));
        } else {
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(
            now.year,
            now.month + 1,
            1,
          ).add(Duration(seconds: -1));
        }
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
    }

    return widget.phoneSales.where((sale) {
      return sale.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
    }).toList();
  }

  Future<void> _showCustomDateRangePicker() async {
    final DateTime? start = await showDatePicker(
      context: context,
      initialDate: _customStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Color(0xFF0A4D2E),
            colorScheme: ColorScheme.light(primary: Color(0xFF0A4D2E)),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (start != null) {
      final DateTime? end = await showDatePicker(
        context: context,
        initialDate: _customEndDate ?? start,
        firstDate: start,
        lastDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              primaryColor: Color(0xFF0A4D2E),
              colorScheme: ColorScheme.light(primary: Color(0xFF0A4D2E)),
              buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
            ),
            child: child!,
          );
        },
      );

      if (end != null) {
        setState(() {
          _customStartDate = start;
          _customEndDate = end;
          _filteredPhoneSales = _filterByTimePeriod('custom');
        });
      }
    }
  }

  String _getPeriodLabel(String period) {
    switch (period) {
      case 'today':
        return 'Today';
      case 'yesterday':
        return 'Yesterday';
      case 'monthly':
        return 'Monthly';
      case 'last_monthly':
        return 'Last Month';
      case 'yearly':
        return 'Yearly';
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          return '${DateFormat('dd MMM').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}';
        }
        return 'Custom';
      default:
        return 'Monthly';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Phone Sales Reports',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: [
            Tab(text: 'Monthly'),
            Tab(text: 'Today'),
            Tab(text: 'Yesterday'),
            Tab(text: 'Last Month'),
            Tab(text: 'Yearly'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 16),
                  SizedBox(width: 4),
                  Text('Custom'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportView(),
          _buildReportView(),
          _buildReportView(),
          _buildReportView(),
          _buildReportView(),
          _buildReportView(),
        ],
      ),
    );
  }

  Widget _buildReportView() {
    final period = _timePeriods[_tabController.index];
    final periodLabel = _getPeriodLabel(period);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Color(0xFFE8F5E9),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      periodLabel,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryStat(
                          'Total Sales',
                          '₹${widget.formatNumber(_filteredPhoneSales.fold(0.0, (sum, sale) => sum + sale.amount))}',
                          Icons.currency_rupee,
                          Color(0xFF0A4D2E),
                        ),
                        _buildSummaryStat(
                          'Transactions',
                          '${_filteredPhoneSales.length}',
                          Icons.receipt,
                          Color(0xFF2196F3),
                        ),
                        _buildSummaryStat(
                          'Avg Sale',
                          _filteredPhoneSales.isNotEmpty
                              ? '₹${widget.formatNumber(_filteredPhoneSales.fold(0.0, (sum, sale) => sum + sale.amount) / _filteredPhoneSales.length)}'
                              : '₹0',
                          Icons.trending_up,
                          Color(0xFF4CAF50),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            color: Color(0xFF0A4D2E),
            child: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'Brand Wise'),
                Tab(text: 'Shop Wise'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              children: [_buildBrandWiseReport(), _buildShopWiseReport()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildBrandWiseReport() {
    if (_filteredPhoneSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_iphone, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No phone sales data',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Try selecting a different time period',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    Map<String, List<Sale>> brandGroups = {};
    for (var sale in _filteredPhoneSales) {
      String brand = sale.brand ?? 'Unknown';
      if (!brandGroups.containsKey(brand)) {
        brandGroups[brand] = [];
      }
      brandGroups[brand]!.add(sale);
    }

    List<Map<String, dynamic>> brandData = [];
    brandGroups.forEach((brand, sales) {
      double totalAmount = sales.fold(0.0, (sum, s) => sum + s.amount);
      int count = sales.length;
      double avgSale = count > 0 ? totalAmount / count : 0;

      brandData.add({
        'brand': brand,
        'totalAmount': totalAmount,
        'count': count,
        'avgSale': avgSale,
      });
    });

    brandData.sort((a, b) => b['totalAmount'].compareTo(a['totalAmount']));

    double totalAllSales = brandData.fold(
      0.0,
      (sum, item) => sum + item['totalAmount'],
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Brand Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniStatCard(
                          'Brands',
                          '${brandData.length}',
                          Icons.branding_watermark,
                          Color(0xFF2196F3),
                        ),
                        _buildMiniStatCard(
                          'Total Sales',
                          '₹${widget.formatNumber(totalAllSales)}',
                          Icons.currency_rupee,
                          Color(0xFF4CAF50),
                        ),
                        _buildMiniStatCard(
                          'Avg/Brand',
                          '₹${widget.formatNumber(brandData.isNotEmpty ? totalAllSales / brandData.length : 0)}',
                          Icons.assessment,
                          Color(0xFF9C27B0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          ...brandData.map((brand) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              brand['brand'],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A4D2E),
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${brand['count']} sales',
                              style: TextStyle(
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Sales',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '₹${widget.formatNumber(brand['totalAmount'])}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A4D2E),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Avg. Sale',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '₹${widget.formatNumber(brand['avgSale'])}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: brandData.isNotEmpty
                            ? brand['totalAmount'] / totalAllSales
                            : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF4CAF50),
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),

          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildShopWiseReport() {
    if (_filteredPhoneSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No shop sales data',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Try selecting a different time period',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    Map<String, Map<String, List<Sale>>> shopBrandGroups = {};

    for (var sale in _filteredPhoneSales) {
      String shop = sale.shopName;
      String brand = sale.brand ?? 'Unknown';

      if (!shopBrandGroups.containsKey(shop)) {
        shopBrandGroups[shop] = {};
      }
      if (!shopBrandGroups[shop]!.containsKey(brand)) {
        shopBrandGroups[shop]![brand] = [];
      }
      shopBrandGroups[shop]![brand]!.add(sale);
    }

    List<Map<String, dynamic>> shopData = [];
    shopBrandGroups.forEach((shop, brandMap) {
      double shopTotal = 0;
      int shopCount = 0;

      List<Map<String, dynamic>> brandsInShop = [];

      brandMap.forEach((brand, sales) {
        double brandTotal = sales.fold(0.0, (sum, s) => sum + s.amount);
        int brandCount = sales.length;

        shopTotal += brandTotal;
        shopCount += brandCount;

        brandsInShop.add({
          'brand': brand,
          'total': brandTotal,
          'count': brandCount,
        });
      });

      brandsInShop.sort((a, b) => b['total'].compareTo(a['total']));

      shopData.add({
        'shop': shop,
        'total': shopTotal,
        'count': shopCount,
        'brands': brandsInShop,
      });
    });

    shopData.sort((a, b) => b['total'].compareTo(a['total']));

    double totalAllSales = shopData.fold(
      0.0,
      (sum, item) => sum + item['total'],
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Shop Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniStatCard(
                          'Shops',
                          '${shopData.length}',
                          Icons.store,
                          Color(0xFF2196F3),
                        ),
                        _buildMiniStatCard(
                          'Total Sales',
                          '₹${widget.formatNumber(totalAllSales)}',
                          Icons.currency_rupee,
                          Color(0xFF4CAF50),
                        ),
                        _buildMiniStatCard(
                          'Avg/Shop',
                          '₹${widget.formatNumber(shopData.isNotEmpty ? totalAllSales / shopData.length : 0)}',
                          Icons.assessment,
                          Color(0xFF9C27B0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          ...shopData.map((shop) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  leading: Icon(Icons.store, color: Color(0xFF1A7D4A)),
                  title: Text(
                    shop['shop'],
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    '${shop['count']} sales • ${shop['brands'].length} brands',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${widget.formatNumber(shop['total'])}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A4D2E),
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${shop['count']} sales',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Shop Summary',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0A4D2E),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Avg. Sale: ₹${widget.formatNumber(shop['total'] / shop['count'])}',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),

                          Text(
                            'Brands in this Shop',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A4D2E),
                            ),
                          ),
                          SizedBox(height: 8),
                          ...(shop['brands'] as List<Map<String, dynamic>>).map((
                            brand,
                          ) {
                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[200]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      brand['brand'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${widget.formatNumber(brand['total'])}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0A4D2E),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            '${brand['count']} sales',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
      ],
    );
  }
}
