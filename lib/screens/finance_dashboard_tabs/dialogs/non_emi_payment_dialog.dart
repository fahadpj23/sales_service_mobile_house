import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NonEMIPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> sale;
  final String collection;
  final String docId;
  final String Function(Map<String, dynamic>) getShopName;
  final double Function(Map<String, dynamic>) getTotalAmount;
  final double Function(dynamic, List<String>) extractAmount;
  final String Function(double) formatNumber;
  final bool Function(dynamic) convertToBool;
  final Future<void> Function(String, String, Map<String, dynamic>) onUpdate;
  final VoidCallback onSuccess;

  const NonEMIPaymentDialog({
    Key? key,
    required this.sale,
    required this.collection,
    required this.docId,
    required this.getShopName,
    required this.getTotalAmount,
    required this.extractAmount,
    required this.formatNumber,
    required this.convertToBool,
    required this.onUpdate,
    required this.onSuccess,
  }) : super(key: key);

  @override
  _NonEMIPaymentDialogState createState() => _NonEMIPaymentDialogState();
}

class _NonEMIPaymentDialogState extends State<NonEMIPaymentDialog> {
  late bool _cashVerified;
  late bool _cardVerified;
  late bool _gpayVerified;

  @override
  void initState() {
    super.initState();
    final paymentBreakdownVerified =
        widget.sale['paymentBreakdownVerified'] ??
        {'cash': false, 'card': false, 'gpay': false};

    _cashVerified = widget.convertToBool(paymentBreakdownVerified['cash']);
    _cardVerified = widget.convertToBool(paymentBreakdownVerified['card']);
    _gpayVerified = widget.convertToBool(paymentBreakdownVerified['gpay']);
  }

  @override
  Widget build(BuildContext context) {
    String purchaseMode = (widget.sale['purchaseMode'] ?? 'Cash').toString();
    String mode = purchaseMode.toLowerCase();

    final paymentBreakdown =
        widget.sale['paymentBreakdown'] ??
        {'cash': 0, 'card': 0, 'credit': 0, 'gpay': 0};

    String shopName = widget.getShopName(widget.sale);

    double exchangeValue =
        (widget.sale['exchangeValue'] as num?)?.toDouble() ?? 0;
    double discount = (widget.sale['discount'] as num?)?.toDouble() ?? 0;
    double totalAmount = widget.getTotalAmount(widget.sale);
    double price = (widget.sale['price'] as num?)?.toDouble() ?? 0;
    double effectivePrice =
        (widget.sale['effectivePrice'] as num?)?.toDouble() ?? 0;
    double amountToPay = (widget.sale['amountToPay'] as num?)?.toDouble() ?? 0;

    double cashAmount = widget.extractAmount(widget.sale, [
      'cashAmount',
      'cash',
    ]);
    double cardAmount = widget.extractAmount(widget.sale, [
      'cardAmount',
      'card',
    ]);
    double gpayAmount = widget.extractAmount(widget.sale, [
      'gpayAmount',
      'upiAmount',
      'gpay',
      'upi',
    ]);
    double creditAmount = widget.extractAmount(widget.sale, [
      'creditAmount',
      'credit',
    ]);

    if (paymentBreakdown is Map) {
      Map<String, dynamic> stringKeyMap = {};
      paymentBreakdown.forEach((key, value) {
        stringKeyMap[key.toString()] = value;
      });

      cashAmount = widget.extractAmount(stringKeyMap, ['cash']);
      cardAmount = widget.extractAmount(stringKeyMap, ['card']);
      gpayAmount = widget.extractAmount(stringKeyMap, ['gpay']);
      creditAmount = widget.extractAmount(stringKeyMap, ['credit']);
    }

    double verifiedAmount = 0;
    if (_cashVerified) verifiedAmount += cashAmount;
    if (_cardVerified) verifiedAmount += cardAmount;
    if (_gpayVerified) verifiedAmount += gpayAmount;

    double expectedAmount = amountToPay > 0 ? amountToPay : effectivePrice;
    if (expectedAmount <= 0) expectedAmount = totalAmount;

    bool isFullyVerified = (verifiedAmount - expectedAmount).abs() < 0.01;

    return AlertDialog(
      title: const Text('Verify Phone Sale Payment'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer: ${widget.sale['customerName'] ?? 'Unknown'}',
                style: const TextStyle(fontSize: 14),
              ),
              Text('Shop: $shopName', style: const TextStyle(fontSize: 14)),
              Text(
                'Product: ${widget.sale['brand'] ?? ''} ${widget.sale['productModel'] ?? ''}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Phone: ${widget.sale['customerPhone'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price Details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[900],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Original Price:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '₹${widget.formatNumber(price)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (discount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discount:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            '-₹${widget.formatNumber(discount)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (exchangeValue > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Exchange Value:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          Text(
                            '-₹${widget.formatNumber(exchangeValue)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Divider(color: Colors.grey.shade300, height: 1),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Amount to Pay:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[900],
                          ),
                        ),
                        Text(
                          '₹${widget.formatNumber(expectedAmount)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Payment Breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[900],
                ),
              ),
              const SizedBox(height: 8),

              if (cashAmount > 0) ...[
                _buildPaymentMethodRowWithAmount(
                  'Cash',
                  cashAmount,
                  _cashVerified,
                  (value) {
                    setState(() {
                      _cashVerified = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
              ],

              if (cardAmount > 0) ...[
                _buildPaymentMethodRowWithAmount(
                  'Card',
                  cardAmount,
                  _cardVerified,
                  (value) {
                    setState(() {
                      _cardVerified = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
              ],

              if (gpayAmount > 0) ...[
                _buildPaymentMethodRowWithAmount(
                  'UPI',
                  gpayAmount,
                  _gpayVerified,
                  (value) {
                    setState(() {
                      _gpayVerified = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
              ],

              if (creditAmount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credit',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '₹${widget.formatNumber(creditAmount)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFullyVerified
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFullyVerified ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFullyVerified ? Icons.check_circle : Icons.info,
                      color: isFullyVerified ? Colors.green : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFullyVerified
                                ? 'Fully Verified'
                                : 'Partial Verification',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isFullyVerified
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verified: ₹${widget.formatNumber(verifiedAmount)} / ₹${widget.formatNumber(expectedAmount)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              final newPaymentBreakdown = {
                'cash': _cashVerified,
                'card': _cardVerified,
                'gpay': _gpayVerified,
              };

              bool isVerified = isFullyVerified;

              final updates = <String, dynamic>{
                'paymentBreakdownVerified': newPaymentBreakdown,
                'paymentVerified': isVerified,
              };

              await widget.onUpdate(widget.collection, widget.docId, updates);
              widget.onSuccess();

              Navigator.pop(context);
              _showSnackBar(
                isVerified
                    ? 'Payment fully verified successfully!'
                    : 'Payment partially verified',
                isVerified ? Colors.green : Colors.orange,
              );
            } catch (e) {
              _showSnackBar('Error: $e', Colors.red);
            }
          },
          child: const Text('Save & Update'),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodRowWithAmount(
    String method,
    double amount,
    bool verified,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: verified ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: verified ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$method Payment',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: verified ? Colors.green : Colors.black,
                  ),
                ),
                Text(
                  '₹${widget.formatNumber(amount)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: verified ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: verified,
            onChanged: onChanged,
            activeColor: Colors.green,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
