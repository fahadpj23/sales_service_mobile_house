import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EMIPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> sale;
  final String collection;
  final String docId;
  final String Function(Map<String, dynamic>) getShopName;
  final double Function(Map<String, dynamic>) getTotalAmount;
  final double Function(dynamic, List<String>) extractAmount;
  final String Function(double) formatNumber;
  final DateTime? Function(dynamic) parseDate;
  final Future<void> Function(String, String, Map<String, dynamic>) onUpdate;
  final VoidCallback onSuccess;

  const EMIPaymentDialog({
    Key? key,
    required this.sale,
    required this.collection,
    required this.docId,
    required this.getShopName,
    required this.getTotalAmount,
    required this.extractAmount,
    required this.formatNumber,
    required this.parseDate,
    required this.onUpdate,
    required this.onSuccess,
  }) : super(key: key);

  @override
  _EMIPaymentDialogState createState() => _EMIPaymentDialogState();
}

class _EMIPaymentDialogState extends State<EMIPaymentDialog> {
  late bool _downPaymentReceived;
  late bool _disbursementReceived;
  late bool _cashVerified;
  late bool _cardVerified;
  late bool _gpayVerified;

  @override
  void initState() {
    super.initState();
    _downPaymentReceived = widget.sale['downPaymentReceived'] ?? false;
    _disbursementReceived = widget.sale['disbursementReceived'] ?? false;

    final paymentBreakdownVerified =
        widget.sale['paymentBreakdownVerified'] ??
        {'cash': false, 'card': false, 'gpay': false};

    _cashVerified = _convertToBool(paymentBreakdownVerified['cash']);
    _cardVerified = _convertToBool(paymentBreakdownVerified['card']);
    _gpayVerified = _convertToBool(paymentBreakdownVerified['gpay']);
  }

