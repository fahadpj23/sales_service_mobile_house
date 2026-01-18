import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';

class SalesDetailsScreen extends StatelessWidget {
  final String title;
  final List<Sale> sales;
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  SalesDetailsScreen({
    required this.title,
    required this.sales,
    required this.formatNumber,
    required this.shops,
  });

  @override
  Widget build(BuildContext context) {
    double totalSales = sales.fold(0.0, (sum, sale) => sum + sale.amount);

    // Group by shop
    Map<String, List<Sale>> shopGroups = {};
    for (var sale in sales) {
      if (!shopGroups.containsKey(sale.shopName)) {
        shopGroups[sale.shopName] = [];
      }
      shopGroups[sale.shopName]!.add(sale);
    }

    // Group by category
    Map<String, List<Sale>> categoryGroups = {};
    for (var sale in sales) {
      if (!categoryGroups.containsKey(sale.category)) {
        categoryGroups[sale.category] = [];
      }
      categoryGroups[sale.category]!.add(sale);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
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
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              color: Color(0xFF0A4D2E),
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: 'Summary'),
                  Tab(text: 'Shop-wise'),
                  Tab(text: 'Category-wise'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSummaryTab(totalSales),
                  _buildShopWiseTab(shopGroups),
                  _buildCategoryWiseTab(categoryGroups),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab(double totalSales) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.analytics, size: 64, color: Color(0xFF0A4D2E)),
                    SizedBox(height: 16),
                    Text(
                      'Total Sales',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '₹${formatNumber(totalSales)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A7D4A),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '${sales.length} transactions',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Distribution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildDistributionItem(
                      'Cash Sales',
                      Icons.currency_rupee,
                      sales.fold(
                        0.0,
                        (sum, sale) => sum + (sale.cashAmount ?? 0),
                      ),
                      Color(0xFF4CAF50),
                    ),
                    _buildDistributionItem(
                      'Card Sales',
                      Icons.credit_card,
                      sales.fold(
                        0.0,
                        (sum, sale) => sum + (sale.cardAmount ?? 0),
                      ),
                      Color(0xFF2196F3),
                    ),
                    _buildDistributionItem(
                      'GPay Sales',
                      Icons.payment,
                      sales.fold(
                        0.0,
                        (sum, sale) => sum + (sale.gpayAmount ?? 0),
                      ),
                      Color(0xFF9C27B0),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionItem(
    String title,
    IconData icon,
    double amount,
    Color color,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14)),
                Text(
                  '₹${formatNumber(amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopWiseTab(Map<String, List<Sale>> shopGroups) {
    List<Map<String, dynamic>> shopData = [];
    shopGroups.forEach((shopName, sales) {
      double total = sales.fold(0.0, (sum, sale) => sum + sale.amount);
      shopData.add({
        'shopName': shopName,
        'total': total,
        'count': sales.length,
        'sales': sales,
      });
    });

    shopData.sort((a, b) => b['total'].compareTo(a['total']));

    return ListView.builder(
      itemCount: shopData.length,
      itemBuilder: (context, index) {
        var data = shopData[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: Icon(Icons.store, color: Color(0xFF1A7D4A)),
            title: Text(
              data['shopName'],
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${data['count']} sales'),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${formatNumber(data['total'])}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
                Text(
                  'Avg: ₹${formatNumber(data['total'] / data['count'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...(data['sales'] as List<Sale>).map((sale) {
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.shopping_cart, size: 20),
                        title: Text(sale.customerName),
                        subtitle: Text(
                          '${sale.category} • ${DateFormat('dd MMM yyyy').format(sale.date)}',
                        ),
                        trailing: Text(
                          '₹${formatNumber(sale.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
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
        );
      },
    );
  }

  Widget _buildCategoryWiseTab(Map<String, List<Sale>> categoryGroups) {
    List<Map<String, dynamic>> categoryData = [];
    categoryGroups.forEach((category, sales) {
      double total = sales.fold(0.0, (sum, sale) => sum + sale.amount);
      categoryData.add({
        'category': category,
        'total': total,
        'count': sales.length,
        'sales': sales,
      });
    });

    categoryData.sort((a, b) => b['total'].compareTo(a['total']));

    return ListView.builder(
      itemCount: categoryData.length,
      itemBuilder: (context, index) {
        var data = categoryData[index];
        Color categoryColor = _getCategoryColor(data['category']);

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  _getCategoryIcon(data['category']),
                  color: categoryColor,
                  size: 20,
                ),
              ),
            ),
            title: Text(
              data['category'],
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${data['count']} sales'),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${formatNumber(data['total'])}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
                Text(
                  'Avg: ₹${formatNumber(data['total'] / data['count'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...(data['sales'] as List<Sale>).map((sale) {
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.person, size: 20),
                        title: Text(sale.customerName),
                        subtitle: Text(
                          '${sale.shopName} • ${DateFormat('dd MMM yyyy').format(sale.date)}',
                        ),
                        trailing: Text(
                          '₹${formatNumber(sale.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
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
        );
      },
    );
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

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'New Phone':
        return Icons.phone_android;
      case 'Base Model':
        return Icons.phone_iphone;
      case 'Second Phone':
        return Icons.phone_iphone_outlined;
      case 'Service':
        return Icons.build;
      default:
        return Icons.category;
    }
  }
}
