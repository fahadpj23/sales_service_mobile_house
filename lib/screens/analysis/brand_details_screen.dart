import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';

class BrandDetailsScreen extends StatelessWidget {
  final String brand;
  final List<Sale> sales;
  final String Function(double) formatNumber;

  BrandDetailsScreen({
    required this.brand,
    required this.sales,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    double totalSales = sales.fold(0.0, (sum, sale) => sum + sale.amount);

    Map<String, List<Sale>> categoryGroups = {};
    for (var sale in sales) {
      if (!categoryGroups.containsKey(sale.category)) {
        categoryGroups[sale.category] = [];
      }
      categoryGroups[sale.category]!.add(sale);
    }

    Map<String, List<Sale>> shopGroups = {};
    for (var sale in sales) {
      if (!shopGroups.containsKey(sale.shopName)) {
        shopGroups[sale.shopName] = [];
      }
      shopGroups[sale.shopName]!.add(sale);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$brand Details',
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
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A4D2E), Color(0xFF1A7D4A)],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        brand.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    brand,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBrandStat(
                        'Total Sales',
                        '₹${formatNumber(totalSales)}',
                      ),
                      SizedBox(width: 20),
                      _buildBrandStat('Transactions', '${sales.length}'),
                      SizedBox(width: 20),
                      _buildBrandStat(
                        'Avg Sale',
                        '₹${formatNumber(sales.isNotEmpty ? totalSales / sales.length : 0)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              color: Color(0xFF0A4D2E),
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Categories'),
                  Tab(text: 'Shops'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                children: [
                  _buildOverviewTab(sales),
                  _buildCategoriesTab(categoryGroups),
                  _buildShopsTab(shopGroups),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(List<Sale> sales) {
    Map<String, List<Sale>> monthGroups = {};
    for (var sale in sales) {
      String month = DateFormat('MMM yyyy').format(sale.date);
      if (!monthGroups.containsKey(month)) {
        monthGroups[month] = [];
      }
      monthGroups[month]!.add(sale);
    }

    List<Map<String, dynamic>> monthData = [];
    monthGroups.forEach((month, sales) {
      double total = sales.fold(0.0, (sum, sale) => sum + sale.amount);
      monthData.add({'month': month, 'total': total, 'count': sales.length});
    });

    monthData.sort((a, b) {
      DateTime dateA = DateFormat('MMM yyyy').parse(a['month']);
      DateTime dateB = DateFormat('MMM yyyy').parse(b['month']);
      return dateB.compareTo(dateA);
    });

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Card(
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
                  'Monthly Performance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
                SizedBox(height: 12),
                ...monthData.take(6).map((data) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['month'],
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Column(
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
                              '${data['count']} sales',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
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
        ),
        SizedBox(height: 16),
        Card(
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
                  'Recent Sales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
                SizedBox(height: 12),
                ...sales.take(5).map((sale) {
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
        ),
      ],
    );
  }

  Widget _buildCategoriesTab(Map<String, List<Sale>> categoryGroups) {
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

  Widget _buildShopsTab(Map<String, List<Sale>> shopGroups) {
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
