import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceDashboardSidebar extends StatelessWidget {
  final int selectedIndex;
  final List<Map<String, dynamic>> phoneSales;
  final List<Map<String, dynamic>> secondsPhoneSales;
  final List<Map<String, dynamic>> baseModelSales;
  final List<Map<String, dynamic>> accessoriesServiceSales;
  final List<Map<String, dynamic>> tvSales;
  final List<Map<String, dynamic>> applianceSales;
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
    required this.tvSales,
    required this.applianceSales,
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

    // Add all sales with null safety
    if (phoneSales.isNotEmpty) allSales.addAll(phoneSales);
    if (secondsPhoneSales.isNotEmpty) allSales.addAll(secondsPhoneSales);
    if (baseModelSales.isNotEmpty) allSales.addAll(baseModelSales);
    if (accessoriesServiceSales.isNotEmpty)
      allSales.addAll(accessoriesServiceSales);
    if (tvSales.isNotEmpty) allSales.addAll(tvSales);
    if (applianceSales.isNotEmpty) allSales.addAll(applianceSales);

    final now = DateTime.now();
    return allSales.where((sale) {
      if (sale['paymentVerified'] == true) return false;

      dynamic saleDate;
      if (sale.containsKey('saleDate')) {
        saleDate = sale['saleDate'];
      } else if (sale.containsKey('date')) {
        saleDate = sale['date'];
      } else if (sale.containsKey('createdAt')) {
        saleDate = sale['createdAt'];
      } else if (sale.containsKey('timestamp')) {
        saleDate = sale['timestamp'];
      }

      if (saleDate == null) return false;

      DateTime? parsedDate;
      if (saleDate is DateTime) {
        parsedDate = saleDate;
      } else if (saleDate is Timestamp) {
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
                    overdueCount: 0,
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
                    overdueCount: 0,
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
                    overdueCount: 0,
                  ),
                  // _buildSidebarItem(
                  //   icon: Icons.shopping_bag,
                  //   label: 'Accessories',
                  //   index: 3,
                  //   count: _filterByShop(accessoriesServiceSales).length,
                  //   totalCount: accessoriesServiceSales.length,
                  //   verifiedCount: accessoriesServiceSales
                  //       .where((s) => s['paymentVerified'] == true)
                  //       .length,
                  //   overdueCount: 0,
                  // ),
                  _buildSidebarItem(
                    icon: Icons.tv,
                    label: 'TV',
                    index: 4,
                    count: _filterByShop(tvSales).length,
                    totalCount: tvSales.length,
                    verifiedCount: tvSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                    overdueCount: 0,
                  ),
                  _buildSidebarItem(
                    icon: Icons.kitchen,
                    label: 'Appliances',
                    index: 5,
                    count: _filterByShop(applianceSales).length,
                    totalCount: applianceSales.length,
                    verifiedCount: applianceSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                    overdueCount: 0,
                  ),
                  const Divider(
                    color: Colors.white24,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _buildSidebarItem(
                    icon: Icons.warning,
                    label: 'Overdue',
                    index: 6,
                    count: selectedShop != null
                        ? overdueSales
                              .where(
                                (sale) => getShopName(sale) == selectedShop,
                              )
                              .length
                        : overdueSales.length,
                    totalCount: overdueSales.length,
                    verifiedCount: 0,
                    overdueCount: overdueSales.length,
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
    required int overdueCount,
    bool isOverdue = false,
  }) {
    bool isSelected = selectedIndex == index;
    double verifiedPercentage = totalCount > 0
        ? (verifiedCount / totalCount * 100)
        : 0;

    // Get color for the item
    Color getIconColor() {
      if (isOverdue) return Colors.red[300]!;
      switch (index) {
        case 0:
          return Colors.blue[300]!;
        case 1:
          return Colors.purple[300]!;
        case 2:
          return Colors.teal[300]!;
        case 3:
          return Colors.orange[300]!;
        case 4:
          return Colors.cyan[300]!;
        case 5:
          return Colors.green[300]!;
        default:
          return Colors.white;
      }
    }

    // Get loading text
    String getTrailingText() {
      if (selectedShop != null && !isOverdue) {
        return '$count';
      }
      if (isOverdue) {
        return '$overdueCount';
      }
      if (totalCount == 0) {
        return '0/0';
      }
      return '$verifiedCount/$totalCount';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? (isOverdue
                  ? Colors.red.withOpacity(0.3)
                  : Colors.white.withOpacity(0.15))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(
                color: isOverdue
                    ? Colors.red.withOpacity(0.5)
                    : Colors.white.withOpacity(0.3),
                width: 1,
              )
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isOverdue ? Colors.red[300] : getIconColor(),
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isOverdue ? Colors.red[300] : Colors.white,
            fontWeight: isOverdue ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
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
            getTrailingText(),
            style: TextStyle(
              color: isOverdue ? Colors.red[300] : Colors.white,
              fontSize: 11,
              fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        onTap: () => onIndexChanged(index),
        subtitle: !isOverdue && totalCount > 0
            ? Text(
                '${verifiedPercentage.toStringAsFixed(0)}% verified',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                ),
              )
            : isOverdue && overdueCount > 0
            ? Text(
                '$overdueCount overdue',
                style: TextStyle(
                  color: Colors.red[300]!.withOpacity(0.7),
                  fontSize: 10,
                ),
              )
            : totalCount == 0 && !isOverdue
            ? Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                ),
              )
            : null,
        dense: true,
      ),
    );
  }
}
