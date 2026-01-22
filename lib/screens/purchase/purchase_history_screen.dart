// purchase_history_screen.dart
import 'package:flutter/material.dart';
import 'package:sales_stock/services/firestore_service.dart';
import 'package:sales_stock/screens/purchase/create_purchase_screen.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Color _primaryGreen = const Color(0xFF2E7D32);
  final Color _lightGreen = const Color(0xFF4CAF50);
  final Color _backgroundColor = const Color(0xFFF5F9F5);

  List<Map<String, dynamic>> _purchases = [];
  bool _isLoading = true;
  double _totalAmount = 0;
  double _paidAmount = 0;
  double _pendingAmount = 0;

  @override
  void initState() {
    super.initState();
    _fetchPurchases();
  }

  Future<void> _fetchPurchases() async {
    setState(() => _isLoading = true);

    try {
      final purchases = await _firestoreService.getPurchases();

      // Calculate statistics
      double total = 0;
      double paid = 0;
      double pending = 0;

      _purchases = purchases.map((doc) {
        Map<String, dynamic> purchase = doc.data() as Map<String, dynamic>;

        // Safely parse amounts
        final amount = _parseDouble(purchase['totalAmount']) ?? 0.0;
        total += amount;

        // Since there's no 'status' field in your data, we'll use a default
        // You can add this field to Firestore or determine status from payment data
        final String status =
            'Paid'; // Default to Paid since your example doesn't show status
        if (status == 'Paid') {
          paid += amount;
        } else {
          pending += amount;
        }

        // Format date
        String formattedDate = 'N/A';
        try {
          final purchaseDate = purchase['purchaseDate'];
          if (purchaseDate is Timestamp) {
            formattedDate = DateFormat(
              'dd-MMM-yyyy',
            ).format(purchaseDate.toDate());
          } else if (purchaseDate is String) {
            formattedDate = purchaseDate;
          }
        } catch (e) {
          print('Error formatting date: $e');
        }

        return {
          'id': doc.id,
          'invoiceNo': purchase['invoiceNumber']?.toString() ?? 'No Invoice',
          'supplierName':
              purchase['supplierName']?.toString() ?? 'Unknown Supplier',
          'date': formattedDate,
          'amount': amount,
          'status': status,
          'totalDiscount': _parseDouble(purchase['totalDiscount']) ?? 0.0,
          'subtotal': _parseDouble(purchase['subtotal']) ?? 0.0,
          'gstAmount': _parseDouble(purchase['gstAmount']) ?? 0.0,
          'items': purchase['items'] ?? [],
          'notes': purchase['notes']?.toString() ?? '',
          'purchaseDate': purchase['purchaseDate'],
          'createdAt': purchase['createdAt'],
        };
      }).toList();

      setState(() {
        _totalAmount = total;
        _paidAmount = paid;
        _pendingAmount = pending;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching purchases: $e');
      setState(() => _isLoading = false);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load purchases: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method to safely parse double values
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> _refreshPurchases() async {
    await _fetchPurchases();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Options
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      // Implement search functionality
                      _searchPurchases(value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search purchases...',
                      border: InputBorder.none,
                      icon: Icon(Icons.search, size: 18, color: _primaryGreen),
                      hintStyle: TextStyle(fontSize: 13),
                    ),
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.filter_alt,
                  size: 18,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _lightGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calendar_month,
                  size: 18,
                  color: _primaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _refreshPurchases,
                icon: Icon(Icons.refresh, size: 20, color: _primaryGreen),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ),

        // Stats Summary
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPurchaseStat(
                'Total',
                '₹ ${_formatCurrency(_totalAmount)}',
                Colors.blue.shade700,
              ),
              _buildPurchaseStat(
                'Paid',
                '₹ ${_formatCurrency(_paidAmount)}',
                _lightGreen,
              ),
              _buildPurchaseStat(
                'Pending',
                '₹ ${_formatCurrency(_pendingAmount)}',
                Colors.orange.shade700,
              ),
            ],
          ),
        ),

        // Purchases List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshPurchases,
            color: _primaryGreen,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryGreen))
                : _purchases.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Purchases Found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first purchase',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            // Navigate to create purchase screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreatePurchaseScreen(),
                              ),
                            ).then((_) => _refreshPurchases());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Create Purchase'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _purchases.length,
                    itemBuilder: (context, index) {
                      final purchase = _purchases[index];
                      return _buildPurchaseItem(purchase);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }

  void _searchPurchases(String query) {
    // Implement search logic here
    // Filter purchases based on invoice number, supplier name, etc.
    if (query.isEmpty) {
      _fetchPurchases();
      return;
    }

    // If you want to implement local search, you'd need to keep a copy of all purchases
    // and filter based on the query
  }

  Widget _buildPurchaseStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
      ],
    );
  }

  Widget _buildPurchaseItem(Map<String, dynamic> purchase) {
    final amount = purchase['amount'] as double;
    final items = purchase['items'] as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _lightGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.receipt_long, size: 24, color: _lightGreen),
        ),
        title: Text(
          purchase['invoiceNo'] ?? 'No Invoice',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              purchase['supplierName'] ?? 'Unknown Supplier',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${purchase['date']}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              'Items: ${items.length}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹ ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: purchase['status'] == 'Paid'
                    ? _lightGreen.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                purchase['status']?.toString() ?? 'Unknown',
                style: TextStyle(
                  fontSize: 10,
                  color: purchase['status'] == 'Paid'
                      ? _lightGreen
                      : Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          _showPurchaseDetails(purchase);
        },
      ),
    );
  }

  void _showPurchaseDetails(Map<String, dynamic> purchase) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return PurchaseDetailsSheet(purchase: purchase);
      },
    );
  }
}

class PurchaseDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> purchase;

  const PurchaseDetailsSheet({Key? key, required this.purchase})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final items = purchase['items'] as List;
    final totalDiscount = purchase['totalDiscount'] as double;
    final subtotal = purchase['subtotal'] as double;
    final gstAmount = purchase['gstAmount'] as double;
    final totalAmount = purchase['amount'] as double;
    final notes = purchase['notes'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Purchase Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                purchase['invoiceNo']?.toString() ?? 'N/A',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Supplier: ${purchase['supplierName']}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          Text(
            'Date: ${purchase['date']}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // Items List
          Text(
            'Items (${items.length})',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index] as Map<String, dynamic>;
                final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
                final total = quantity * rate;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['productName']?.toString() ?? 'Unknown Product',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Qty: $quantity',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Rate: ₹ ${rate.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Total: ₹ ${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      if (item['imei'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'IMEI: ${item['imei']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // Summary
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  'Subtotal',
                  '₹ ${subtotal.toStringAsFixed(2)}',
                ),
                _buildSummaryRow(
                  'Discount',
                  '-₹ ${totalDiscount.toStringAsFixed(2)}',
                ),
                _buildSummaryRow('GST', '₹ ${gstAmount.toStringAsFixed(2)}'),
                const Divider(height: 16),
                _buildSummaryRow(
                  'Total Amount',
                  '₹ ${totalAmount.toStringAsFixed(2)}',
                  isTotal: true,
                ),
              ],
            ),
          ),

          // Notes
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Notes:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(notes, style: TextStyle(color: Colors.grey.shade600)),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
