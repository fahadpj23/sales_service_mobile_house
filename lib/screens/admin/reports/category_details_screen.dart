import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';

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
  String _timePeriod = 'monthly'; // Default to monthly
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _showCustomDatePicker = false;

  @override
  Widget build(BuildContext context) {
    List<Sale> filteredSales = _filterSales();
    List<Sale> categorySales = filteredSales
        .where((sale) => sale.category == widget.category)
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
          '${widget.category} Details',
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
            // Time Period Filter
            _buildTimePeriodFilter(),

            // Summary Card
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

            // Time Period Label
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

            // Shop-wise Breakdown
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

            // Shop Cards
            ...shopWiseSales.entries.map((entry) {
              String shopName = entry.key;
              List<Sale> shopSales = entry.value;
              double shopTotal = shopSales.fold(
                0.0,
                (sum, sale) => sum + sale.amount,
              );

              return Container(
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
                        // Shop Header
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _expandedShop = _expandedShop == shopName
                                  ? null
                                  : shopName;
                            });
                          },
                          child: Row(
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
                        ),

                        // Shop Summary
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

                        // Detailed Items (Expanded)
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
              );
            }).toList(),

            // No data message
            if (categorySales.isEmpty)
              Container(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'No sales found for ${_getTimePeriodLabel().toLowerCase()}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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

              // Time Period Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTimePeriodChip('Today', 'today', Icons.today),
                  _buildTimePeriodChip('Yesterday', 'yesterday', Icons.history),
                  _buildTimePeriodChip(
                    'Monthly',
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

              // Custom Date Picker
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
            _timePeriod = value;
            _showCustomDatePicker = !_showCustomDatePicker;
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
      });
    }
  }

  List<Sale> _filterSales() {
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_timePeriod) {
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
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1).add(Duration(seconds: -1));
        break;
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          startDate = _customStartDate!;
          endDate = DateTime(
            _customEndDate!.year,
            _customEndDate!.month,
            _customEndDate!.day,
            23,
            59,
            59,
          );
        } else {
          // Default to monthly if custom dates not selected
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

    return widget.sales.where((sale) {
      return sale.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
    }).toList();
  }

  String _getTimePeriodLabel() {
    switch (_timePeriod) {
      case 'today':
        return 'Today\'s Sales';
      case 'yesterday':
        return 'Yesterday\'s Sales';
      case 'monthly':
        return 'Monthly Sales (${DateFormat('MMM yyyy').format(DateTime.now())})';
      case 'yearly':
        return 'Yearly Sales (${DateTime.now().year})';
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          return 'Custom Period: ${DateFormat('dd/MM/yyyy').format(_customStartDate!)} - ${DateFormat('dd/MM/yyyy').format(_customEndDate!)}';
        }
        return 'Custom Period';
      default:
        return 'Monthly Sales (${DateFormat('MMM yyyy').format(DateTime.now())})';
    }
  }

  // ... Rest of the code remains the same (_buildSaleItemCard, _buildInfoRow, _buildPaymentInfo, etc.)
  Widget _buildSaleItemCard(Sale sale) {
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

          if (sale.itemName != null && sale.itemName!.isNotEmpty)
            _buildInfoRow('Product:', sale.itemName!),
          if (sale.model != null && sale.model!.isNotEmpty)
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
          if (sale.brand != null && sale.brand!.isNotEmpty)
            _buildInfoRow('Brand:', sale.brand!),

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
              '${sale.type.replaceAll('_', ' ').toUpperCase()}',
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
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
