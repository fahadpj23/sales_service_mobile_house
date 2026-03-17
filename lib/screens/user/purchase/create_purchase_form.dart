import 'package:flutter/material.dart';
import 'package:sales_stock/models/purchase_item.dart';
import 'dart:async';
import 'create_purchase_scanner.dart';

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

class CreatePurchaseForm extends StatefulWidget {
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
  final void Function(int, String) updateItemQuantity;
  final void Function(int, String) updateItemRate;
  final void Function(int, String) updateItemDiscount;
  final void Function(int, int, String) updateItemSerial;

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
    required this.updateItemQuantity,
    required this.updateItemRate,
    required this.updateItemDiscount,
    required this.updateItemSerial,
  }) : super(key: key);

  @override
  State<CreatePurchaseForm> createState() => _CreatePurchaseFormState();
}

class _CreatePurchaseFormState extends State<CreatePurchaseForm> {
  final Map<String, TextEditingController> _imeiControllers = {};
  final Map<String, FocusNode> _imeiFocusNodes = {};
  final Debouncer _debouncer = Debouncer(milliseconds: 300);
  bool _isUpdating = false;

  String _getImeiKey(int itemIndex, int imeiIndex) {
    return 'imei_${itemIndex}_$imeiIndex';
  }

  void _initializeImeiController(int itemIndex, int imeiIndex, String value) {
    final key = _getImeiKey(itemIndex, imeiIndex);
    if (!_imeiControllers.containsKey(key)) {
      _imeiControllers[key] = TextEditingController(text: value);
      _imeiFocusNodes[key] = FocusNode();

      // Add listener to update parent
      _imeiControllers[key]!.addListener(() {
        if (!_isUpdating) {
          final newValue = _imeiControllers[key]!.text;
          final currentValue =
              imeiIndex < (widget.itemImeis[itemIndex]?.length ?? 0)
              ? widget.itemImeis[itemIndex]![imeiIndex]
              : '';

          if (newValue != currentValue) {
            _debouncer.run(() {
              if (mounted) {
                widget.updateItemSerial(itemIndex, imeiIndex, newValue);
              }
            });
          }
        }
      });
    } else {
      // Update controller value without triggering listener
      _isUpdating = true;
      if (_imeiControllers[key]!.text != value) {
        _imeiControllers[key]!.text = value;
      }
      _isUpdating = false;
    }
  }

  void _disposeImeiControllers() {
    for (var controller in _imeiControllers.values) {
      controller.dispose();
    }
    for (var node in _imeiFocusNodes.values) {
      node.dispose();
    }
    _imeiControllers.clear();
    _imeiFocusNodes.clear();
    _debouncer.dispose();
  }

  @override
  void dispose() {
    _disposeImeiControllers();
    super.dispose();
  }

