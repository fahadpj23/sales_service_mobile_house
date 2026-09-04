// lib/screens/finance_dashboard_tabs/dialogs/generic_payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  State<GenericPaymentDialog> createState() => _GenericPaymentDialogState();
}

class _GenericPaymentDialogState extends State<GenericPaymentDialog> {
  late bool cashVerified;
  late bool cardVerified;
  late bool gpayVerified;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    cashVerified = widget.initialCashVerified;
    cardVerified = widget.initialCardVerified;
    gpayVerified = widget.initialGpayVerified;

    // Debug print
    print('GenericPaymentDialog initialized:');
    print('  cashVerified: $cashVerified');
    print('  cardVerified: $cardVerified');
    print('  gpayVerified: $gpayVerified');
    print('  cashAmount: ${widget.cashAmount}');
    print('  cardAmount: ${widget.cardAmount}');
    print('  gpayAmount: ${widget.gpayAmount}');
  }

  double get verifiedAmount {
    double total = 0;
    if (cashVerified) total += widget.cashAmount;
    if (cardVerified) total += widget.cardAmount;
    if (gpayVerified) total += widget.gpayAmount;
    return total;
  }

  bool get allVerified =>
      verifiedAmount >= widget.totalAmount &&
      cashVerified &&
      cardVerified &&
      gpayVerified;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 400,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.verified, color: Colors.green[700], size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Verify Payment',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Customer & Shop Info
              _buildInfoRow(
                'Customer:',
                widget.sale['customerName'] ?? 'Unknown',
              ),
              _buildInfoRow('Shop:', widget.shopName),
              _buildInfoRow('Product:', _getProductDescription()),
              const SizedBox(height: 8),

              // Total Amount
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₹${widget.formatNumber(widget.totalAmount)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),

              // Partial Verification Progress
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Verified Amount:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '₹${widget.formatNumber(verifiedAmount)} / ₹${widget.formatNumber(widget.totalAmount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: verifiedAmount >= widget.totalAmount
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Methods with Switches - ALWAYS SHOW
              const Text(
                'Payment Methods',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Cash Switch
              _buildPaymentMethodSwitch(
                icon: Icons.money,
                label: 'Cash',
                amount: widget.cashAmount,
                verified: cashVerified,
                onChanged: (value) {
                  setState(() {
                    cashVerified = value;
                  });
                },
              ),

              // Card Switch
              _buildPaymentMethodSwitch(
                icon: Icons.credit_card,
                label: 'Card',
                amount: widget.cardAmount,
                verified: cardVerified,
                onChanged: (value) {
                  setState(() {
                    cardVerified = value;
                  });
                },
              ),

              // UPI Switch
              _buildPaymentMethodSwitch(
                icon: Icons.qr_code_scanner,
                label: 'UPI',
                amount: widget.gpayAmount,
                verified: gpayVerified,
                onChanged: (value) {
                  setState(() {
                    gpayVerified = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Additional Info
              if (widget.sale['billDate'] != null) ...[
                _buildInfoRow('Date:', _formatDate(widget.sale['billDate'])),
              ],
              if (widget.sale['billNumber'] != null &&
                  widget.sale['billNumber'].toString().isNotEmpty) ...[
                _buildInfoRow('Bill No:', widget.sale['billNumber'].toString()),
              ],
              if (widget.sale['taxableAmount'] != null) ...[
                _buildInfoRow(
                  'Taxable Amount:',
                  '₹${widget.formatNumber((widget.sale['taxableAmount'] as num?)?.toDouble() ?? 0)}',
                ),
              ],
              if (widget.sale['gstAmount'] != null &&
                  widget.sale['gstRate'] != null) ...[
                _buildInfoRow(
                  'GST ${widget.sale['gstRate']}%:',
                  '₹${widget.formatNumber((widget.sale['gstAmount'] as num?)?.toDouble() ?? 0)}',
                ),
              ],
              if (widget.sale['purchaseMode'] != null &&
                  widget.sale['purchaseMode'].toString().isNotEmpty) ...[
                _buildInfoRow(
                  'Payment Mode:',
                  widget.sale['purchaseMode'].toString(),
                ),
              ],

              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isLoading ? null : _saveAndUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Save & Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSwitch({
    required IconData icon,
    required String label,
    required double amount,
    required bool verified,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: verified ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: verified ? Colors.green.shade200 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: verified ? Colors.green : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$label (₹${widget.formatNumber(amount)})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: verified ? FontWeight.w600 : FontWeight.normal,
                  color: verified ? Colors.green.shade800 : Colors.grey[700],
                ),
              ),
            ),
            Switch(
              value: verified,
              onChanged: onChanged,
              activeColor: Colors.green,
              inactiveThumbColor: Colors.grey[400],
              activeTrackColor: Colors.green.shade100,
              inactiveTrackColor: Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }

  String _getProductDescription() {
    // Check for nested product map
    if (widget.sale['product'] is Map) {
      final product = widget.sale['product'] as Map<String, dynamic>;
      String name = product['productName'] ?? product['name'] ?? '';
      String brand = product['brand'] ?? product['brandName'] ?? '';
      if (brand.isNotEmpty && name.isNotEmpty) {
        return '$brand - $name';
      }
      return name.isNotEmpty ? name : 'N/A';
    }

    // Check for appliance specific fields
    if (widget.sale['applianceProductName'] != null) {
      String brand = widget.sale['applianceBrand'] ?? '';
      String name = widget.sale['applianceProductName'] ?? '';
      if (brand.isNotEmpty) {
        return '$brand - $name';
      }
      return name;
    }

    // Check for TV specific fields
    if (widget.sale['modelName'] != null) {
      return widget.sale['modelName'];
    }

    // Check for product name
    if (widget.sale['productName'] != null) {
      return widget.sale['productName'];
    }

    return widget.sale['name'] ?? 'N/A';
  }

  String _formatDate(dynamic date) {
    try {
      if (date == null) return 'N/A';
      if (date is Timestamp) {
        return DateFormat('dd/MM/yyyy').format(date.toDate());
      } else if (date is DateTime) {
        return DateFormat('dd/MM/yyyy').format(date);
      } else if (date is String) {
        try {
          final parsed = DateTime.parse(date);
          return DateFormat('dd/MM/yyyy').format(parsed);
        } catch (e) {
          // Try to extract date from string
          if (date.length >= 10) {
            return date.substring(0, 10);
          }
          return date;
        }
      }
      return date.toString();
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _saveAndUpdate() async {
    setState(() => isLoading = true);

    final paymentBreakdown = {
      'cash': cashVerified,
      'card': cardVerified,
      'gpay': gpayVerified,
    };

    final isFullyVerified = allVerified;

    try {
      final success = await widget.onUpdate(paymentBreakdown, isFullyVerified);
      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verification updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }
}
