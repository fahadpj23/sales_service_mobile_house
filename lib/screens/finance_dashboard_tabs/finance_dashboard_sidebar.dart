import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import

class FinanceDashboardSidebar extends StatelessWidget {
  final int selectedIndex;
  final List<Map<String, dynamic>> phoneSales;
  final List<Map<String, dynamic>> secondsPhoneSales;
  final List<Map<String, dynamic>> baseModelSales;
  final List<Map<String, dynamic>> accessoriesServiceSales;
  final String? selectedShop;
  final String Function(Map<String, dynamic>) getShopName;
  final Function(int) onIndexChanged;

  const FinanceDashboardSidebar({
    Key? key,
    required this.selectedIndex,
    required this.phoneSales,
    required this.secondsPhoneSales,
    required this.baseModelSales,
    required this.accessoriesServiceSales,
    required this.selectedShop,
    required this.getShopName,
    required this.onIndexChanged,
  }) : super(key: key);

  List<Map<String, dynamic>> _filterByShop(List<Map<String, dynamic>> sales) {
    if (selectedShop == null || selectedShop == 'All Shops') {
      return sales;
    }
    return sales.where((sale) => getShopName(sale) == selectedShop).toList();
  }

  List<Map<String, dynamic>> _getOverdueSales() {
    List<Map<String, dynamic>> allSales = [];
    allSales.addAll(phoneSales);
    allSales.addAll(secondsPhoneSales);
    allSales.addAll(baseModelSales);
    allSales.addAll(accessoriesServiceSales);

    final now = DateTime.now();
    return allSales.where((sale) {
      if (sale['paymentVerified'] == true) return false;

      dynamic saleDate;
      if (sale.containsKey('saleDate')) {
        saleDate = sale['saleDate'];
      } else if (sale.containsKey('date')) {
        saleDate = sale['date'];
      } else if (sale.containsKey('timestamp')) {
        saleDate = sale['timestamp'];
      }

      if (saleDate == null) return false;

      DateTime? parsedDate;
      if (saleDate is DateTime) {
        parsedDate = saleDate;
      } else if (saleDate is Timestamp) {
        // Now Timestamp is recognized
        parsedDate = saleDate.toDate();
      }

      if (parsedDate == null) return false;
      final difference = now.difference(parsedDate);
      return difference.inDays > 7;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final overdueSales = _getOverdueSales();

    return Container(
      color: Colors.green[900],
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Payment Verification',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSidebarItem(
                    icon: Icons.phone_iphone,
                    label: 'Phones',
                    index: 0,
                    count: _filterByShop(phoneSales).length,
                    totalCount: phoneSales.length,
                    verifiedCount: phoneSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                  ),
                  _buildSidebarItem(
                    icon: Icons.phone_android,
                    label: '2nd Hand',
                    index: 1,
                    count: _filterByShop(secondsPhoneSales).length,
                    totalCount: secondsPhoneSales.length,
                    verifiedCount: secondsPhoneSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                  ),
                  _buildSidebarItem(
                    icon: Icons.phone,
                    label: 'Base Models',
                    index: 2,
                    count: _filterByShop(baseModelSales).length,
                    totalCount: baseModelSales.length,
                    verifiedCount: baseModelSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                  ),
                  _buildSidebarItem(
                    icon: Icons.shopping_cart,
                    label: 'Accessories',
                    index: 3,
                    count: _filterByShop(accessoriesServiceSales).length,
                    totalCount: accessoriesServiceSales.length,
                    verifiedCount: accessoriesServiceSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                  ),
                  _buildSidebarItem(
                    icon: Icons.warning,
                    label: 'Overdue',
                    index: 4,
                    count: selectedShop != null
                        ? overdueSales
                              .where(
                                (sale) => getShopName(sale) == selectedShop,
                              )
                              .length
                        : overdueSales.length,
                    totalCount: overdueSales.length,
                    verifiedCount: 0,
                    isOverdue: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required int index,
    required int count,
    required int totalCount,
    required int verifiedCount,
    bool isOverdue = false,
  }) {
    bool isSelected = selectedIndex == index;
    double verifiedPercentage = totalCount > 0
        ? (verifiedCount / totalCount * 100)
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? (isOverdue
                  ? Colors.red.withOpacity(0.3)
                  : Colors.white.withOpacity(0.2))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: isOverdue ? Colors.red[300] : Colors.white),
        title: Text(
          label,
          style: TextStyle(
            color: isOverdue ? Colors.red[300] : Colors.white,
            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isOverdue
                ? Colors.red.withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOverdue ? Colors.red : Colors.white,
              width: 1,
            ),
          ),
          child: Text(
            selectedShop != null && !isOverdue
                ? '$count'
                : '$verifiedCount/$totalCount',
            style: TextStyle(
              color: isOverdue ? Colors.red[300] : Colors.white,
              fontSize: 12,
              fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        onTap: () => onIndexChanged(index),
        subtitle: !isOverdue && totalCount > 0
            ? Text(
                '${verifiedPercentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
              )
            : null,
      ),
    );
  }
}
