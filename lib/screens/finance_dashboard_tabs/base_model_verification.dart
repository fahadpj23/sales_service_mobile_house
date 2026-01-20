import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BaseModelVerificationTab extends StatelessWidget {
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
  final bool Function(dynamic) convertToBool;
  final Map<String, dynamic> Function(Map<String, dynamic>) createTransaction;

  const BaseModelVerificationTab({
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
    required this.convertToBool,
    required this.createTransaction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildMobileListView(
      title: 'Base Models',
      filteredData: filteredData,
      allData: allData,
      selectedShop: selectedShop,
      availableShops: availableShops,
      onShopChanged: onShopChanged,
      buildItem: (sale) => _buildGenericSaleCard(sale, context),
      emptyMessage: 'No base model sales found',
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

  Widget _buildGenericSaleCard(
    Map<String, dynamic> sale,
    BuildContext context,
  ) {
    bool paymentVerified = sale['paymentVerified'] ?? false;

    final paymentBreakdown =
        sale['paymentBreakdownVerified'] ??
        {'cash': false, 'card': false, 'gpay': false};

    bool cashVerified = convertToBool(paymentBreakdown['cash']);
    bool cardVerified = convertToBool(paymentBreakdown['card']);
    bool gpayVerified = convertToBool(paymentBreakdown['gpay']);

    String shopName = getShopName(sale);
    double amount = getTotalAmount(sale);

    Map<String, dynamic> displayData = _getBaseModelDisplayData(sale);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      Text(
                        displayData['customer']?.isNotEmpty == true
                            ? displayData['customer']
                            : 'Walk-in Customer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayData['description'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_red_eye,
                    color: Colors.green[800],
                    size: 20,
                  ),
                  onPressed: () => onVerifyPayment(createTransaction(sale)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade300, height: 1),
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
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
                        'Payment',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _buildMobileVerificationChip(paymentVerified),
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
                        formatDate(displayData['date']),
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
            const SizedBox(height: 12),
            Text(
              'Payment Methods',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green[900],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPaymentMethodIndicator('Cash', cashVerified),
                _buildPaymentMethodIndicator('Card', cardVerified),
                _buildPaymentMethodIndicator('UPI', gpayVerified),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileVerificationChip(bool verified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: verified
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: verified ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.check_circle : Icons.pending,
            size: 12,
            color: verified ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Verified' : 'Pending',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: verified ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodIndicator(String method, bool verified) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: verified
                ? Colors.green.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: verified ? Colors.green : Colors.grey,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Icon(
              verified ? Icons.check : Icons.close,
              size: 16,
              color: verified ? Colors.green : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          method,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: verified ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getBaseModelDisplayData(Map<String, dynamic> sale) {
    return {
      'customer': sale['customerName'] ?? '',
      'description': sale['modelName'] ?? '',
      'amount': (sale['price'] as num?)?.toDouble() ?? 0,
      'date': sale['date'] ?? sale['timestamp'],
    };
  }
}
