import 'package:flutter/material.dart';

class GenericPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> sale;
  final String collection;
  final String docId;
  final String shopName;
  final double totalAmount;
  final double cashAmount;
  final double cardAmount;
  final double gpayAmount;
  final bool initialCashVerified;
  final bool initialCardVerified;
  final bool initialGpayVerified;
  final bool useSwitches;
  final String Function(double) formatNumber;
  final Future<bool> Function(Map<String, dynamic>, bool) onUpdate;

  const GenericPaymentDialog({
    Key? key,
    required this.sale,
    required this.collection,
    required this.docId,
    required this.shopName,
    required this.totalAmount,
    required this.cashAmount,
    required this.cardAmount,
    required this.gpayAmount,
    required this.initialCashVerified,
    required this.initialCardVerified,
    required this.initialGpayVerified,
    required this.useSwitches,
    required this.formatNumber,
    required this.onUpdate,
  }) : super(key: key);

  @override
  _GenericPaymentDialogState createState() => _GenericPaymentDialogState();
}

class _GenericPaymentDialogState extends State<GenericPaymentDialog> {
  late bool _cashVerified;
  late bool _cardVerified;
  late bool _gpayVerified;

  @override
  void initState() {
    super.initState();
    _cashVerified = widget.initialCashVerified;
    _cardVerified = widget.initialCardVerified;
    _gpayVerified = widget.initialGpayVerified;
  }

  double _calculateVerifiedAmount() {
    double verified = 0;
    if (_cashVerified) verified += widget.cashAmount;
    if (_cardVerified) verified += widget.cardAmount;
    if (_gpayVerified) verified += widget.gpayAmount;
    return verified;
  }

  bool _isFullyVerified() {
    final verifiedAmount = _calculateVerifiedAmount();
    return (verifiedAmount - widget.totalAmount).abs() < 0.01;
  }

  @override
  Widget build(BuildContext context) {
    final verifiedAmount = _calculateVerifiedAmount();
    final isFullyVerified = _isFullyVerified();

    return AlertDialog(
      title: const Text('Verify Payment'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer: ${widget.sale['customerName'] ?? 'Walk-in'}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Shop: ${widget.shopName}',
                style: const TextStyle(fontSize: 14),
              ),
              if (widget.sale.containsKey('modelName')) ...[
                Text(
                  'Model: ${widget.sale['modelName']}',
                  style: const TextStyle(fontSize: 14),
                ),
              ] else if (widget.sale.containsKey('productName')) ...[
                Text(
                  'Product: ${widget.sale['productName']}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              Text(
                'Total: ₹${widget.formatNumber(widget.totalAmount)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              if (widget.cashAmount > 0) ...[
                if (widget.useSwitches)
                  _buildSwitchPaymentRow(
                    'Cash',
                    widget.cashAmount,
                    _cashVerified,
                    (value) {
                      setState(() {
                        _cashVerified = value;
                      });
                    },
                  )
                else
                  _buildRadioPaymentRow(
                    'Cash',
                    widget.cashAmount,
                    _cashVerified,
                    (value) {
                      setState(() {
                        _cashVerified = value;
                        if (value) {
                          _cardVerified = false;
                          _gpayVerified = false;
                        }
                      });
                    },
                  ),
                const SizedBox(height: 12),
              ],

              if (widget.cardAmount > 0) ...[
                if (widget.useSwitches)
                  _buildSwitchPaymentRow(
                    'Card',
                    widget.cardAmount,
                    _cardVerified,
                    (value) {
                      setState(() {
                        _cardVerified = value;
                      });
                    },
                  )
                else
                  _buildRadioPaymentRow(
                    'Card',
                    widget.cardAmount,
                    _cardVerified,
                    (value) {
                      setState(() {
                        _cardVerified = value;
                        if (value) {
                          _cashVerified = false;
                          _gpayVerified = false;
                        }
                      });
                    },
                  ),
                const SizedBox(height: 12),
              ],

              if (widget.gpayAmount > 0) ...[
                if (widget.useSwitches)
                  _buildSwitchPaymentRow(
                    'UPI',
                    widget.gpayAmount,
                    _gpayVerified,
                    (value) {
                      setState(() {
                        _gpayVerified = value;
                      });
                    },
                  )
                else
                  _buildRadioPaymentRow(
                    'UPI',
                    widget.gpayAmount,
                    _gpayVerified,
                    (value) {
                      setState(() {
                        _gpayVerified = value;
                        if (value) {
                          _cashVerified = false;
                          _cardVerified = false;
                        }
                      });
                    },
                  ),
              ],

              const SizedBox(height: 16),

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
                            'Verified: ₹${widget.formatNumber(verifiedAmount)} / ₹${widget.formatNumber(widget.totalAmount)}',
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
            final newPaymentBreakdown = {
              'cash': _cashVerified,
              'card': _cardVerified,
              'gpay': _gpayVerified,
            };

            final isVerified = _isFullyVerified();

            final success = await widget.onUpdate(
              newPaymentBreakdown,
              isVerified,
            );

            if (success) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isVerified
                        ? 'Payment fully verified successfully!'
                        : 'Payment partially verified',
                  ),
                  backgroundColor: isVerified ? Colors.green : Colors.orange,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to update payment verification'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Save & Update'),
        ),
      ],
    );
  }

  Widget _buildSwitchPaymentRow(
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
                const SizedBox(height: 4),
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

  Widget _buildRadioPaymentRow(
    String method,
    double amount,
    bool selected,
    ValueChanged<bool> onChanged,
  ) {
    return InkWell(
      onTap: () {
        onChanged(!selected);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? Colors.green.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.green : Colors.grey,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: selected,
              onChanged: (value) {
                onChanged(value ?? false);
              },
              activeColor: Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.green : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${widget.formatNumber(amount)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.green : Colors.grey,
                    ),
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
