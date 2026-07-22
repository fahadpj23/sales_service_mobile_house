import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';

class AccessoriesServiceReportScreen extends StatefulWidget {
  final List<Sale> allSales;
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  AccessoriesServiceReportScreen({
    required this.allSales,
    required this.formatNumber,
    required this.shops,
  });

  @override
  _AccessoriesServiceReportScreenState createState() =>
      _AccessoriesServiceReportScreenState();
}

class _AccessoriesServiceReportScreenState
    extends State<AccessoriesServiceReportScreen> {
  String _selectedTimePeriod = 'monthly';
  String? _selectedShop;

  List<Map<String, dynamic>> _timePeriods = [
    {'label': 'Monthly', 'value': 'monthly'},
    {'label': 'Daily', 'value': 'daily'},
    {'label': 'Yesterday', 'value': 'yesterday'},
    {'label': 'Last Month', 'value': 'last_month'},
    {'label': 'Yearly', 'value': 'yearly'},
  ];

  List<Sale> _getFilteredSales() {
    DateTime startDate;
    DateTime endDate;
    DateTime now = DateTime.now();

    switch (_selectedTimePeriod) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'yesterday':
        final yesterday = now.subtract(Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'last_month':
        final firstDayOfLastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = firstDayOfLastMonth;
        endDate = DateTime(now.year, now.month, 1).add(Duration(seconds: -1));
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
      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
    }

    return widget.allSales.where((sale) {
      if (sale.type != 'accessories_service_sale') return false;
      if (_selectedShop != null && sale.shopName != _selectedShop) return false;
      return sale.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    List<Sale> filteredSales = _getFilteredSales();

    double totalService = filteredSales.fold(
      0.0,
      (sum, sale) => sum + (sale.serviceAmount ?? 0),
    );
    double totalAccessories = filteredSales.fold(
      0.0,
      (sum, sale) => sum + (sale.accessoriesAmount ?? 0),
    );
    double totalCombined = totalService + totalAccessories;

    // Calculate payment method totals
    double totalCash = filteredSales.fold(
      0.0,
      (sum, sale) => sum + (sale.cashAmount ?? 0),
    );
    double totalCard = filteredSales.fold(
      0.0,
      (sum, sale) => sum + (sale.cardAmount ?? 0),
    );
    double totalGpay = filteredSales.fold(
      0.0,
      (sum, sale) => sum + (sale.gpayAmount ?? 0),
    );

    Map<String, List<Sale>> shopGroups = {};
    for (var sale in filteredSales) {
      if (!shopGroups.containsKey(sale.shopName)) {
        shopGroups[sale.shopName] = [];
      }
      shopGroups[sale.shopName]!.add(sale);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Accessories & Service Report',
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
            // Filter Section
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
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _timePeriods.map((period) {
                          bool isSelected =
                              _selectedTimePeriod == period['value'];
                          return FilterChip(
                            label: Text(
                              period['label'],
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
                              setState(() {
                                _selectedTimePeriod = period['value'];
                              });
                            },
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: Color(0xFF1A7D4A),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedShop,
                            isExpanded: true,
                            hint: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('All Shops'),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('All Shops'),
                                ),
                              ),
                              ...widget.shops.map<DropdownMenuItem<String>>((
                                shop,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: shop['name'] as String?,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(shop['name'] as String),
                                  ),
                                );
                              }).toList(),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedShop = value;
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

            // Summary Cards - Now includes Payment Summary
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
                  _buildSummaryCard(
                    'Total Combined',
                    '₹${widget.formatNumber(totalCombined)}',
                    Icons.currency_rupee,
                    Color(0xFF0A4D2E),
                  ),
                  _buildSummaryCard(
                    'Service Amount',
                    '₹${widget.formatNumber(totalService)}',
                    Icons.build,
                    Color(0xFF2196F3),
                  ),
                  _buildSummaryCard(
                    'Accessories Amount',
                    '₹${widget.formatNumber(totalAccessories)}',
                    Icons.shopping_bag,
                    Color(0xFF9C27B0),
                  ),
                  _buildPaymentSummaryCard(totalCash, totalCard, totalGpay),
                ],
              ),
            ),

            // Transactions Summary
            Container(
              padding: EdgeInsets.all(16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Shop-wise Breakdown Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Shop-wise Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A4D2E),
                ),
              ),
            ),
            SizedBox(height: 12),

            // Shop-wise Breakdown
            ...shopGroups.entries.map((entry) {
              String shopName = entry.key;
              List<Sale> shopSales = entry.value;

              double shopService = shopSales.fold(
                0.0,
                (sum, sale) => sum + (sale.serviceAmount ?? 0),
              );
              double shopAccessories = shopSales.fold(
                0.0,
                (sum, sale) => sum + (sale.accessoriesAmount ?? 0),
              );
              double shopCombined = shopService + shopAccessories;

              double shopCash = shopSales.fold(
                0.0,
                (sum, sale) => sum + (sale.cashAmount ?? 0),
              );
              double shopCard = shopSales.fold(
                0.0,
                (sum, sale) => sum + (sale.cardAmount ?? 0),
              );
              double shopGpay = shopSales.fold(
                0.0,
                (sum, sale) => sum + (sale.gpayAmount ?? 0),
              );

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
                      shopName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${shopSales.length} transactions'),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${widget.formatNumber(shopCombined)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Shop Payment Summary
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Payment Breakdown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0A4D2E),
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildSmallPaymentChip(
                                        'Cash',
                                        shopCash,
                                        Icons.attach_money,
                                        Color(0xFF4CAF50),
                                      ),
                                      _buildSmallPaymentChip(
                                        'Card',
                                        shopCard,
                                        Icons.credit_card,
                                        Color(0xFF2196F3),
                                      ),
                                      _buildSmallPaymentChip(
                                        'GPay',
                                        shopGpay,
                                        Icons.phone_android,
                                        Color(0xFF9C27B0),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),

                            // Service and Accessories breakdown
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Service Amount',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '₹${widget.formatNumber(shopService)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Accessories Amount',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '₹${widget.formatNumber(shopAccessories)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF9C27B0),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Divider(),
                            SizedBox(height: 8),

                            // Individual transaction details
                            ...shopSales.map((sale) {
                              return ListTile(
                                dense: true,
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat(
                                        'dd MMM yyyy',
                                      ).format(sale.date),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Service: ₹${widget.formatNumber(sale.serviceAmount ?? 0)} | Accessories: ₹${widget.formatNumber(sale.accessoriesAmount ?? 0)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Row(
                                  children: [
                                    if ((sale.cashAmount ?? 0) > 0)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        margin: EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: Color(
                                            0xFF4CAF50,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: Color(
                                              0xFF4CAF50,
                                            ).withOpacity(0.2),
                                          ),
                                        ),
                                        child: Text(
                                          'Cash: ₹${widget.formatNumber(sale.cashAmount ?? 0)}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Color(0xFF4CAF50),
                                          ),
                                        ),
                                      ),
                                    if ((sale.cardAmount ?? 0) > 0)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        margin: EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: Color(
                                            0xFF2196F3,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: Color(
                                              0xFF2196F3,
                                            ).withOpacity(0.2),
                                          ),
                                        ),
                                        child: Text(
                                          'Card: ₹${widget.formatNumber(sale.cardAmount ?? 0)}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Color(0xFF2196F3),
                                          ),
                                        ),
                                      ),
                                    if ((sale.gpayAmount ?? 0) > 0)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color(
                                            0xFF9C27B0,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: Color(
                                              0xFF9C27B0,
                                            ).withOpacity(0.2),
                                          ),
                                        ),
                                        child: Text(
                                          'GPay: ₹${widget.formatNumber(sale.gpayAmount ?? 0)}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Color(0xFF9C27B0),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  '₹${widget.formatNumber(sale.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0A4D2E),
                                  ),
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

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 110, maxHeight: 110),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSummaryCard(double cash, double card, double gpay) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 110, maxHeight: 110),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cash Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.attach_money, color: Color(0xFF4CAF50), size: 14),
                  SizedBox(width: 4),
                  Text(
                    '₹${widget.formatNumber(cash)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Cash',
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  ),
                ],
              ),
              // Card Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.credit_card, color: Color(0xFF2196F3), size: 14),
                  SizedBox(width: 4),
                  Text(
                    '₹${widget.formatNumber(card)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Card',
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  ),
                ],
              ),
              // GPay Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_android, color: Color(0xFF9C27B0), size: 14),
                  SizedBox(width: 4),
                  Text(
                    '₹${widget.formatNumber(gpay)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9C27B0),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'GPay',
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallPaymentChip(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          SizedBox(width: 4),
          Text(
            '$title: ₹${widget.formatNumber(amount)}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
