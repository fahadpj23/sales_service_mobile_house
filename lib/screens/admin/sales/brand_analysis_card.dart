// lib/screens/sales/brand_analysis_card.dart
import 'package:flutter/material.dart';
import '../../models/sale.dart';
import '../analysis/brand_details_screen.dart'; // Added this import

class BrandAnalysisCard extends StatefulWidget {
  final List<Sale> allSales;
  final String Function(double) formatNumber;
  final VoidCallback onViewDetails;

  BrandAnalysisCard({
    required this.allSales,
    required this.formatNumber,
    required this.onViewDetails,
  });

  @override
  _BrandAnalysisCardState createState() => _BrandAnalysisCardState();
}

class _BrandAnalysisCardState extends State<BrandAnalysisCard> {
  String _selectedTimePeriod = 'monthly';
  final List<String> _timePeriods = ['daily', 'monthly', 'yearly'];

  List<Sale> _getFilteredSales() {
    DateTime startDate;
    DateTime endDate;
    DateTime now = DateTime.now();

    switch (_selectedTimePeriod) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
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
      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
    }

    return widget.allSales.where((sale) {
      return sale.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
    }).toList();
  }

  Map<String, Map<String, dynamic>> _getBrandAnalysis() {
    List<Sale> filteredSales = _getFilteredSales();
    Map<String, Map<String, dynamic>> brandData = {};

    for (var sale in filteredSales) {
      String? brand = sale.brand;
      if (brand == null || brand.isEmpty) continue;

      if (!brandData.containsKey(brand)) {
        brandData[brand] = {
          'totalSales': 0.0,
          'count': 0,
          'categories': <String, double>{},
          'models': <String, int>{},
          'shops': <String, double>{},
        };
      }

      brandData[brand]!['totalSales'] += sale.amount;
      brandData[brand]!['count'] += 1;

      String category = sale.category;
      brandData[brand]!['categories'][category] =
          (brandData[brand]!['categories'][category] ?? 0.0) + sale.amount;

      String? model = sale.model;
      if (model != null && model.isNotEmpty) {
        brandData[brand]!['models'][model] =
            (brandData[brand]!['models'][model] ?? 0) + 1;
      }

      brandData[brand]!['shops'][sale.shopName] =
          (brandData[brand]!['shops'][sale.shopName] ?? 0.0) + sale.amount;
    }

    return brandData;
  }

  @override
  Widget build(BuildContext context) {
    final brandAnalysis = _getBrandAnalysis();
    final sortedBrands = brandAnalysis.entries.toList()
      ..sort((a, b) => b.value['totalSales'].compareTo(a.value['totalSales']));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.branding_watermark,
                      color: Color(0xFF0A4D2E),
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Brand Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _selectedTimePeriod = value;
                    });
                  },
                  itemBuilder: (context) => _timePeriods.map((period) {
                    return PopupMenuItem(
                      value: period,
                      child: Text(period.toUpperCase()),
                    );
                  }).toList(),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF0A4D2E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedTimePeriod.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: Color(0xFF0A4D2E),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTimePeriodLabel(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${sortedBrands.length} Brands',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: widget.onViewDetails,
                    icon: Icon(Icons.analytics, size: 16),
                    label: Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1A7D4A),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            ...sortedBrands.take(3).map((entry) {
              String brand = entry.key;
              var data = entry.value;
              double totalSales = data['totalSales'];
              int count = data['count'];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BrandDetailsScreen(
                        brand: brand,
                        sales: widget.allSales
                            .where((s) => s.brand == brand)
                            .toList(),
                        formatNumber: widget.formatNumber,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _getBrandColor(brand).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            brand.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getBrandColor(brand),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  brand,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
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
                                    '$count sales',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF1A7D4A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            Text(
                              '₹${widget.formatNumber(totalSales)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A4D2E),
                              ),
                            ),
                            SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: sortedBrands.isNotEmpty
                                  ? totalSales /
                                        sortedBrands.first.value['totalSales']
                                  : 0,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getBrandColor(brand),
                              ),
                              minHeight: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            if (sortedBrands.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.more_horiz, color: Colors.grey[400]),
                    SizedBox(width: 4),
                    Text(
                      '+${sortedBrands.length - 3} more brands',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getTimePeriodLabel() {
    switch (_selectedTimePeriod) {
      case 'daily':
        return 'Today';
      case 'monthly':
        return 'This Month';
      case 'yearly':
        return 'This Year';
      default:
        return 'This Month';
    }
  }

  Color _getBrandColor(String brand) {
    int hash = brand.hashCode;
    List<Color> brandColors = [
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
      Color(0xFF9C27B0),
      Color(0xFFFF9800),
      Color(0xFFF44336),
      Color(0xFF00BCD4),
      Color(0xFF673AB7),
      Color(0xFFFF5722),
    ];
    return brandColors[hash.abs() % brandColors.length];
  }
}
