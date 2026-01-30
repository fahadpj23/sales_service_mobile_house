import 'package:flutter/material.dart';
import 'package:sales_stock/models/purchase_item.dart';
import 'dart:math' as math;

class CreatePurchasePreview extends StatelessWidget {
  final Color primaryGreen;
  final Color lightGreen;
  final DateTime selectedDate;
  final Map<String, dynamic>? selectedSupplier;
  final TextEditingController invoiceController;
  final List<PurchaseItem> purchaseItems;
  final Map<int, List<String>> itemImeis;
  final double subtotal;
  final double totalDiscount;
  final double gstAmount;
  final double roundOff;
  final double totalAmount;
  final void Function() togglePreview;
  final Future<void> Function() confirmAndSavePurchase;
  final bool Function(String) isValidSerialNumber;

  const CreatePurchasePreview({
    Key? key,
    required this.primaryGreen,
    required this.lightGreen,
    required this.selectedDate,
    required this.selectedSupplier,
    required this.invoiceController,
    required this.purchaseItems,
    required this.itemImeis,
    required this.subtotal,
    required this.totalDiscount,
    required this.gstAmount,
    required this.roundOff,
    required this.totalAmount,
    required this.togglePreview,
    required this.confirmAndSavePurchase,
    required this.isValidSerialNumber,
  }) : super(key: key);

  Widget _buildPreviewSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: primaryGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isTotal ? primaryGreen : Colors.grey.shade700,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isTotal ? primaryGreen : Colors.grey.shade800,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validItems = purchaseItems
        .where((item) => item.productId != null)
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.remove_red_eye,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Purchase Preview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: togglePreview,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreviewSection(
                    icon: Icons.calendar_today,
                    title: 'Purchase Date',
                    content:
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                  _buildPreviewSection(
                    icon: Icons.business,
                    title: 'Supplier',
                    content: selectedSupplier?['name'] ?? 'Not selected',
                  ),
                  _buildPreviewSection(
                    icon: Icons.receipt,
                    title: 'Invoice Number',
                    content: invoiceController.text.isNotEmpty
                        ? invoiceController.text
                        : 'Not entered',
                  ),
                  const Divider(height: 20),
                  Text(
                    'Items (${validItems.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...validItems.map((item) {
                    final index = purchaseItems.indexOf(item);
                    final itemImeisList = itemImeis[index] ?? [];
                    final requiredImeiCount = item.quantity?.toInt() ?? 0;
                    final hasAllImeis =
                        itemImeisList.length == requiredImeiCount;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasAllImeis ? lightGreen : Colors.amber,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          if (item.brand != null)
                            Text(
                              item.brand!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${item.quantity} × ₹${item.rate?.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                '₹${(item.quantity! * item.rate!).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: primaryGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Serials:',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: hasAllImeis
                                      ? lightGreen.withOpacity(0.1)
                                      : Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${itemImeisList.length}/${requiredImeiCount}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: hasAllImeis
                                        ? lightGreen
                                        : Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (itemImeisList.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...itemImeisList.take(3).map((imei) {
                                    final isValid = isValidSerialNumber(imei);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isValid
                                                ? Icons.check_circle
                                                : Icons.warning,
                                            size: 10,
                                            color: isValid
                                                ? lightGreen
                                                : Colors.amber,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${imei.substring(0, math.min(imei.length, 12))}...',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  if (itemImeisList.length > 3)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '+ ${itemImeisList.length - 3} more',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  const Divider(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: lightGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _buildPreviewSummaryRow(
                          'Subtotal:',
                          '₹${subtotal.toStringAsFixed(2)}',
                        ),
                        if (totalDiscount > 0)
                          _buildPreviewSummaryRow(
                            'Discount:',
                            '-₹${totalDiscount.toStringAsFixed(2)}',
                          ),
                        _buildPreviewSummaryRow(
                          'GST (18%):',
                          '₹${gstAmount.toStringAsFixed(2)}',
                        ),
                        if (roundOff != 0)
                          _buildPreviewSummaryRow(
                            'Round Off:',
                            roundOff > 0
                                ? '+₹${roundOff.abs().toStringAsFixed(2)}'
                                : '-₹${roundOff.abs().toStringAsFixed(2)}',
                          ),
                        const Divider(height: 10),
                        _buildPreviewSummaryRow(
                          'Total Amount:',
                          '₹${totalAmount.toStringAsFixed(2)}',
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: togglePreview,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Continue Editing',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: confirmAndSavePurchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lightGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Confirm & Save',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
