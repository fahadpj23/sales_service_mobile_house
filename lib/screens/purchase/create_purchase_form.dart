import 'package:flutter/material.dart';
import 'package:sales_stock/models/purchase_item.dart';
import 'dart:math' as math;

class CreatePurchaseForm extends StatelessWidget {
  final Color primaryGreen;
  final Color lightGreen;
  final GlobalKey<FormState> formKey;
  final DateTime selectedDate;
  final Future<void> Function() selectDate;
  final List<Map<String, dynamic>> suppliers;
  final Map<String, dynamic>? selectedSupplier;
  final TextEditingController supplierController;
  final void Function() showSupplierSelection;
  final TextEditingController invoiceController;
  final TextEditingController notesController;
  final List<PurchaseItem> purchaseItems;
  final Map<int, List<String>> itemImeis;
  final Map<int, bool> showEditSections;
  final double subtotal;
  final double totalDiscount;
  final double gstAmount;
  final double roundOff;
  final double totalAmount;
  final void Function() addNewItem;
  final void Function(int) toggleEditSection;
  final void Function(int) removeItem;
  final Future<void> Function(int) showProductSelection;
  final Future<void> Function(int, {int? imeiIndex}) showScannerDialog;
  final Future<void> Function(int, {int? imeiIndex}) showManualSerialEntry;
  final void Function(String) onSerialScanned;
  final bool Function(String) isValidSerialNumber;
  final void Function() togglePreview;
  final void Function() savePurchase;

  const CreatePurchaseForm({
    Key? key,
    required this.primaryGreen,
    required this.lightGreen,
    required this.formKey,
    required this.selectedDate,
    required this.selectDate,
    required this.suppliers,
    required this.selectedSupplier,
    required this.supplierController,
    required this.showSupplierSelection,
    required this.invoiceController,
    required this.notesController,
    required this.purchaseItems,
    required this.itemImeis,
    required this.showEditSections,
    required this.subtotal,
    required this.totalDiscount,
    required this.gstAmount,
    required this.roundOff,
    required this.totalAmount,
    required this.addNewItem,
    required this.toggleEditSection,
    required this.removeItem,
    required this.showProductSelection,
    required this.showScannerDialog,
    required this.showManualSerialEntry,
    required this.onSerialScanned,
    required this.isValidSerialNumber,
    required this.togglePreview,
    required this.savePurchase,
  }) : super(key: key);

