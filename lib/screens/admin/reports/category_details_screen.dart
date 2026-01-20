import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';

class CategoryDetailsScreen extends StatelessWidget {
  final String category;
  final List<Sale> sales;
  final String Function(double) formatNumber;
  final Color Function(String) getCategoryColor;

  CategoryDetailsScreen({
    required this.category,
    required this.sales,
    required this.formatNumber,
    required this.getCategoryColor,
  });

  @override
  Widget build(BuildContext context) {
    List<Sale> categorySales = sales
        .where((sale) => sale.category == category)
        .toList();

    Map<String, List<Sale>> shopWiseSales = {};
    for (var sale in categorySales) {
      if (!shopWiseSales.containsKey(sale.shopName)) {
        shopWiseSales[sale.shopName] = [];
      }
      shopWiseSales[sale.shopName]!.add(sale);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$category Details',
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
                            '₹${formatNumber(categorySales.fold(0.0, (sum, sale) => sum + sale.amount))}',
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
                            'Total Sales Count',
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              shopName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                                '${shopSales.length} sales',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1A7D4A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                                  'Total: ₹${formatNumber(shopTotal)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0A4D2E),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Avg: ₹${formatNumber(shopTotal / shopSales.length)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
