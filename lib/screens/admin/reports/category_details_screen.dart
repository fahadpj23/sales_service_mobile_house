import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryDetailsScreen extends StatefulWidget {
  final String category;
  final List<Sale> sales;
  final String Function(double) formatNumber;
  final Color Function(String) getCategoryColor;

  const CategoryDetailsScreen({
    required this.category,
    required this.sales,
    required this.formatNumber,
    required this.getCategoryColor,
    Key? key,
  }) : super(key: key);

  @override
  _CategoryDetailsScreenState createState() => _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends State<CategoryDetailsScreen> {
  String? _expandedShop;
  String _timePeriod = 'monthly';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _showCustomDatePicker = false;

  @override
  void initState() {
    super.initState();
    _debugCheckDates();
  }

  void _debugCheckDates() {
    print('=== DEBUG: Total sales received: ${widget.sales.length} ===');
    int validDates = 0;
    int nullDates = 0;

    for (var sale in widget.sales) {
      if (sale.category == 'Base Model' || sale.category == 'Second Phone') {
        print('Sale ID: ${sale.id}');
        print('  Type: ${sale.type}');
        print('  Category: ${sale.category}');
        print('  Date object: ${sale.date}');
        print('  Date type: ${sale.date.runtimeType}');
        print('  Amount: ${sale.amount}');
        print('---');

        if (sale.date != null) {
          validDates++;
        } else {
          nullDates++;
        }
      }
    }
    print('=== Valid dates: $validDates, Null dates: $nullDates ===');
  }

  @override
  Widget build(BuildContext context) {
    List<Sale> filteredSales = _filterSales();

    print('=== Filtered sales count: ${filteredSales.length} ===');

    List<String> categoriesToShow = _getCategoriesForDisplay();

    List<Sale> categorySales = filteredSales
        .where((sale) => categoriesToShow.contains(sale.category))
        .toList();

    print('=== Category sales count: ${categorySales.length} ===');

    Map<String, List<Sale>> shopWiseSales = {};
    for (var sale in categorySales) {
      if (!shopWiseSales.containsKey(sale.shopName)) {
        shopWiseSales[sale.shopName] = [];
      }
      shopWiseSales[sale.shopName]!.add(sale);
    }

    double totalSales = categorySales.fold(
      0.0,
      (sum, sale) => sum + sale.amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getDisplayTitle(),
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
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          return Future.value();
        },
        color: Color(0xFF0A4D2E),
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildTimePeriodFilter(),
              Container(
                padding: EdgeInsets.all(16),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Total Sales',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '₹${widget.formatNumber(totalSales)}',
                              style: TextStyle(
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
                              'Total Items',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${categorySales.length}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A7D4A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Color(0xFF0A4D2E),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _getTimePeriodLabel(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0A4D2E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Shop-wise Breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    if (categorySales.isNotEmpty)
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
                          '${shopWiseSales.length} Shops',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0A4D2E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              if (categorySales.isEmpty)
                Container(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        'No sales found for ${_getDisplayTitle().toLowerCase()} in ${_getTimePeriodLabel().toLowerCase()}',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Try selecting a different time period',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      SizedBox(height: 16),
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
                            icon: Icon(Icons.arrow_back),
                            label: Text('Previous Month'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0A4D2E),
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
                            icon: Icon(Icons.calendar_today),
                            label: Text('Yearly'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0A4D2E),
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
                            icon: Icon(Icons.all_inclusive),
                            label: Text('All Time'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0A4D2E),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                ...shopWiseSales.entries.map((entry) {
                  String shopName = entry.key;
                  List<Sale> shopSales = entry.value;
                  double shopTotal = shopSales.fold(
                    0.0,
                    (sum, sale) => sum + sale.amount,
                  );

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedShop = _expandedShop == shopName
                            ? null
                            : shopName;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      shopName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color(
                                            0xFF1A7D4A,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '${shopSales.length} items',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF1A7D4A),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        _expandedShop == shopName
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: Color(0xFF0A4D2E),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total: ₹${widget.formatNumber(shopTotal)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0A4D2E),
                                        ),
                                      ),
                                      Text(
                                        'Avg: ₹${widget.formatNumber(shopTotal / shopSales.length)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (_expandedShop == shopName) ...[
                                SizedBox(height: 16),
                                Divider(),
                                SizedBox(height: 8),
                                Text(
                                  'Items Details:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF0A4D2E),
                                  ),
                                ),
                                SizedBox(height: 8),
                                ...shopSales.map((sale) {
                                  return _buildSaleItemCard(sale);
                                }).toList(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getCategoriesForDisplay() {
    switch (widget.category) {
      case 'Second Phone':
        return ['Second Phone', 'seconds_phone_sale'];
      case 'Base Model':
        return ['Base Model', 'base_model_sale'];
      case 'New Phone':
        return ['New Phone', 'phone_sale'];
      case 'Service':
        return ['Service', 'accessories_service_sale'];
      default:
        return [widget.category];
    }
  }

  String _getDisplayTitle() {
    switch (widget.category) {
      case 'Second Phone':
        return 'Second Phone Sales';
      case 'Base Model':
        return 'Base Model Sales';
      case 'New Phone':
        return 'New Phone Sales';
      case 'Service':
        return 'Service & Accessories Sales';
      default:
        return '${widget.category} Details';
    }
  }

  Widget _buildTimePeriodFilter() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_alt, size: 18, color: Color(0xFF0A4D2E)),
                  SizedBox(width: 8),
                  Text(
                    'Filter by Time Period',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0A4D2E),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
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
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 8),
                Text(
                  'Select Custom Date Range:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
                SizedBox(height: 12),
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
                          SizedBox(height: 4),
                          InkWell(
                            onTap: () => _selectStartDate(context),
                            child: Container(
                              padding: EdgeInsets.all(12),
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
                                    color: Color(0xFF0A4D2E),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
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
                          SizedBox(height: 4),
                          InkWell(
                            onTap: () => _selectEndDate(context),
                            child: Container(
                              padding: EdgeInsets.all(12),
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
                                    color: Color(0xFF0A4D2E),
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
                SizedBox(height: 12),
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
                    SizedBox(width: 8),
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
                        backgroundColor: Color(0xFF0A4D2E),
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Apply Filter'),
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
            color: isSelected ? Colors.white : Color(0xFF0A4D2E),
          ),
          SizedBox(width: 4),
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
      selectedColor: Color(0xFF0A4D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
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
            primaryColor: Color(0xFF0A4D2E),
            colorScheme: ColorScheme.light(primary: Color(0xFF0A4D2E)),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
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
            primaryColor: Color(0xFF0A4D2E),
            colorScheme: ColorScheme.light(primary: Color(0xFF0A4D2E)),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
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

  List<Sale> _filterSales() {
    // First, filter by category
    List<String> categoriesToShow = _getCategoriesForDisplay();
    List<Sale> categoryFilteredSales = widget.sales
        .where((sale) => categoriesToShow.contains(sale.category))
        .toList();

    print('=== Category filtered sales: ${categoryFilteredSales.length} ===');

    // If no sales in this category, return empty list
    if (categoryFilteredSales.isEmpty) {
      return [];
    }

    // Handle All Time filter separately
    if (_timePeriod == 'all_time') {
      print('Showing all time sales: ${categoryFilteredSales.length}');
      return categoryFilteredSales;
    }

    // Get current date
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    // Calculate date range based on selected period
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
          Duration(days: 1),
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
          // Default to current month if custom dates not set
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0);
        }
        break;

      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
    }

    print('Filter period: $_timePeriod');
    print('Start date: ${DateFormat('yyyy-MM-dd').format(startDate)}');
    print('End date: ${DateFormat('yyyy-MM-dd').format(endDate)}');

    // Filter by date range
    List<Sale> dateFilteredSales = categoryFilteredSales.where((sale) {
      DateTime? saleDate = _extractDateFromSale(sale);

      if (saleDate == null) {
        print('Warning: Sale ${sale.id} has no valid date');
        return false;
      }

      // Extract just the date part for comparison
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

      // Check if sale date is within range (inclusive)
      bool isInRange =
          (saleDateOnly.isAfter(startDateOnly.subtract(Duration(days: 1))) &&
          saleDateOnly.isBefore(endDateOnly.add(Duration(days: 1))));

      if (isInRange) {
        print(
          'Sale ${sale.id} date ${DateFormat('yyyy-MM-dd').format(saleDate)} is IN range',
        );
      } else {
        print(
          'Sale ${sale.id} date ${DateFormat('yyyy-MM-dd').format(saleDate)} is OUT of range',
        );
      }

      return isInRange;
    }).toList();

    print(
      'Final filtered sales: ${dateFilteredSales.length} out of ${categoryFilteredSales.length}',
    );

    return dateFilteredSales;
  }

  DateTime? _extractDateFromSale(Sale sale) {
    try {
      // Direct access to sale.date property
      if (sale.date != null) {
        if (sale.date is DateTime) {
          return sale.date as DateTime;
        } else if (sale.date is Timestamp) {
          return (sale.date as Timestamp).toDate();
        } else if (sale.date is int) {
          return DateTime.fromMillisecondsSinceEpoch(sale.date as int);
        }
      }

      // For debugging purposes
      print(
        'Could not extract valid date for sale: ${sale.id}, type: ${sale.type}, category: ${sale.category}',
      );
      print('  sale.date value: ${sale.date}');
      print('  sale.date type: ${sale.date.runtimeType}');

      return null;
    } catch (e) {
      print('Error extracting date from sale: $e');
      return null;
    }
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

  Widget _buildSaleItemCard(Sale sale) {
    String displayName = '';

    if (sale.type == 'seconds_phone_sale') {
      displayName = sale.itemName ?? sale.productName ?? 'Second Phone';
    } else if (sale.type == 'base_model_sale') {
      displayName = sale.model ?? sale.itemName ?? 'Base Model Phone';
    } else if (sale.type == 'phone_sale') {
      displayName = sale.model ?? sale.itemName ?? 'New Phone';
    } else if (sale.type == 'accessories_service_sale') {
      displayName = sale.itemName ?? 'Service & Accessories';
    } else {
      displayName = sale.itemName ?? sale.model ?? 'Product';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
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
              Text(
                '₹${widget.formatNumber(sale.amount)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A4D2E),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSaleTypeColor(sale.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getDisplayTypeName(sale.type),
                  style: TextStyle(
                    fontSize: 10,
                    color: _getSaleTypeColor(sale.type),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (displayName.isNotEmpty) _buildInfoRow('Product:', displayName),
          if (sale.brand != null && sale.brand!.isNotEmpty)
            _buildInfoRow('Brand:', sale.brand!),
          if (sale.model != null &&
              sale.model!.isNotEmpty &&
              sale.model != displayName)
            _buildInfoRow('Model:', sale.model!),
          if (sale.imei != null && sale.imei!.isNotEmpty)
            _buildInfoRow('IMEI:', sale.imei!),
          if (sale.customerName != null && sale.customerName!.isNotEmpty)
            _buildInfoRow('Customer:', sale.customerName!),
          if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
            _buildInfoRow('Phone:', sale.customerPhone!),
          SizedBox(height: 8),
          _buildPaymentInfo(sale),
          if (sale.defect != null && sale.defect!.isNotEmpty)
            _buildInfoRow('Defect:', sale.defect!),
          if (sale.salesPersonName != null && sale.salesPersonName!.isNotEmpty)
            _buildInfoRow('Sales Person:', sale.salesPersonName!),
          if (sale.salesPersonEmail != null &&
              sale.salesPersonEmail!.isNotEmpty)
            _buildInfoRow('Sales Email:', sale.salesPersonEmail!),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
              SizedBox(width: 4),
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

  String _getDisplayTypeName(String type) {
    switch (type) {
      case 'phone_sale':
        return 'NEW PHONE';
      case 'base_model_sale':
        return 'BASE MODEL';
      case 'seconds_phone_sale':
        return 'SECOND PHONE';
      case 'accessories_service_sale':
        return 'SERVICE & ACCESSORIES';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
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
          SizedBox(width: 8),
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

    if (sale.cashAmount != null && sale.cashAmount! > 0) {
      paymentMethods.add(
        Chip(
          label: Text('Cash: ₹${widget.formatNumber(sale.cashAmount!)}'),
          backgroundColor: Colors.green[50],
          labelStyle: TextStyle(fontSize: 10),
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    if (sale.gpayAmount != null && sale.gpayAmount! > 0) {
      paymentMethods.add(
        Chip(
          label: Text('GPay: ₹${widget.formatNumber(sale.gpayAmount!)}'),
          backgroundColor: Colors.blue[50],
          labelStyle: TextStyle(fontSize: 10),
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    if (sale.cardAmount != null && sale.cardAmount! > 0) {
      paymentMethods.add(
        Chip(
          label: Text('Card: ₹${widget.formatNumber(sale.cardAmount!)}'),
          backgroundColor: Colors.orange[50],
          labelStyle: TextStyle(fontSize: 10),
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    if (paymentMethods.isEmpty) return SizedBox();

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
        SizedBox(height: 4),
        Wrap(spacing: 4, runSpacing: 4, children: paymentMethods),
        SizedBox(height: 8),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';

    try {
      if (date is DateTime) {
        return DateFormat('dd/MM/yyyy').format(date);
      } else if (date is Timestamp) {
        return DateFormat('dd/MM/yyyy').format(date.toDate());
      } else if (date is int) {
        return DateFormat(
          'dd/MM/yyyy',
        ).format(DateTime.fromMillisecondsSinceEpoch(date));
      }
      return 'Invalid Date';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Color _getSaleTypeColor(String saleType) {
    switch (saleType) {
      case 'phone_sale':
        return Colors.green;
      case 'base_model_sale':
        return Colors.blue;
      case 'seconds_phone_sale':
        return Colors.purple;
      case 'accessories_service_sale':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
