// lib/screens/analysis/brand_analysis_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/sale.dart';
import 'brand_details_screen.dart';

class BrandAnalysisDetailsScreen extends StatefulWidget {
  final List<Sale> allSales;
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  BrandAnalysisDetailsScreen({
    required this.allSales,
    required this.formatNumber,
    required this.shops,
  });

  @override
  _BrandAnalysisDetailsScreenState createState() =>
      _BrandAnalysisDetailsScreenState();
}

class _BrandAnalysisDetailsScreenState extends State<BrandAnalysisDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTimePeriod = 'monthly'; // Changed default to monthly
  final List<String> _timePeriods = [
    'today',
    'yesterday',
    'weekly',
    'monthly', // Moved monthly to more prominent position
    'yearly',
    'custom',
  ];
  String? _selectedBrand;
  List<String> _allBrands = [];
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _extractBrands();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _extractBrands() {
    Set<String> brands = {};
    for (var sale in widget.allSales) {
      if (sale.brand != null &&
          sale.brand!.isNotEmpty &&
          sale.brand!.toLowerCase() != 'unknown') {
        brands.add(sale.brand!);
      }
    }
    _allBrands = brands.toList()..sort();
  }

  List<Sale> _getFilteredSales() {
    DateTime startDate;
    DateTime endDate;
    DateTime now = DateTime.now();

    switch (_selectedTimePeriod) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'yesterday':
        startDate = DateTime(now.year, now.month, now.day - 1);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'weekly':
        // Get Monday of current week
        int weekDay = now.weekday;
        startDate = DateTime(now.year, now.month, now.day - weekDay + 1);
        endDate = startDate.add(Duration(days: 7, seconds: -1));
        break;
      case 'monthly': // This is now the default case
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1).add(Duration(seconds: -1));
        break;
      case 'custom':
        if (_customStartDate == null || _customEndDate == null) {
          // Default to current month if custom dates not selected
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(
            now.year,
            now.month + 1,
            1,
          ).add(Duration(seconds: -1));
        } else {
          startDate = DateTime(
            _customStartDate!.year,
            _customStartDate!.month,
            _customStartDate!.day,
          );
          endDate = DateTime(
            _customEndDate!.year,
            _customEndDate!.month,
            _customEndDate!.day,
            23,
            59,
            59,
          );
        }
        break;
      default:
        // Fallback to monthly
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
    }

    return widget.allSales.where((sale) {
      if (_selectedBrand != null) {
        if (_selectedBrand == 'All Brands') return true;

        // Handle unknown/empty brands
        if (sale.brand == null || sale.brand!.isEmpty) {
          return _selectedBrand == 'Unspecified';
        }

        return sale.brand == _selectedBrand;
      }

      return sale.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
    }).toList();
  }

  Map<String, dynamic> _getBrandStatistics() {
    List<Sale> filteredSales = _getFilteredSales();
    Map<String, Map<String, dynamic>> brandData = {};

    // Process only valid brands, group unknown/empty together
    for (var sale in filteredSales) {
      String brand = sale.brand ?? '';

      // Handle empty or null brand
      if (brand.trim().isEmpty) {
        brand = 'Unspecified';
      } else {
        // Clean the brand name
        brand = brand.trim();
      }

      if (!brandData.containsKey(brand)) {
        brandData[brand] = {
          'totalSales': 0.0,
          'count': 0,
          'categories': <String, double>{},
          'models': <String, int>{},
          'shops': <String, double>{},
          'paymentMethods': {'cash': 0.0, 'card': 0.0, 'gpay': 0.0},
        };
      }

      brandData[brand]!['totalSales'] += sale.amount;
      brandData[brand]!['count'] += 1;

      String category = sale.category;
      brandData[brand]!['categories'][category] =
          (brandData[brand]!['categories'][category] ?? 0.0) + sale.amount;

      String? model = sale.model ?? sale.itemName;
      if (model.isNotEmpty) {
        brandData[brand]!['models'][model] =
            (brandData[brand]!['models'][model] ?? 0) + 1;
      }

      brandData[brand]!['shops'][sale.shopName] =
          (brandData[brand]!['shops'][sale.shopName] ?? 0.0) + sale.amount;

      if (sale.cashAmount != null)
        brandData[brand]!['paymentMethods']['cash'] += sale.cashAmount!;
      if (sale.cardAmount != null)
        brandData[brand]!['paymentMethods']['card'] += sale.cardAmount!;
      if (sale.gpayAmount != null)
        brandData[brand]!['paymentMethods']['gpay'] += sale.gpayAmount!;
    }

    double totalAllSales = 0;
    int totalTransactions = 0;

    // Calculate totals including all brands
    brandData.forEach((brand, data) {
      totalAllSales += data['totalSales'];
      totalTransactions += data['count'] as int;
    });

    return {
      'brandData': brandData,
      'totalAllSales': totalAllSales,
      'totalTransactions': totalTransactions,
    };
  }

  List<MapEntry<String, Map<String, dynamic>>> _getSortedBrands(
    Map<String, Map<String, dynamic>> brandData,
  ) {
    List<MapEntry<String, Map<String, dynamic>>> allEntries = brandData.entries
        .toList();

    // Separate unspecified brand
    List<MapEntry<String, Map<String, dynamic>>> validBrands = [];
    MapEntry<String, Map<String, dynamic>>? unspecifiedEntry;

    for (var entry in allEntries) {
      if (entry.key == 'Unspecified') {
        unspecifiedEntry = entry;
      } else {
        validBrands.add(entry);
      }
    }

    // Sort valid brands by sales
    validBrands.sort(
      (a, b) => b.value['totalSales'].compareTo(a.value['totalSales']),
    );

    // Add unspecified at the end if it exists
    if (unspecifiedEntry != null) {
      validBrands.add(unspecifiedEntry);
    }

    return validBrands;
  }

  Future<void> _selectCustomDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _customStartDate = picked;
          // If end date is before start date, update end date to start date
          if (_customEndDate != null && _customEndDate!.isBefore(picked)) {
            _customEndDate = picked;
          }
        } else {
          _customEndDate = picked;
          // If start date is after end date, update start date to end date
          if (_customStartDate != null && _customStartDate!.isAfter(picked)) {
            _customStartDate = picked;
          }
        }
        // Switch to custom period when dates are selected
        if (_customStartDate != null && _customEndDate != null) {
          _selectedTimePeriod = 'custom';
        }
      });
    }
  }

  String _getSelectedDateRangeText() {
    final DateFormat dateFormat = DateFormat('dd MMM yyyy');
    DateTime now = DateTime.now();

    switch (_selectedTimePeriod) {
      case 'today':
        return 'Today (${dateFormat.format(now)})';
      case 'yesterday':
        return 'Yesterday (${dateFormat.format(now.subtract(Duration(days: 1)))})';
      case 'weekly':
        // Calculate week range
        int weekDay = now.weekday;
        DateTime weekStart = DateTime(
          now.year,
          now.month,
          now.day - weekDay + 1,
        );
        DateTime weekEnd = weekStart.add(Duration(days: 6));
        return 'This Week (${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)})';
      case 'monthly': // Default selection
        return 'This Month (${DateFormat('MMM yyyy').format(now)})';
      case 'yearly':
        return 'This Year (${now.year})';
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          return 'Custom (${dateFormat.format(_customStartDate!)} - ${dateFormat.format(_customEndDate!)})';
        }
        return 'Custom Date Range';
      default:
        return 'This Month (${DateFormat('MMM yyyy').format(now)})';
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getBrandStatistics();
    final brandData = stats['brandData'] as Map<String, Map<String, dynamic>>;
    final sortedBrands = _getSortedBrands(brandData);

    // Calculate brand count excluding "Unspecified"
    int validBrandCount = sortedBrands
        .where((entry) => entry.key != 'Unspecified')
        .length;

    // Get unspecified sales data if exists
    double unspecifiedSalesValue = 0;
    int unspecifiedSalesCount = 0;
    var unspecifiedEntry = sortedBrands.firstWhere(
      (entry) => entry.key == 'Unspecified',
      orElse: () => MapEntry('', {}),
    );
    if (unspecifiedEntry.key == 'Unspecified') {
      unspecifiedSalesValue = unspecifiedEntry.value['totalSales'] ?? 0;
      unspecifiedSalesCount = unspecifiedEntry.value['count'] ?? 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Brand Performance Analysis',
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
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Brand Details'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(
            stats,
            sortedBrands,
            validBrandCount,
            unspecifiedSalesValue,
            unspecifiedSalesCount,
          ),
          _buildBrandDetailsTab(sortedBrands),
          _buildTrendsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    Map<String, dynamic> stats,
    List<MapEntry<String, Map<String, dynamic>>> sortedBrands,
    int validBrandCount,
    double unspecifiedSalesValue,
    int unspecifiedSalesCount,
  ) {
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF0A4D2E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getSelectedDateRangeText(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0A4D2E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _timePeriods.map((period) {
                        bool isSelected = _selectedTimePeriod == period;
                        String label = period;
                        Color chipColor = Color(0xFF1A7D4A);

                        switch (period) {
                          case 'today':
                            label = 'Today';
                            break;
                          case 'yesterday':
                            label = 'Yesterday';
                            break;
                          case 'weekly':
                            label = 'Weekly';
                            break;
                          case 'monthly':
                            label = 'Monthly';
                            chipColor = Color(
                              0xFF0A4D2E,
                            ); // Darker green for default
                            break;
                          case 'yearly':
                            label = 'Yearly';
                            break;
                          case 'custom':
                            label = 'Custom';
                            break;
                        }
                        return FilterChip(
                          label: Text(
                            label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (period == 'custom') {
                              _showCustomDatePicker(context);
                            } else {
                              setState(() {
                                _selectedTimePeriod = period;
                              });
                            }
                          },
                          backgroundColor: Colors.grey.shade100,
                          selectedColor: chipColor,
                          checkmarkColor: Colors.white,
                        );
                      }).toList(),
                    ),

                    // Show custom date picker if custom is selected
                    if (_selectedTimePeriod == 'custom')
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () =>
                                            _selectCustomDate(context, true),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _customStartDate != null
                                                    ? DateFormat(
                                                        'dd MMM yyyy',
                                                      ).format(
                                                        _customStartDate!,
                                                      )
                                                    : 'Select start date',
                                                style: TextStyle(
                                                  color:
                                                      _customStartDate != null
                                                      ? Colors.black
                                                      : Colors.grey,
                                                ),
                                              ),
                                              Icon(
                                                Icons.calendar_today,
                                                size: 18,
                                                color: Colors.grey[600],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'End Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () =>
                                            _selectCustomDate(context, false),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _customEndDate != null
                                                    ? DateFormat(
                                                        'dd MMM yyyy',
                                                      ).format(_customEndDate!)
                                                    : 'Select end date',
                                                style: TextStyle(
                                                  color: _customEndDate != null
                                                      ? Colors.black
                                                      : Colors.grey,
                                                ),
                                              ),
                                              Icon(
                                                Icons.calendar_today,
                                                size: 18,
                                                color: Colors.grey[600],
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
                            if (_customStartDate != null &&
                                _customEndDate != null)
                              Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Selected Range:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '${_customEndDate!.difference(_customStartDate!).inDays + 1} days',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0A4D2E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                    SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBrand,
                          isExpanded: true,
                          hint: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('All Brands'),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('All Brands'),
                              ),
                            ),
                            if (unspecifiedSalesCount > 0)
                              DropdownMenuItem<String>(
                                value: 'Unspecified',
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.help_outline,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Unspecified Brands'),
                                      SizedBox(width: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '$unspecifiedSalesCount',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ..._allBrands.map<DropdownMenuItem<String>>((
                              brand,
                            ) {
                              return DropdownMenuItem<String>(
                                value: brand,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(brand),
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedBrand = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatCard(
                  'Total Brands',
                  '$validBrandCount',
                  Icons.branding_watermark,
                  Color(0xFF2196F3),
                  'Valid brands',
                ),
                _buildStatCard(
                  'Total Sales',
                  '₹${widget.formatNumber(stats['totalAllSales'])}',
                  Icons.currency_rupee,
                  Color(0xFF0A4D2E),
                  'All brands combined',
                ),
                _buildStatCard(
                  'Transactions',
                  '${stats['totalTransactions']}',
                  Icons.receipt,
                  Color(0xFF4CAF50),
                  'Total sales count',
                ),
                _buildStatCard(
                  'Avg/Brand',
                  validBrandCount > 0
                      ? '₹${widget.formatNumber(stats['totalAllSales'] / validBrandCount)}'
                      : '₹0',
                  Icons.trending_up,
                  Color(0xFF9C27B0),
                  'Average per brand',
                ),
              ],
            ),
          ),

          // Unspecified sales summary card (if exists)
          if (unspecifiedSalesCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.warning_amber,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sales Without Brand Information',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.shopping_cart,
                                        size: 12,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '$unspecifiedSalesCount sales',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF0A4D2E).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.currency_rupee,
                                        size: 12,
                                        color: Color(0xFF0A4D2E),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '₹${widget.formatNumber(unspecifiedSalesValue)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0A4D2E),
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
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            ),

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Top Brands by Sales',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                        if (unspecifiedSalesCount > 0)
                          GestureDetector(
                            onTap: () {
                              // Show dialog with unspecified sales details
                              _showUnspecifiedSalesDialog(
                                context,
                                unspecifiedSalesValue,
                                unspecifiedSalesCount,
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info,
                                    size: 12,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '$unspecifiedSalesCount unspecified',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 16),

                    if (sortedBrands
                        .where((entry) => entry.key != 'Unspecified')
                        .isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.branding_watermark_outlined,
                              size: 48,
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No brand data available',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    else
                      ...sortedBrands
                          .where((entry) => entry.key != 'Unspecified')
                          .take(5)
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) {
                            int index = entry.key;
                            var brandEntry = entry.value;
                            String brand = brandEntry.key;
                            var data = brandEntry.value;
                            double totalSales = data['totalSales'];
                            double percentage = stats['totalAllSales'] > 0
                                ? (totalSales / stats['totalAllSales']) * 100
                                : 0;

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BrandDetailsScreen(
                                      brand: brand,
                                      sales: widget.allSales
                                          .where((s) => s.brand == brand)
                                          .toList(),
                                      formatNumber: widget.formatNumber,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: _getBrandColor(brand),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          (index + 1).toString(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                brand,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                '₹${widget.formatNumber(totalSales)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0A4D2E),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          LinearProgressIndicator(
                                            value: percentage / 100,
                                            backgroundColor: Colors.grey[200],
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  _getBrandColor(brand),
                                                ),
                                            minHeight: 6,
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${data['count']} sales',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                '${percentage.toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
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
                            );
                          })
                          .toList(),

                    // Show unspecified sales summary at the bottom
                    if (unspecifiedSalesCount > 0)
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(),
                            SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                _showUnspecifiedSalesDialog(
                                  context,
                                  unspecifiedSalesValue,
                                  unspecifiedSalesCount,
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.help_outline,
                                          size: 16,
                                          color: Colors.orange,
                                        ),
                                        SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Sales without brand information',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey[700],
                                                fontSize: 12,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Requires attention to complete brand data',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${widget.formatNumber(unspecifiedSalesValue)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          '$unspecifiedSalesCount sales',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomDatePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Custom Date Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Start Date Picker
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start Date',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await _selectCustomDate(context, true);
                    _showCustomDatePicker(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _customStartDate != null
                              ? DateFormat(
                                  'dd MMM yyyy',
                                ).format(_customStartDate!)
                              : 'Select start date',
                          style: TextStyle(
                            color: _customStartDate != null
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                        Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // End Date Picker
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'End Date',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await _selectCustomDate(context, false);
                    _showCustomDatePicker(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _customEndDate != null
                              ? DateFormat(
                                  'dd MMM yyyy',
                                ).format(_customEndDate!)
                              : 'Select end date',
                          style: TextStyle(
                            color: _customEndDate != null
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                        Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_customStartDate != null && _customEndDate != null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF0A4D2E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Range:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      '${_customEndDate!.difference(_customStartDate!).inDays + 1} days',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A4D2E),
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
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedTimePeriod = 'custom';
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0A4D2E)),
            child: Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandDetailsTab(
    List<MapEntry<String, Map<String, dynamic>>> sortedBrands,
  ) {
    // Filter out unspecified brands from the main list
    final validBrands = sortedBrands
        .where((entry) => entry.key != 'Unspecified')
        .toList();
    final unspecifiedBrands = sortedBrands
        .where((entry) => entry.key == 'Unspecified')
        .toList();

    return ListView(
      children: [
        // Valid brands section
        if (validBrands.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Brands',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          ...validBrands
              .map((brandEntry) => _buildBrandCard(brandEntry))
              .toList(),
        ],

        // Unspecified brands section (if any)
        if (unspecifiedBrands.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sales Without Brand Information',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${unspecifiedBrands.first.value['count']} sales',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...unspecifiedBrands
              .map(
                (brandEntry) =>
                    _buildBrandCard(brandEntry, isUnspecified: true),
              )
              .toList(),
        ],

        if (sortedBrands.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.branding_watermark_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No brand data available',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTrendsTab() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Trend Analysis',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A4D2E),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Brand performance trends over time will be displayed here.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Features coming soon:',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  _buildFeatureItem('Monthly sales trends'),
                  _buildFeatureItem('Year-over-year comparison'),
                  _buildFeatureItem('Market share analysis'),
                  _buildFeatureItem('Seasonal patterns'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnspecifiedSalesDialog(
    BuildContext context,
    double salesValue,
    int salesCount,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Sales Without Brand Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Some sales are missing brand information. This affects brand performance analysis.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Sales Value:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '₹${widget.formatNumber(salesValue)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Number of Sales:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$salesCount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Average per Sale:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '₹${widget.formatNumber(salesCount > 0 ? salesValue / salesCount : 0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Action Required:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A4D2E),
              ),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: Color(0xFF4CAF50)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Review individual sales to add brand information',
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: Color(0xFF4CAF50)),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Update sales records with missing brand data'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Color(0xFF0A4D2E))),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Color(0xFF4CAF50)),
          SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
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
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandCard(
    MapEntry<String, Map<String, dynamic>> brandEntry, {
    bool isUnspecified = false,
  }) {
    String brand = brandEntry.key;
    var data = brandEntry.value;

    // Prepare top shops list
    List<MapEntry<String, double>> topShops = [];
    if ((data['shops'] as Map<String, double>).isNotEmpty) {
      topShops = (data['shops'] as Map<String, double>).entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..take(3);
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isUnspecified
                ? Colors.orange.withOpacity(0.1)
                : _getBrandColor(brand).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: isUnspecified
                ? Icon(Icons.warning_amber, color: Colors.orange, size: 20)
                : Text(
                    brand.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getBrandColor(brand),
                    ),
                  ),
          ),
        ),
        title: Text(
          isUnspecified ? 'Sales Without Brand Information' : brand,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isUnspecified ? Colors.grey[800] : null,
          ),
        ),
        subtitle: Text(
          '${data['count']} sales',
          style: TextStyle(color: isUnspecified ? Colors.grey[600] : null),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${widget.formatNumber(data['totalSales'])}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isUnspecified ? Colors.orange : Color(0xFF0A4D2E),
              ),
            ),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isUnspecified
                    ? Colors.orange.withOpacity(0.1)
                    : Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Avg: ₹${widget.formatNumber(data['count'] > 0 ? data['totalSales'] / data['count'] : 0)}',
                style: TextStyle(
                  fontSize: 10,
                  color: isUnspecified ? Colors.orange : Color(0xFF4CAF50),
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                if ((data['categories'] as Map<String, double>).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales by Category',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                      SizedBox(height: 8),
                      ...(data['categories'] as Map<String, double>).entries
                          .map((entry) {
                            Color categoryColor = _getCategoryColor(entry.key);
                            return Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: categoryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(child: Text(entry.key)),
                                  Text(
                                    '₹${widget.formatNumber(entry.value)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(),
                    ],
                  ),

                SizedBox(height: 16),

                if ((data['models'] as Map<String, int>).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Items',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                      SizedBox(height: 8),
                      ...(data['models'] as Map<String, int>).entries
                          .take(3)
                          .map((entry) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.shopping_cart,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF2196F3).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${entry.value} sales',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(),
                    ],
                  ),

                SizedBox(height: 16),

                if (topShops.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Performing Shops',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                      SizedBox(height: 8),
                      ...topShops.map((entry) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.store,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 8),
                              Expanded(child: Text(entry.key)),
                              Text(
                                '₹${widget.formatNumber(entry.value)}',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBrandColor(String brand) {
    if (brand == 'Unspecified') return Colors.orange;

    int hash = brand.hashCode;
    List<Color> brandColors = [
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
      Color(0xFF9C27B0),
      Color(0xFFFF9800),
      Color(0xFFF44336),
      Color(0xFF00BCD4),
      Color(0xFF673AB7),
      Color(0xFFFF5722),
    ];
    return brandColors[hash.abs() % brandColors.length];
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'New Phone':
        return Color(0xFF4CAF50);
      case 'Base Model':
        return Color(0xFF2196F3);
      case 'Second Phone':
        return Color(0xFF9C27B0);
      case 'Service':
        return Color(0xFFFF9800);
      default:
        return Colors.grey;
    }
  }
}