  bool _convertToBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is num) {
      return value == 1;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    double downPayment = (widget.sale['downPayment'] as num?)?.toDouble() ?? 0;
    double disbursement =
        (widget.sale['disbursementAmount'] as num?)?.toDouble() ?? 0;
    double discount = (widget.sale['discount'] as num?)?.toDouble() ?? 0;
    double exchangeValue =
        (widget.sale['exchangeValue'] as num?)?.toDouble() ?? 0;
    double price = (widget.sale['price'] as num?)?.toDouble() ?? 0;
    double effectivePrice =
        (widget.sale['effectivePrice'] as num?)?.toDouble() ?? 0;
    double amountToPay = (widget.sale['amountToPay'] as num?)?.toDouble() ?? 0;
    double balanceReturned =
        (widget.sale['balanceReturnedToCustomer'] as num?)?.toDouble() ?? 0;
    double customerCredit =
        (widget.sale['customerCredit'] as num?)?.toDouble() ?? 0;

    final paymentBreakdown =
        widget.sale['paymentBreakdown'] ??
        {'cash': 0, 'card': 0, 'credit': 0, 'gpay': 0};

    double cashAmount = widget.extractAmount(paymentBreakdown, ['cash']);
    double cardAmount = widget.extractAmount(paymentBreakdown, ['card']);
    double creditAmount = widget.extractAmount(paymentBreakdown, ['credit']);
    double gpayAmount = widget.extractAmount(paymentBreakdown, ['gpay']);

    String shopName = widget.getShopName(widget.sale);

    DateTime? addedAt;
    if (widget.sale['addedAt'] != null) {
      addedAt = widget.parseDate(widget.sale['addedAt']);
    } else if (widget.sale['createdAt'] != null) {
      addedAt = widget.parseDate(widget.sale['createdAt']);
    } else if (widget.sale['saleDate'] != null) {
      addedAt = widget.parseDate(widget.sale['saleDate']);
    }

    return AlertDialog(
      title: const Text('Verify EMI Payment'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer: ${widget.sale['customerName'] ?? 'Unknown'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text('Shop: $shopName', style: const TextStyle(fontSize: 14)),
              Text(
                'Product: ${widget.sale['brand'] ?? ''} ${widget.sale['productModel'] ?? ''}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Finance: ${widget.sale['financeType'] ?? ''} ',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),

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
                      'Price Breakdown',
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
                    if (customerCredit > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Customer Credit:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade700,
                            ),
                          ),
                          Text(
                            '-₹${widget.formatNumber(customerCredit)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.purple.shade700,
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
                          'Effective Price:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[900],
                          ),
                        ),
                        Text(
                          '₹${widget.formatNumber(effectivePrice)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                    if (balanceReturned > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Balance Returned:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            '₹${widget.formatNumber(balanceReturned)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                          '₹${widget.formatNumber(amountToPay)}',
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
                'Down Payment',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[900],
                ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '₹${widget.formatNumber(downPayment)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _downPaymentReceived,
                    onChanged: (value) {
                      setState(() {
                        _downPaymentReceived = value;
                      });
                    },
                    activeColor: Colors.green,
                  ),
                ],
              ),

              if (downPayment > 0 && _downPaymentReceived) ...[
                const SizedBox(height: 8),
                Text(
                  'Down Payment Breakdown',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),

                if (cashAmount > 0)
                  _buildPaymentBreakdownRow('Cash', cashAmount, _cashVerified, (
                    value,
                  ) {
                    setState(() {
                      _cashVerified = value;
                    });
                  }),

                if (cardAmount > 0)
                  _buildPaymentBreakdownRow('Card', cardAmount, _cardVerified, (
                    value,
                  ) {
                    setState(() {
                      _cardVerified = value;
                    });
                  }),

                if (gpayAmount > 0)
                  _buildPaymentBreakdownRow('UPI', gpayAmount, _gpayVerified, (
                    value,
                  ) {
                    setState(() {
                      _gpayVerified = value;
                    });
                  }),

                if (creditAmount > 0) _buildCreditPaymentRow(creditAmount),
              ],

              const SizedBox(height: 16),

              Text(
                'Disbursement',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[900],
                ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '₹${widget.formatNumber(disbursement)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _disbursementReceived,
                    onChanged: (value) {
                      setState(() {
                        _disbursementReceived = value;
                      });
                    },
                    activeColor: Colors.green,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Text(
                'Transaction Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[900],
                ),
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
                    if (addedAt != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Added At:',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMMM yyyy, HH:mm:ss').format(addedAt!),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Added By:',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.sale['userEmail'] ?? 'Unknown',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_downPaymentReceived && _disbursementReceived)
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_downPaymentReceived && _disbursementReceived)
                        ? Colors.green
                        : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (_downPaymentReceived && _disbursementReceived)
                          ? Icons.check_circle
                          : Icons.info,
                      color: (_downPaymentReceived && _disbursementReceived)
                          ? Colors.green
                          : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_downPaymentReceived && _disbursementReceived)
                                ? 'Fully Verified'
                                : 'Partial Verification',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  (_downPaymentReceived &&
                                      _disbursementReceived)
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Down Payment: ${_downPaymentReceived ? '✓' : '✗'} | '
                            'Disbursement: ${_disbursementReceived ? '✓' : '✗'}',
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
              final updates = <String, dynamic>{
                'downPaymentReceived': _downPaymentReceived,
                'disbursementReceived': _disbursementReceived,
                'paymentVerified':
                    _downPaymentReceived && _disbursementReceived,
              };

              if (_downPaymentReceived) {
                updates['paymentBreakdownVerified'] = {
                  'cash': _cashVerified,
                  'card': _cardVerified,
                  'gpay': _gpayVerified,
                };
              }

              await widget.onUpdate(widget.collection, widget.docId, updates);
              widget.onSuccess();

              Navigator.pop(context);
              _showSnackBar('EMI payment verified successfully', Colors.green);
            } catch (e) {
              _showSnackBar('Error: $e', Colors.red);
            }
          },
          child: const Text('Save & Update'),
        ),
      ],
    );
  }

  Widget _buildPaymentBreakdownRow(
    String method,
    double amount,
    bool verified,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: verified ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: verified ? Colors.green : Colors.grey.shade300,
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
                  method,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: verified ? Colors.green : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${widget.formatNumber(amount)}',
                  style: TextStyle(
                    fontSize: 11,
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
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildCreditPaymentRow(double amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${widget.formatNumber(amount)}',
                  style: TextStyle(fontSize: 11, color: Colors.green),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Pending',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
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
