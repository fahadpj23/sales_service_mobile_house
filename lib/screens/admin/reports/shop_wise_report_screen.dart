// lib/screens/reports/shop_wise_report_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';

class ShopWiseReportScreen extends StatefulWidget {
  final List<Sale> allSales;
  final List<Map<String, dynamic>> shops;
  final String Function(double) formatNumber;
  final Color Function(String) getCategoryColor;

  const ShopWiseReportScreen({
    Key? key,
    required this.allSales,
    required this.shops,
    required this.formatNumber,
    required this.getCategoryColor,
  }) : super(key: key);

  @override
  _ShopWiseReportScreenState createState() => _ShopWiseReportScreenState();
}

class _ShopWiseReportScreenState extends State<ShopWiseReportScreen> {
  String? _selectedShopId;
  String _selectedTimePeriod = 'monthly';
  final List<String> _timePeriods = [
    'today',
    'yesterday',
    'weekly',
    'monthly',
    'lastmonth', // Added lastmonth option
    'yearly',
    'custom',
  ];
  DateTime? _customStartDate;
  DateTime? _customEndDate;

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
        int weekDay = now.weekday;
        startDate = DateTime(now.year, now.month, now.day - weekDay + 1);
        endDate = startDate.add(Duration(days: 7, seconds: -1));
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
        break;
      case 'lastmonth': // Added last month calculation
        startDate = DateTime(now.year, now.month - 1, 1);
        endDate = DateTime(now.year, now.month, 1).add(Duration(seconds: -1));
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1).add(Duration(seconds: -1));
        break;
      case 'custom':
        if (_customStartDate == null || _customEndDate == null) {
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
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
    }

    List<Sale> timeFilteredSales = widget.allSales.where((sale) {
      return sale.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
    }).toList();

    // Apply shop filter if selected
    if (_selectedShopId != null) {
      return timeFilteredSales
          .where((sale) => sale.shopId == _selectedShopId)
          .toList();
    }

    return timeFilteredSales;
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
        int weekDay = now.weekday;
        DateTime weekStart = DateTime(
          now.year,
          now.month,
          now.day - weekDay + 1,
        );
        DateTime weekEnd = weekStart.add(Duration(days: 6));
        return 'This Week (${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)})';
      case 'monthly':
        return 'This Month (${DateFormat('MMM yyyy').format(now)})';
      case 'lastmonth': // Added last month text
        DateTime lastMonth = DateTime(now.year, now.month - 1, 1);
        return 'Last Month (${DateFormat('MMM yyyy').format(lastMonth)})';
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
          if (_customEndDate != null && _customEndDate!.isBefore(picked)) {
            _customEndDate = picked;
          }
        } else {
          _customEndDate = picked;
          if (_customStartDate != null && _customStartDate!.isAfter(picked)) {
            _customStartDate = picked;
          }
        }
        if (_customStartDate != null && _customEndDate != null) {
          _selectedTimePeriod = 'custom';
        }
      });
    }
  }

  void _showCustomDatePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Custom Date Range', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start Date',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 3),
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await _selectCustomDate(context, true);
                    _showCustomDatePicker(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
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
                            fontSize: 12,
                            color: _customStartDate != null
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'End Date',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 3),
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await _selectCustomDate(context, false);
                    _showCustomDatePicker(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
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
                            fontSize: 12,
                            color: _customEndDate != null
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_customStartDate != null && _customEndDate != null)
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFF0A4D2E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Range:',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      '${_customEndDate!.difference(_customStartDate!).inDays + 1} days',
                      style: TextStyle(
                        fontSize: 11,
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
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedTimePeriod = 'custom';
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0A4D2E),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text('Apply', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shop-wise Report', style: TextStyle(fontSize: 18)),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter Section
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF0A4D2E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getSelectedDateRangeText(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0A4D2E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
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
                            label = 'This Month';
                            chipColor = Color(0xFF0A4D2E);
                            break;
                          case 'lastmonth': // Added last month label
                            label = 'Last Month';
                            chipColor = Color(0xFF1A7D4A);
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
                              fontSize: 11,
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        );
                      }).toList(),
                    ),
                    if (_selectedTimePeriod == 'custom')
                      Padding(
                        padding: EdgeInsets.only(top: 12),
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
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      GestureDetector(
                                        onTap: () =>
                                            _selectCustomDate(context, true),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
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
                                                  fontSize: 12,
                                                  color:
                                                      _customStartDate != null
                                                      ? Colors.black
                                                      : Colors.grey,
                                                ),
                                              ),
                                              Icon(
                                                Icons.calendar_today,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'End Date',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      GestureDetector(
                                        onTap: () =>
                                            _selectCustomDate(context, false),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
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
                                                  fontSize: 12,
                                                  color: _customEndDate != null
                                                      ? Colors.black
                                                      : Colors.grey,
                                                ),
                                              ),
                                              Icon(
                                                Icons.calendar_today,
                                                size: 16,
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
                                padding: EdgeInsets.only(top: 6),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Selected Range:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '${_customEndDate!.difference(_customStartDate!).inDays + 1} days',
                                      style: TextStyle(
                                        fontSize: 11,
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
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      height: 36,
                      child: Row(
                        children: [
                          Icon(Icons.store, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedShopId,
                                isExpanded: true,
                                isDense: true,
                                iconSize: 16,
                                hint: Text(
                                  'All Shops',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Text(
                                        'All Shops',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  ...widget.shops.map((shop) {
                                    return DropdownMenuItem<String>(
                                      value: shop['id'] as String?,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          shop['name'] as String,
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedShopId = value;
                                  });
                                },
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
          Expanded(child: _buildShopReport()),
        ],
      ),
    );
  }

  Widget _buildShopReport() {
    List<Sale> filteredSales = _getFilteredSales();

    // Calculate shop-wise totals
    Map<String, Map<String, dynamic>> shopData = {};

    for (var sale in filteredSales) {
      if (!shopData.containsKey(sale.shopId)) {
        String shopName = 'Unknown Shop';

        try {
          final shop = widget.shops.firstWhere(
            (shop) => shop['id'] == sale.shopId,
          );
          shopName = shop['name'] as String;
        } catch (e) {
          shopName = sale.shopName;
        }

        shopData[sale.shopId] = {
          'name': shopName,
          'total': 0.0,
          'transactionCount': 0,
          'categories': <String, Map<String, dynamic>>{},
        };
      }

      var data = shopData[sale.shopId]!;
      data['total'] = (data['total'] as double) + sale.amount;
      data['transactionCount'] = (data['transactionCount'] as int) + 1;

      // Track category-wise totals
      final categories =
          data['categories'] as Map<String, Map<String, dynamic>>;
      if (!categories.containsKey(sale.category)) {
        categories[sale.category] = {'total': 0.0, 'count': 0};
      }
      var categoryData = categories[sale.category]!;
      categoryData['total'] = (categoryData['total'] as double) + sale.amount;
      categoryData['count'] = (categoryData['count'] as int) + 1;
    }

    // Convert to list and sort by total sales (highest first)
    var shopList = shopData.entries.toList()
      ..sort(
        (a, b) =>
            (b.value['total'] as double).compareTo(a.value['total'] as double),
      );

    if (shopList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 48, color: Colors.grey[300]),
            SizedBox(height: 12),
            Text(
              'No sales data available',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: shopList.length,
      itemBuilder: (context, index) {
        var entry = shopList[index];
        var shopId = entry.key;
        var data = entry.value;
        var categories =
            data['categories'] as Map<String, Map<String, dynamic>>;

        // Sort categories in specific order
        List<MapEntry<String, Map<String, dynamic>>> sortedCategories =
            categories.entries.toList()..sort((a, b) {
              // Define custom order for categories
              Map<String, int> categoryOrder = {
                'New Phone': 1,
                'Accessories': 2,
                'Service': 3,
                'Base Model': 4,
                'Second Phone': 5,
              };

              int orderA = categoryOrder[a.key] ?? 999;
              int orderB = categoryOrder[b.key] ?? 999;
              return orderA.compareTo(orderB);
            });

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        data['name'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${data['transactionCount']} sales',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: Color(0xFF1A7D4A),
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Total: ₹${widget.formatNumber(data['total'] as double)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
                SizedBox(height: 12),
                if (sortedCategories.isNotEmpty) ...[
                  Text(
                    'Category Breakdown:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 6),
                  ...sortedCategories.map((categoryEntry) {
                    var categoryName = categoryEntry.key;
                    var categoryData = categoryEntry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: widget.getCategoryColor(categoryName),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${categoryData['count']}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '₹${widget.formatNumber(categoryData['total'] as double)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Color(0xFF0A4D2E),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to get category colors
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'new phone':
        return Color(0xFF4CAF50); // Green
      case 'accessories':
        return Color(0xFF2196F3); // Blue
      case 'service':
        return Color(0xFFFF9800); // Orange
      case 'base model':
        return Color(0xFF9C27B0); // Purple
      case 'second phone':
        return Color(0xFFF44336); // Red
      default:
        return Colors.grey;
    }
  }
}
