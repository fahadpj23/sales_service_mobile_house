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
  Widget build(BuildContext context) {
    List<Sale> filteredSales = _filterSales();

    List<String> categoriesToShow = _getCategoriesForDisplay();

    List<Sale> categorySales = filteredSales
        .where((sale) => categoriesToShow.contains(sale.category))
        .toList();

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
      body: SingleChildScrollView(
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
              child: Text(
                'Shop-wise Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A4D2E),
                ),
              ),
            ),
            SizedBox(height: 8),
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
                    _expandedShop = _expandedShop == shopName ? null : shopName;
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                      color: Color(0xFF1A7D4A).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                              return GestureDetector(
                                onTap: () {},
                                child: _buildSaleItemCard(sale),
                              );
                            }).toList(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
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
                  ],
                ),
              ),
          ],
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
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    // Calculate start and end dates based on selected period
    switch (_timePeriod) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'yesterday':
        final yesterday = now.subtract(Duration(days: 1));
        startDate = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          0,
          0,
          0,
        );
        endDate = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
        );
        break;
      case 'previous_month':
        final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
        final lastDayOfPreviousMonth = firstDayOfCurrentMonth.subtract(
          Duration(days: 1),
        );
        startDate = DateTime(
          lastDayOfPreviousMonth.year,
          lastDayOfPreviousMonth.month,
          1,
          0,
          0,
          0,
        );
        endDate = DateTime(
          lastDayOfPreviousMonth.year,
          lastDayOfPreviousMonth.month,
          lastDayOfPreviousMonth.day,
          23,
          59,
          59,
        );
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1, 0, 0, 0);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          startDate = DateTime(
            _customStartDate!.year,
            _customStartDate!.month,
            _customStartDate!.day,
            0,
            0,
            0,
          );
          endDate = DateTime(
            _customEndDate!.year,
            _customEndDate!.month,
            _customEndDate!.day,
            23,
            59,
            59,
          );
        } else {
          startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        }
        break;
      default:
        startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }

    // Filter sales using the date parameter
    List<Sale> filteredSales = widget.sales.where((sale) {
      // Extract the actual date from the sale
      DateTime saleDate = _extractDateFromSale(sale);

      // Check if the sale date is within the selected range
      bool isInRange =
          saleDate.isAfter(startDate.subtract(Duration(milliseconds: 1))) &&
          saleDate.isBefore(endDate.add(Duration(milliseconds: 1)));

      return isInRange;
    }).toList();

    return filteredSales;
  }

  DateTime _extractDateFromSale(Sale sale) {
    try {
      // Try to get the date from the sale object
      // The date is stored in the 'date' field
      if (sale.date != null) {
        if (sale.date is DateTime) {
          return sale.date as DateTime;
        } else if (sale.date is Timestamp) {
          return (sale.date as Timestamp).toDate();
        } else if (sale.date is int) {
          return DateTime.fromMillisecondsSinceEpoch(sale.date as int);
        }
      }

      // Fallback to current date if no valid date found
      print(
        'Warning: Could not parse date for sale ${sale.id}, using current date',
      );
      return DateTime.now();
    } catch (e) {
      print('Error extracting date from sale: $e');
      return DateTime.now();
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
              Text(
                _formatDate(sale.date),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          Container(
            margin: EdgeInsets.only(top: 4),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getSaleTypeColor(sale.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _getSaleTypeColor(sale.type)),
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
