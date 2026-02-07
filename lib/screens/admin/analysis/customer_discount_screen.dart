import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';

class CustomerDiscountScreen extends StatefulWidget {
  final List<Sale> allSales;
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  const CustomerDiscountScreen({
    Key? key,
    required this.allSales,
    required this.formatNumber,
    required this.shops,
  }) : super(key: key);

  @override
  _CustomerDiscountScreenState createState() => _CustomerDiscountScreenState();
}

class _CustomerDiscountScreenState extends State<CustomerDiscountScreen> {
  final DateTime _selectedDate = DateTime.now();
  String _timePeriod = 'monthly';
  bool _isCustomPeriod = false;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  final Color primaryGreen = Color(0xFF0A4D2E);
  final Color secondaryGreen = Color(0xFF1A7D4A);
  final Color lightGreen = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        title: Text(
          'Customer Discount',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    List<Sale> filteredSales = _filterSales();
    double totalDiscount = _calculateTotalDiscount(filteredSales);
    int discountCount = _countSalesWithDiscount(filteredSales);

    return Column(
      children: [
        // Header Section
        Container(
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getPeriodLabel(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '₹${widget.formatNumber(totalDiscount)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          '$discountCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              if (_isCustomPeriod &&
                  _customStartDate != null &&
                  _customEndDate != null)
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.white70),
                    SizedBox(width: 4),
                    Text(
                      '${DateFormat('dd MMM').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Time Period Selector
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: primaryGreen),
                      SizedBox(width: 6),
                      Text(
                        'Time Period',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 36,
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _isCustomPeriod
                            ? 'Custom Range'
                            : _getPeriodLabel(),
                        isExpanded: true,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color: primaryGreen,
                        ),
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        items:
                            [
                              'Daily',
                              'Yesterday',
                              'Last Month',
                              'Monthly',
                              'Yearly',
                              'Custom Range',
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue == 'Custom Range') {
                            _showCustomDateRangePicker();
                          } else {
                            setState(() {
                              _isCustomPeriod = false;
                              switch (newValue) {
                                case 'Daily':
                                  _timePeriod = 'daily';
                                  break;
                                case 'Yesterday':
                                  _timePeriod = 'yesterday';
                                  break;
                                case 'Last Month':
                                  _timePeriod = 'last_month';
                                  break;
                                case 'Monthly':
                                  _timePeriod = 'monthly';
                                  break;
                                case 'Yearly':
                                  _timePeriod = 'yearly';
                                  break;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Main Content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                // Summary Card
                _buildSummaryCard(filteredSales),
                SizedBox(height: 8),

                // Category-wise Report
                _buildCategoryWiseReport(filteredSales),
                SizedBox(height: 8),

                // Shop-wise Report
                _buildShopWiseReport(filteredSales),
                SizedBox(height: 8),

                // Transaction List
                _buildTransactionList(filteredSales),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(List<Sale> filteredSales) {
    double totalDiscount = _calculateTotalDiscount(filteredSales);
    int discountCount = _countSalesWithDiscount(filteredSales);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Discount',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                Text(
                  '₹${widget.formatNumber(totalDiscount)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Transactions',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                Text(
                  '$discountCount',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: secondaryGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryWiseReport(List<Sale> filteredSales) {
    Map<String, double> discountByCategory = {
      'Phone Sales': 0.0,
      'Second Hand': 0.0,
      'Base Model': 0.0,
    };

    Map<String, int> countByCategory = {
      'Phone Sales': 0,
      'Second Hand': 0,
      'Base Model': 0,
    };

    for (var sale in filteredSales) {
      double saleDiscount = sale.discount ?? 0.0;
      if (saleDiscount > 0) {
        if (sale.type == 'phone_sale') {
          discountByCategory['Phone Sales'] =
              discountByCategory['Phone Sales']! + saleDiscount;
          countByCategory['Phone Sales'] = countByCategory['Phone Sales']! + 1;
        } else if (sale.type == 'seconds_phone_sale') {
          discountByCategory['Second Hand'] =
              discountByCategory['Second Hand']! + saleDiscount;
          countByCategory['Second Hand'] = countByCategory['Second Hand']! + 1;
        } else if (sale.type == 'base_model_sale') {
          discountByCategory['Base Model'] =
              discountByCategory['Base Model']! + saleDiscount;
          countByCategory['Base Model'] = countByCategory['Base Model']! + 1;
        }
      }
    }

    var entries =
        discountByCategory.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.category, size: 16, color: primaryGreen),
                  SizedBox(width: 6),
                  Text(
                    'Category-wise Report',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Center(
                child: Text(
                  'No discounts by category',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    double totalDiscount = _calculateTotalDiscount(filteredSales);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, size: 16, color: primaryGreen),
                SizedBox(width: 6),
                Text(
                  'Category-wise Report',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            ...entries.map((entry) {
              String category = entry.key;
              double discount = entry.value;
              int count = countByCategory[category]!;
              double percentage = totalDiscount > 0
                  ? (discount / totalDiscount * 100)
                  : 0;

              Color color;
              IconData icon;

              switch (category) {
                case 'Phone Sales':
                  color = Color(0xFF4CAF50);
                  icon = Icons.phone_android;
                  break;
                case 'Second Hand':
                  color = Color(0xFF9C27B0);
                  icon = Icons.phone_iphone_outlined;
                  break;
                case 'Base Model':
                  color = Color(0xFF2196F3);
                  icon = Icons.phone_iphone;
                  break;
                default:
                  color = Colors.grey;
                  icon = Icons.category;
              }

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Icon(icon, size: 18, color: color)),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹${widget.formatNumber(discount)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              Text(
                                '${percentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildShopWiseReport(List<Sale> filteredSales) {
    Map<String, double> discountByShop = {};
    Map<String, int> countByShop = {};

    for (var shop in widget.shops) {
      discountByShop[shop['name']] = 0.0;
      countByShop[shop['name']] = 0;
    }

    for (var sale in filteredSales) {
      double saleDiscount = sale.discount ?? 0.0;
      if (saleDiscount > 0 && discountByShop.containsKey(sale.shopName)) {
        discountByShop[sale.shopName] =
            discountByShop[sale.shopName]! + saleDiscount;
        countByShop[sale.shopName] = countByShop[sale.shopName]! + 1;
      }
    }

    var sortedShops =
        discountByShop.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedShops.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.store, size: 16, color: primaryGreen),
                  SizedBox(width: 6),
                  Text(
                    'Shop-wise Report',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Center(
                child: Text(
                  'No discounts by shop',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    double totalDiscount = _calculateTotalDiscount(filteredSales);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, size: 16, color: primaryGreen),
                SizedBox(width: 6),
                Text(
                  'Shop-wise Report',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            ...sortedShops.map((entry) {
              String shopName = entry.key;
              double discount = entry.value;
              int count = countByShop[shopName]!;
              double percentage = totalDiscount > 0
                  ? (discount / totalDiscount * 100)
                  : 0;

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: secondaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.store,
                          size: 18,
                          color: secondaryGreen,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  shopName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: secondaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: secondaryGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹${widget.formatNumber(discount)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: secondaryGreen,
                                ),
                              ),
                              Text(
                                '${percentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<Sale> filteredSales) {
    List<Sale> salesWithDiscount =
        filteredSales.where((sale) => (sale.discount ?? 0) > 0).toList()
          ..sort((a, b) => (b.discount ?? 0).compareTo(a.discount ?? 0));

    if (salesWithDiscount.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.money_off, size: 48, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'No discounts found',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try selecting a different time period',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list, size: 16, color: primaryGreen),
                SizedBox(width: 6),
                Text(
                  'All Discounts',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: secondaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${salesWithDiscount.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            ...salesWithDiscount.take(10).map((sale) {
              double saleDiscount = sale.discount ?? 0.0;
              Color color = _getSaleTypeColor(sale.type);
              IconData icon = _getSaleTypeIcon(sale.type);

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, size: 16, color: color),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  sale.itemName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '₹${widget.formatNumber(saleDiscount)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF44336),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sale.customerName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      sale.shopName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    DateFormat('dd MMM').format(sale.date),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Sale: ₹${widget.formatNumber(sale.amount)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (salesWithDiscount.length > 10)
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '+ ${salesWithDiscount.length - 10} more discounts',
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getSaleTypeColor(String type) {
    switch (type) {
      case 'phone_sale':
        return Color(0xFF4CAF50);
      case 'seconds_phone_sale':
        return Color(0xFF9C27B0);
      case 'base_model_sale':
        return Color(0xFF2196F3);
      default:
        return Colors.grey;
    }
  }

  IconData _getSaleTypeIcon(String type) {
    switch (type) {
      case 'phone_sale':
        return Icons.phone_android;
      case 'seconds_phone_sale':
        return Icons.phone_iphone_outlined;
      case 'base_model_sale':
        return Icons.phone_iphone;
      default:
        return Icons.category;
    }
  }

  Future<void> _showCustomDateRangePicker() async {
    DateTime startDate =
        _customStartDate ?? DateTime.now().subtract(Duration(days: 7));
    DateTime endDate = _customEndDate ?? DateTime.now();

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
      );
      _customEndDate = DateTime(
        pickedEndDate.year,
        pickedEndDate.month,
        pickedEndDate.day,
        23,
        59,
        59,
      );
      _isCustomPeriod = true;
      _timePeriod = 'custom';
    });
  }

  List<Sale> _filterSales() {
    DateTime startDate;
    DateTime endDate;

    if (_isCustomPeriod && _customStartDate != null && _customEndDate != null) {
      startDate = _customStartDate!;
      endDate = _customEndDate!;
    } else {
      switch (_timePeriod) {
        case 'daily':
          startDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
          );
          endDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            23,
            59,
            59,
          );
          break;
        case 'yesterday':
          final yesterday = _selectedDate.subtract(Duration(days: 1));
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
          final firstDayOfLastMonth = DateTime(
            _selectedDate.year,
            _selectedDate.month - 1,
            1,
          );
          startDate = firstDayOfLastMonth;
          endDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            0,
            23,
            59,
            59,
          );
          break;
        case 'monthly':
          startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
          endDate = DateTime(
            _selectedDate.year,
            _selectedDate.month + 1,
            0,
            23,
            59,
            59,
          );
          break;
        case 'yearly':
          startDate = DateTime(_selectedDate.year, 1, 1);
          endDate = DateTime(_selectedDate.year, 12, 31, 23, 59, 59);
          break;
        default:
          startDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
          );
          endDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            23,
            59,
            59,
          );
      }
    }

    return widget.allSales.where((sale) {
      return sale.date.isAfter(startDate.subtract(Duration(milliseconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(milliseconds: 1)));
    }).toList();
  }

  double _calculateTotalDiscount(List<Sale> sales) {
    return sales.fold(0.0, (sum, sale) => sum + (sale.discount ?? 0));
  }

  int _countSalesWithDiscount(List<Sale> sales) {
    return sales.where((sale) => (sale.discount ?? 0) > 0).length;
  }

  String _getPeriodLabel() {
    if (_isCustomPeriod) {
      return 'Custom Range';
    }

    switch (_timePeriod) {
      case 'daily':
        return 'Daily';
      case 'yesterday':
        return 'Yesterday';
      case 'last_month':
        return 'Last Month';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return 'Monthly';
    }
  }
}
