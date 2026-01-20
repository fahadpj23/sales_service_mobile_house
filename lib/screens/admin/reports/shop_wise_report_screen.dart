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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shop-wise Report'),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Shop Filter Dropdown
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedShopId,
                  decoration: InputDecoration(
                    labelText: 'Select Shop',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Shops'),
                    ),
                    ...widget.shops.map((shop) {
                      return DropdownMenuItem<String>(
                        value: shop['id'] as String?,
                        child: Text(shop['name'] as String),
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
          ),
          Expanded(child: _buildShopReport()),
        ],
      ),
    );
  }

  Widget _buildShopReport() {
    // Filter sales by selected shop
    List<Sale> filteredSales = _selectedShopId == null
        ? widget.allSales
        : widget.allSales
              .where((sale) => sale.shopId == _selectedShopId)
              .toList();

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
        child: Text(
          'No sales data available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
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

        return Card(
          margin: EdgeInsets.all(8),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${data['transactionCount']} sales',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Color(0xFF1A7D4A),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Total: ₹${widget.formatNumber(data['total'] as double)}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                if (categories.isNotEmpty) ...[
                  Text(
                    'Category Breakdown:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  ...categories.entries.map((categoryEntry) {
                    var categoryName = categoryEntry.key;
                    var categoryData = categoryEntry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: widget.getCategoryColor(categoryName),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(child: Text(categoryName)),
                          Text(
                            '${categoryData['count']} sales',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          SizedBox(width: 16),
                          Text(
                            '₹${widget.formatNumber(categoryData['total'] as double)}',
                            style: TextStyle(fontWeight: FontWeight.w600),
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
}