  Widget _buildPurchaseItemCard(int index, BuildContext context) {
    final item = widget.purchaseItems[index];
    final showEditSection = widget.showEditSections[index] ?? false;
    final requiredImeiCount = item.quantity?.toInt() ?? 1;
    final currentImeiCount = widget.itemImeis[index]?.length ?? 0;
    final hasAllImeis = currentImeiCount >= requiredImeiCount;
    final itemImeisList = widget.itemImeis[index] ?? [];

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
          // Header Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.lightGreen.withOpacity(0.1),
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
                    color: widget.lightGreen,
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
                      if (item.productId != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.productName ?? 'No Product Selected',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '₹${item.rate?.toStringAsFixed(2) ?? "0.00"}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: widget.primaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => widget.showProductSelection(index),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: widget.primaryGreen.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: widget.primaryGreen.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    size: 16,
                                    color: widget.primaryGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Tap to select product *',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: widget.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (item.productId != null) ...[
                  IconButton(
                    onPressed: () => widget.toggleEditSection(index),
                    icon: Icon(
                      showEditSection ? Icons.expand_less : Icons.expand_more,
                      color: widget.primaryGreen,
                      size: 18,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  if (widget.purchaseItems.length > 1)
                    IconButton(
                      onPressed: () {
                        // Dispose controllers for this item before removal
                        for (int i = 0; i < 100; i++) {
                          final key = _getImeiKey(index, i);
                          _imeiControllers[key]?.dispose();
                          _imeiFocusNodes[key]?.dispose();
                          _imeiControllers.remove(key);
                          _imeiFocusNodes.remove(key);
                        }
                        widget.removeItem(index);
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ],
            ),
          ),

          // Content Section
          if (item.productId != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Quick Summary when collapsed
                  if (!showEditSection) ...[
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
                                  color: widget.primaryGreen,
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
                                  color: widget.primaryGreen,
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
                                  color: widget.primaryGreen,
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
                                  color: currentImeiCount == requiredImeiCount
                                      ? widget.lightGreen.withOpacity(0.1)
                                      : Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$currentImeiCount/$requiredImeiCount',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: currentImeiCount == requiredImeiCount
                                        ? widget.lightGreen
                                        : Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (currentImeiCount != requiredImeiCount)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                currentImeiCount < requiredImeiCount
                                    ? 'Need ${requiredImeiCount - currentImeiCount} more serial${requiredImeiCount - currentImeiCount > 1 ? 's' : ''}'
                                    : 'Too many serials (remove ${currentImeiCount - requiredImeiCount})',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.amber.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Edit Section
                  if (showEditSection) ...[
                    const SizedBox(height: 12),
                    // Quantity and Rate fields
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Quantity *',
                            value: item.quantity?.toString(),
                            onChanged: (value) =>
                                widget.updateItemQuantity(index, value),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInputField(
                            label: 'Rate *',
                            value: item.rate?.toStringAsFixed(2),
                            onChanged: (value) =>
                                widget.updateItemRate(index, value),
                            keyboardType: TextInputType.number,
                            prefix: '₹',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Serial Number Section with Scan Option
                    StatefulBuilder(
                      builder: (context, setState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),

                            // Individual serial number text fields with scan button
                            ...List.generate(requiredImeiCount, (imeiIndex) {
                              final currentSerial =
                                  imeiIndex < itemImeisList.length
                                  ? itemImeisList[imeiIndex]
                                  : '';

                              // Initialize or update controller
                              _initializeImeiController(
                                index,
                                imeiIndex,
                                currentSerial,
                              );
                              final controller =
                                  _imeiControllers[_getImeiKey(
                                    index,
                                    imeiIndex,
                                  )]!;
                              final focusNode =
                                  _imeiFocusNodes[_getImeiKey(
                                    index,
                                    imeiIndex,
                                  )]!;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Serial/IMEI #${imeiIndex + 1}',
                                          hintStyle: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade400,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: widget.primaryGreen,
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                        ),
                                        textInputAction:
                                            imeiIndex < requiredImeiCount - 1
                                            ? TextInputAction.next
                                            : TextInputAction.done,
                                        onFieldSubmitted: (_) {
                                          if (imeiIndex <
                                              requiredImeiCount - 1) {
                                            final nextKey = _getImeiKey(
                                              index,
                                              imeiIndex + 1,
                                            );
                                            _imeiFocusNodes[nextKey]
                                                ?.requestFocus();
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: widget.lightGreen.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        onPressed: () async {
                                          final scannedSerial =
                                              await Navigator.of(
                                                context,
                                              ).push<String>(
                                                MaterialPageRoute(
                                                  builder: (ctx) =>
                                                      CreatePurchaseScanner(
                                                        itemIndex: index,
                                                        imeiIndex: imeiIndex,
                                                        currentSerial:
                                                            controller.text,
                                                      ),
                                                ),
                                              );

                                          if (scannedSerial != null &&
                                              scannedSerial.isNotEmpty) {
                                            _isUpdating = true;
                                            controller.text = scannedSerial;
                                            _isUpdating = false;
                                            widget.updateItemSerial(
                                              index,
                                              imeiIndex,
                                              scannedSerial,
                                            );
                                          }
                                        },
                                        icon: Icon(
                                          Icons.qr_code_scanner,
                                          color: widget.primaryGreen,
                                          size: 22,
                                        ),
                                        tooltip: 'Scan IMEI/Serial',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),

                    // Item Total Summary
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Subtotal:',
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
                                      color: widget.primaryGreen,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                      color: widget.primaryGreen,
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
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
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
              color: isTotal ? widget.primaryGreen : Colors.grey.shade700,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: isTotal ? widget.primaryGreen : Colors.grey.shade800,
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
            color: widget.primaryGreen,
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
              borderSide: BorderSide(color: widget.lightGreen, width: 1.5),
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
        key: widget.formKey,
        child: Column(
          children: [
            // Date Section
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
                        '${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: widget.selectDate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.lightGreen.withOpacity(0.1),
                      foregroundColor: widget.primaryGreen,
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

            // Supplier Field
            GestureDetector(
              onTap: widget.showSupplierSelection,
              child: AbsorbPointer(
                absorbing: true,
                child: _buildFormField(
                  label: 'Supplier *',
                  controller: widget.supplierController,
                  readOnly: true,
                  suffixIcon: Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: widget.primaryGreen,
                  ),
                  validator: (value) {
                    if (widget.selectedSupplier == null) {
                      return 'Please select a supplier';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Invoice Field
            _buildFormField(
              label: 'Invoice Number *',
              controller: widget.invoiceController,
              keyboardType: TextInputType.text,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter invoice number';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Items Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Purchase Items',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.primaryGreen,
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.addNewItem,
                  style: TextButton.styleFrom(
                    foregroundColor: widget.lightGreen,
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Item', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Purchase Items List
            ...widget.purchaseItems.asMap().entries.map((entry) {
              return _buildPurchaseItemCard(entry.key, context);
            }).toList(),

            // Add Item Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.addNewItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.lightGreen,
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

            // Order Summary
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
                      color: widget.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    'Subtotal:',
                    '₹${widget.subtotal.toStringAsFixed(2)}',
                  ),
                  if (widget.totalDiscount > 0)
                    _buildSummaryRow(
                      'Total Discount:',
                      '-₹${widget.totalDiscount.toStringAsFixed(2)}',
                    ),
                  _buildSummaryRow(
                    'GST (18%):',
                    '₹${widget.gstAmount.toStringAsFixed(2)}',
                  ),
                  if (widget.roundOff != 0)
                    _buildSummaryRow(
                      'Round Off:',
                      widget.roundOff > 0
                          ? '+₹${widget.roundOff.abs().toStringAsFixed(2)}'
                          : '-₹${widget.roundOff.abs().toStringAsFixed(2)}',
                    ),
                  const Divider(height: 12),
                  _buildSummaryRow(
                    'Total Amount:',
                    '₹${widget.totalAmount.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Notes Field
            _buildFormField(
              label: 'Notes',
              controller: widget.notesController,
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.togglePreview,
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
                    onPressed: widget.savePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.lightGreen,
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
