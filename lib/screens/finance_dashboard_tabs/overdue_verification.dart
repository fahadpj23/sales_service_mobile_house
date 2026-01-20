import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OverdueVerificationTab extends StatelessWidget {
  final List<Map<String, dynamic>> filteredData;
  final List<Map<String, dynamic>> allData;
  final String? selectedShop;
  final List<String> availableShops;
  final Function(String?) onShopChanged;
  final Function(Map<String, dynamic>) onVerifyPayment;
  final String Function(Map<String, dynamic>) getShopName;
  final double Function(Map<String, dynamic>) getTotalAmount;
  final String Function(double) formatNumber;
  final String Function(dynamic) formatDate;
  final DateTime? Function(dynamic) parseDate;
  final Map<String, dynamic> Function(Map<String, dynamic>) createTransaction;

  const OverdueVerificationTab({
    Key? key,
    required this.filteredData,
    required this.allData,
    required this.selectedShop,
    required this.availableShops,
    required this.onShopChanged,
    required this.onVerifyPayment,
    required this.getShopName,
    required this.getTotalAmount,
    required this.formatNumber,
    required this.formatDate,
    required this.parseDate,
    required this.createTransaction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildMobileListView(
      title: 'Overdue Payments (>7 days)',
      filteredData: filteredData,
      allData: allData,
      selectedShop: selectedShop,
      availableShops: availableShops,
      onShopChanged: onShopChanged,
      buildItem: (sale) => _buildOverdueSaleCard(sale, context),
      emptyMessage: 'No overdue payments found',
    );
  }

  Widget _buildMobileListView({
    required String title,
    required List<Map<String, dynamic>> filteredData,
    required List<Map<String, dynamic>> allData,
    required String? selectedShop,
    required List<String> availableShops,
    required Function(String?) onShopChanged,
    required Widget Function(Map<String, dynamic>) buildItem,
    required String emptyMessage,
  }) {
    return Column(
      children: [
        _buildVerificationSummary(title, filteredData, allData),
        const SizedBox(height: 8),
        _buildShopFilter(selectedShop, availableShops, onShopChanged),
        const SizedBox(height: 8),
        Expanded(
          child: filteredData.isEmpty
              ? Center(
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12.0),
                  itemCount: filteredData.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: buildItem(filteredData[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildShopFilter(
    String? selectedShop,
    List<String> availableShops,
    Function(String?) onShopChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter by Shop',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[900],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedShop ?? 'All Shops',
                            icon: const Icon(Icons.arrow_drop_down),
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            onChanged: (String? newValue) {
                              onShopChanged(
                                newValue == 'All Shops' ? null : newValue,
                              );
                            },
                            items: availableShops.map<DropdownMenuItem<String>>(
                              (String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              },
                            ).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (selectedShop != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        onShopChanged(null);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationSummary(
    String title,
    List<Map<String, dynamic>> filteredData,
    List<Map<String, dynamic>> allData,
  ) {
    int total = filteredData.length;
    int verified = filteredData
        .where((sale) => sale['paymentVerified'] == true)
        .length;
    int pending = total - verified;
    double verifiedPercentage = total > 0 ? (verified / total * 100) : 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[900],
                  ),
                ),
                if (selectedShop != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.store, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          selectedShop!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMobileSummaryItem(
                  'Total',
                  total.toString(),
                  Icons.list,
                  Colors.green,
                ),
                _buildMobileSummaryItem(
                  'Verified',
                  verified.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildMobileSummaryItem(
                  'Pending',
                  pending.toString(),
                  Icons.pending,
                  Colors.orange,
                ),
                _buildMobileSummaryItem(
                  '%',
                  '${verifiedPercentage.toStringAsFixed(0)}',
                  Icons.percent,
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildOverdueSaleCard(
    Map<String, dynamic> sale,
    BuildContext context,
  ) {
    String saleType = '';
    String collection = '';

    if (sale.containsKey('purchaseMode')) {
      saleType = 'Phone Sale';
      collection = 'phoneSales';
    } else if (sale.containsKey('productName') &&
        !sale.containsKey('modelName')) {
      saleType = '2nd Hand Phone';
      collection = 'seconds_phone_sale';
    } else if (sale.containsKey('modelName')) {
      saleType = 'Base Model';
      collection = 'base_model_sale';
    } else if (sale.containsKey('totalSaleAmount')) {
      saleType = 'Accessory/Service';
      collection = 'accessories_service_sales';
    }

    DateTime? saleDate;
    if (sale.containsKey('saleDate')) {
      saleDate = parseDate(sale['saleDate']);
    } else if (sale.containsKey('date')) {
      saleDate = parseDate(sale['date']);
    } else if (sale.containsKey('timestamp')) {
      saleDate = parseDate(sale['timestamp']);
    }

    int daysOverdue = 0;
    if (saleDate != null) {
      final now = DateTime.now();
      daysOverdue = now.difference(saleDate).inDays;
    }

    double amount = getTotalAmount(sale);
    String shopName = getShopName(sale);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.withOpacity(0.5), width: 2),
      ),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red[700], size: 18),
                          const SizedBox(width: 8),
                          Text(
                            saleType,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sale['customerName'] ?? 'Walk-in Customer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (sale['customerPhone'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sale['customerPhone'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_red_eye,
                    color: Colors.red[700],
                    size: 20,
                  ),
                  onPressed: () => onVerifyPayment(createTransaction(sale)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.red.shade300, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shop',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Days Overdue',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red, width: 1),
                        ),
                        child: Text(
                          '$daysOverdue days',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${formatNumber(amount)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatDate(saleDate),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (sale.containsKey('purchaseMode')) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Mode',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green, width: 1),
                          ),
                          child: Text(
                            sale['purchaseMode'] ?? 'Cash',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => onVerifyPayment(createTransaction(sale)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 36),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user, size: 16),
                  SizedBox(width: 8),
                  Text('Verify Payment Now'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
