// lib/screens/admin/reports/appliance_verification_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ApplianceVerificationTab extends StatelessWidget {
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

  const ApplianceVerificationTab({
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
      title: 'Appliances',
      filteredData: filteredData,
      allData: allData,
      selectedShop: selectedShop,
      availableShops: availableShops,
      onShopChanged: onShopChanged,
      buildItem: (sale) => _buildApplianceSaleCard(sale, context),
      emptyMessage: 'No appliance sales found',
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.kitchen, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        emptyMessage,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
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
                        border: Border.all(color: Colors.grey.shade300),
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
                Row(
                  children: [
                    Icon(Icons.kitchen, size: 18, color: Colors.green[900]),
                    const SizedBox(width: 8),
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[900],
                      ),
                    ),
                  ],
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
                _buildSummaryItem(
                  'Total',
                  total.toString(),
                  Icons.list,
                  Colors.blue,
                ),
                _buildSummaryItem(
                  'Verified',
                  verified.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildSummaryItem(
                  'Pending',
                  pending.toString(),
                  Icons.pending,
                  Colors.orange,
                ),
                _buildSummaryItem(
                  '%',
                  '${verifiedPercentage.toStringAsFixed(0)}%',
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

  Widget _buildSummaryItem(
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

  Widget _buildApplianceSaleCard(
    Map<String, dynamic> sale,
    BuildContext context,
  ) {
    bool paymentVerified = sale['paymentVerified'] ?? false;

    // Get payment breakdown
    final paymentBreakdown =
        sale['paymentBreakdownVerified'] ??
        {'cash': false, 'card': false, 'gpay': false};

    bool cashVerified = convertToBool(paymentBreakdown['cash']);
    bool cardVerified = convertToBool(paymentBreakdown['card']);
    bool gpayVerified = convertToBool(paymentBreakdown['gpay']);

    // ===== EXTRACT DATA FROM SALE =====

    // Customer Name
    String customerName = sale['customerName'] ?? 'Walk-in Customer';

    // Customer Mobile
    String customerMobile = sale['customerMobile'] ?? '';

    // Shop Name
    String shopName = getShopName(sale);

    // Bill Number
    String billNumber = sale['billNumber'] ?? sale['invoiceNumber'] ?? '';

    // Bill Date
    dynamic billDate = sale['billDate'] ?? sale['createdAt'] ?? sale['date'];

    // Purchase Mode
    String purchaseMode = sale['purchaseMode'] ?? sale['paymentMode'] ?? '';

    // GST Details
    double gstRate = (sale['gstRate'] ?? 0).toDouble();
    double gstAmount = (sale['gstAmount'] ?? 0).toDouble();
    double taxableAmount = (sale['taxableAmount'] ?? 0).toDouble();

    // Total Amount
    double totalAmount = getTotalAmount(sale);

    // ===== EXTRACT PRODUCT DATA =====
    String applianceBrand = '';
    String applianceModelId = '';
    String applianceProductName = '';
    String serialNumber = '';
    double price = 0;
    int quantity = 1;
    double discount = 0;

    // Check if product is a map (nested)
    if (sale['product'] is Map) {
      Map<String, dynamic> product = sale['product'];
      applianceBrand = product['brand'] ?? product['brandName'] ?? '';
      applianceModelId = product['modelId'] ?? product['model'] ?? '';
      applianceProductName = product['productName'] ?? product['name'] ?? '';
      price = (product['price'] as num?)?.toDouble() ?? 0;
      quantity = (product['quantity'] as num?)?.toInt() ?? 1;
      discount = (product['discount'] as num?)?.toDouble() ?? 0;
      serialNumber = product['serialNumber'] ?? sale['serialNumber'] ?? '';
    } else {
      // Direct fields
      applianceBrand = sale['applianceBrand'] ?? sale['brand'] ?? '';
      applianceModelId = sale['applianceModelId'] ?? sale['modelId'] ?? '';
      applianceProductName =
          sale['applianceProductName'] ??
          sale['productName'] ??
          sale['name'] ??
          '';
      serialNumber = sale['serialNumber'] ?? sale['serial'] ?? '';
      price = (sale['price'] as num?)?.toDouble() ?? 0;
      quantity = (sale['quantity'] as num?)?.toInt() ?? 1;
      discount = (sale['discount'] as num?)?.toDouble() ?? 0;
    }

    // Build display description
    String description = applianceProductName;
    if (applianceBrand.isNotEmpty && applianceBrand != applianceProductName) {
      description = '$applianceBrand - $description';
    }
    if (applianceModelId.isNotEmpty &&
        applianceModelId != applianceProductName) {
      description = '$description (ID: $applianceModelId)';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row - Customer Name & View Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (customerMobile.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: 10,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      customerMobile,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description.isNotEmpty ? description : 'Appliance Sale',
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
                // View button only - NO TOGGLE
                IconButton(
                  icon: Icon(
                    Icons.remove_red_eye,
                    color: paymentVerified ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  onPressed: () => onVerifyPayment(createTransaction(sale)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade300, height: 1),
            const SizedBox(height: 8),

            // Row 1: Bill Number & Shop
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill No.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        billNumber.isNotEmpty ? billNumber : 'N/A',
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Amount & Quantity
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
                        '₹${formatNumber(totalAmount)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
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
                        'Qty / Price',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$quantity × ₹${formatNumber(price)}',
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
            const SizedBox(height: 8),

            // Row 3: Payment Status & Date
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
                      _buildVerificationChip(paymentVerified),
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
                        formatDate(billDate),
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

            // GST Details
            if (gstRate > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GST ${gstRate.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${formatNumber(gstAmount)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.purple,
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
                          'Taxable Amount',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${formatNumber(taxableAmount)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

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

            // Appliance Specific Details
            const SizedBox(height: 8),

            // Tags Row
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (applianceBrand.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      'Brand: $applianceBrand',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (applianceModelId.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'Model ID: $applianceModelId',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (purchaseMode.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      purchaseMode,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (discount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'Discount: ₹${formatNumber(discount)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (serialNumber.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'S/N: $serialNumber',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: serialNumber),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Serial number copied'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.copy,
                            size: 12,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Created By
            if (sale['createdByName'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Added by: ${sale['createdByName']}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationChip(bool verified) {
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
}