  Widget _buildPurchaseItemCard(int index) {
    final item = purchaseItems[index];
    final showEditSection = showEditSections[index] ?? false;
    final requiredImeiCount = item.quantity?.toInt() ?? 1;
    final currentImeiCount = itemImeis[index]?.length ?? 0;
    final hasAllImeis = currentImeiCount >= requiredImeiCount;
    final itemImeisList = itemImeis[index] ?? [];

    double itemTotal = 0.0;
    double itemDiscount = 0.0;
    double itemGst = 0.0;
    if (item.quantity != null && item.rate != null) {
      itemTotal = item.quantity! * item.rate!;
      if (item.discountPercentage != null && item.discountPercentage! > 0) {
        itemDiscount = itemTotal * (item.discountPercentage! / 100);
        itemTotal -= itemDiscount;
      }
      itemGst = itemTotal * 0.18;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lightGreen.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName ?? 'No Product Selected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.productName != null
                              ? Colors.grey.shade800
                              : Colors.grey.shade400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.brand != null)
                        Text(
                          item.brand!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (item.productId != null)
                  IconButton(
                    onPressed: () => toggleEditSection(index),
                    icon: Icon(
                      showEditSection ? Icons.expand_less : Icons.expand_more,
                      color: primaryGreen,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (purchaseItems.length > 1)
                  IconButton(
                    onPressed: () => removeItem(index),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => showProductSelection(index),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: item.productId != null
                            ? lightGreen
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone_android,
                          color: item.productId != null
                              ? lightGreen
                              : Colors.grey.shade400,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName ?? 'Tap to select product *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: item.productId != null
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                if (item.productId != null && !showEditSection) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Quantity:',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              '${item.quantity ?? 0}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Rate:',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              '₹${item.rate?.toStringAsFixed(2) ?? "0.00"}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (item.discountPercentage != null &&
                            item.discountPercentage! > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Discount:',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                '${item.discountPercentage!.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 6),
                        Divider(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Item Total:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              '₹${itemTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Serials:',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
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
                                '$currentImeiCount/$requiredImeiCount',
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
                      ],
                    ),
                  ),
                ],
                if (showEditSection && item.productId != null) ...[
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 3.9,
                    children: [
                      _buildInputField(
                        label: 'Quantity *',
                        value: item.quantity?.toString(),
                        onChanged: (value) {},
                        keyboardType: TextInputType.number,
                      ),
                      _buildInputField(
                        label: 'Rate *',
                        value: item.rate?.toStringAsFixed(2),
                        onChanged: (value) {},
                        keyboardType: TextInputType.number,
                        prefix: '₹',
                      ),
                      _buildInputField(
                        label: 'Discount %',
                        value: item.discountPercentage?.toStringAsFixed(1),
                        onChanged: (value) {},
                        keyboardType: TextInputType.number,
                        suffix: '%',
                      ),
                      _buildInputField(
                        label: 'HSN Code',
                        value: item.hsnCode,
                        onChanged: (value) {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.pink.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.pink.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.smartphone,
                              color: Colors.pink,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Serial/IMEI Numbers *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.pink,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: hasAllImeis ? lightGreen : Colors.amber,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$currentImeiCount/$requiredImeiCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Required: $requiredImeiCount Serial${requiredImeiCount > 1 ? 's' : ''} (1 per unit)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (itemImeisList.isNotEmpty)
                          ...List.generate(itemImeisList.length, (imeiIndex) {
                            final imei = itemImeisList[imeiIndex];
                            final isValid =
                                imei.isNotEmpty && isValidSerialNumber(imei);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: isValid
                                          ? lightGreen.withOpacity(0.1)
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${imeiIndex + 1}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: isValid
                                              ? lightGreen
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => showManualSerialEntry(
                                        index,
                                        imeiIndex: imeiIndex,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isValid
                                              ? lightGreen.withOpacity(0.05)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: isValid
                                                ? lightGreen
                                                : Colors.grey.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                imei.isEmpty
                                                    ? 'Tap to enter Serial'
                                                    : imei,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: imei.isEmpty
                                                      ? Colors.grey.shade500
                                                      : Colors.grey.shade800,
                                                  fontWeight: isValid
                                                      ? FontWeight.w500
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              isValid
                                                  ? Icons.check_circle
                                                  : Icons.edit,
                                              size: 14,
                                              color: isValid
                                                  ? lightGreen
                                                  : primaryGreen,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    onPressed: () => showScannerDialog(
                                      index,
                                      imeiIndex: imeiIndex,
                                    ),
                                    icon: Icon(
                                      Icons.qr_code_scanner,
                                      size: 16,
                                      color: primaryGreen,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          }),
                        if (currentImeiCount < requiredImeiCount)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => showScannerDialog(index),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.pink.withOpacity(0.1),
                                  foregroundColor: Colors.pink,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                ),
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text(
                                  'Add Serial/IMEI',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            hasAllImeis &&
                                    itemImeisList.every(
                                      (imei) => isValidSerialNumber(imei),
                                    )
                                ? '✅ All Serial Numbers are valid'
                                : '⚠️ ${requiredImeiCount - currentImeiCount} Serial${requiredImeiCount - currentImeiCount > 1 ? 's' : ''} remaining',
                            style: TextStyle(
                              fontSize: 9,
                              color: hasAllImeis ? lightGreen : Colors.amber,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.rate != null && item.quantity != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.indigo.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Item Total:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  '₹${(item.quantity! * item.rate!).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (item.discountPercentage != null &&
                                item.discountPercentage! > 0)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Discount:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    '-₹${((item.quantity! * item.rate!) * (item.discountPercentage! / 100)).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'GST (18%):',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  '₹${itemGst.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Divider(height: 1, color: Colors.grey.shade300),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total with GST:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                Text(
                                  '₹${(itemTotal + itemGst).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    String? value,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade700)),
        const SizedBox(height: 2),
        TextFormField(
          initialValue: value,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 11),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(fontSize: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            prefixText: prefix,
            suffixText: suffix,
            prefixStyle: const TextStyle(fontSize: 11),
            suffixStyle: const TextStyle(fontSize: 11),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isTotal ? primaryGreen : Colors.grey.shade700,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: isTotal ? primaryGreen : Colors.grey.shade800,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: primaryGreen,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: lightGreen, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            suffixIcon: suffixIcon,
          ),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Purchase Date',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: selectDate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightGreen.withOpacity(0.1),
                      foregroundColor: primaryGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: const Text('Change', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: showSupplierSelection,
              child: AbsorbPointer(
                absorbing: true,
                child: _buildFormField(
                  label: 'Supplier *',
                  controller: supplierController,
                  readOnly: true,
                  suffixIcon: Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: primaryGreen,
                  ),
                  validator: (value) {
                    if (selectedSupplier == null) {
                      return 'Please select a supplier';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildFormField(
              label: 'Invoice Number *',
              controller: invoiceController,
              keyboardType: TextInputType.text,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter invoice number';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Purchase Items',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryGreen,
                  ),
                ),
                TextButton.icon(
                  onPressed: addNewItem,
                  style: TextButton.styleFrom(foregroundColor: lightGreen),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Item', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...purchaseItems.asMap().entries.map((entry) {
              return _buildPurchaseItemCard(entry.key);
            }),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: addNewItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Add New Item',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    'Subtotal:',
                    '₹${subtotal.toStringAsFixed(2)}',
                  ),
                  if (totalDiscount > 0)
                    _buildSummaryRow(
                      'Total Discount:',
                      '-₹${totalDiscount.toStringAsFixed(2)}',
                    ),
                  _buildSummaryRow(
                    'GST (18%):',
                    '₹${gstAmount.toStringAsFixed(2)}',
                  ),
                  if (roundOff != 0)
                    _buildSummaryRow(
                      'Round Off:',
                      roundOff > 0
                          ? '+₹${roundOff.abs().toStringAsFixed(2)}'
                          : '-₹${roundOff.abs().toStringAsFixed(2)}',
                    ),
                  const Divider(height: 12),
                  _buildSummaryRow(
                    'Total Amount:',
                    '₹${totalAmount.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildFormField(
              label: 'Notes',
              controller: notesController,
              maxLines: 2,
            ),
            const SizedBox(height: 20),
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
                      'Preview',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: savePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save Purchase',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
