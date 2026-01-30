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
  List<Map<String, dynamic>> _filteredPurchases = [];
  bool _isLoading = true;
  double _totalAmount = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPurchases();
  }

  Future<void> _fetchPurchases() async {
    setState(() => _isLoading = true);

    try {
      final purchases = await _firestoreService.getPurchases();

      // Calculate total amount
      double total = 0;

      _purchases = purchases.map((purchase) {
        // Safely parse amounts
        final amount = _parseDouble(purchase['totalAmount']) ?? 0.0;
        total += amount;

        // Format date
        String formattedDate = 'N/A';
        try {
          final purchaseDate = purchase['purchaseDate'];
          if (purchaseDate is Timestamp) {
            formattedDate = DateFormat(
              'dd-MMM-yyyy',
            ).format(purchaseDate.toDate());
          } else if (purchaseDate is DateTime) {
            formattedDate = DateFormat('dd-MMM-yyyy').format(purchaseDate);
          } else if (purchaseDate is String) {
            formattedDate = purchaseDate;
          }
        } catch (e) {
          print('Error formatting date: $e');
        }

        return {
          'id': purchase['id'] ?? '',
          'invoiceNo': purchase['invoiceNumber']?.toString() ?? 'No Invoice',
          'supplierName':
              purchase['supplierName']?.toString() ?? 'Unknown Supplier',
          'date': formattedDate,
          'amount': amount,
          'totalDiscount': _parseDouble(purchase['totalDiscount']) ?? 0.0,
          'subtotal': _parseDouble(purchase['subtotal']) ?? 0.0,
          'gstAmount': _parseDouble(purchase['gstAmount']) ?? 0.0,
          'items': purchase['items'] ?? [],
          'notes': purchase['notes']?.toString() ?? '',
          'purchaseDate': purchase['purchaseDate'],
          'createdAt': purchase['createdAt'],
        };
      }).toList();

      // Initialize filtered purchases
      _filteredPurchases = List.from(_purchases);

      setState(() {
        _totalAmount = total;
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

  void _searchPurchases(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredPurchases = List.from(_purchases);
      });
      return;
    }

    final searchQuery = query.toLowerCase().trim();
    setState(() {
      _filteredPurchases = _purchases.where((purchase) {
        final invoiceNo = (purchase['invoiceNo'] ?? '')
            .toString()
            .toLowerCase();
        final supplierName = (purchase['supplierName'] ?? '')
            .toString()
            .toLowerCase();
        final invoiceLower = invoiceNo.toLowerCase();

        return invoiceLower.contains(searchQuery) ||
            supplierName.contains(searchQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Purchase History'),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search and Filter Section
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
                      controller: _searchController,
                      onChanged: _searchPurchases,
                      decoration: InputDecoration(
                        hintText: 'Search by invoice or supplier...',
                        border: InputBorder.none,
                        icon: Icon(
                          Icons.search,
                          size: 18,
                          color: _primaryGreen,
                        ),
                        hintStyle: const TextStyle(fontSize: 13),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchPurchases('');
                                },
                              )
                            : null,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _refreshPurchases,
                  icon: Icon(Icons.refresh, size: 22, color: _primaryGreen),
                  padding: const EdgeInsets.all(4),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Total Purchase Statistics
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                Text(
                  'Total Purchase',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹ ${_formatCurrency(_totalAmount)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
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
                  ? Center(
                      child: CircularProgressIndicator(color: _primaryGreen),
                    )
                  : _filteredPurchases.isEmpty
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
                            _searchController.text.isNotEmpty
                                ? 'No matching purchases found'
                                : 'No Purchases Found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'Try a different search term'
                                : 'Create your first purchase order',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          if (_searchController.text.isEmpty) ...[
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CreatePurchaseScreen(),
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
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredPurchases.length,
                      itemBuilder: (context, index) {
                        final purchase = _filteredPurchases[index];
                        return _buildPurchaseItem(purchase);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreatePurchaseScreen()),
          ).then((_) => _refreshPurchases());
        },
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Create New Purchase',
      ),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0.00').format(amount);
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
              '₹ ${_formatCurrency(amount)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
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
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
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

          // Header
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
            ],
          ),
          const SizedBox(height: 8),

          // Invoice and Supplier info
          Text(
            'Invoice: ${purchase['invoiceNo']}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Supplier: ${purchase['supplierName']}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            'Date: ${purchase['date']}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // Items List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items (${items.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              if (items.isNotEmpty)
                Text(
                  'Total: ₹ ${totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Items List
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index] as Map<String, dynamic>;
                final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
                final total = quantity * rate;
                final productName =
                    item['productName']?.toString() ?? 'Unknown Product';
                final brand = item['brand']?.toString();
                final imeis = item['imeis'] as List? ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        productName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),

                      // Brand (if available)
                      if (brand != null && brand.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          brand,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Quantity, Rate, Total
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

                      // IMEIs (if available)
                      if (imeis.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Divider(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 6),
                        Text(
                          'IMEIs (${imeis.length}):',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        ...imeis.take(2).map((imei) {
                          return Text(
                            '• ${imei.toString()}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          );
                        }),
                        if (imeis.length > 2) ...[
                          Text(
                            '+ ${imeis.length - 2} more',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // Purchase Summary
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  'Subtotal',
                  '₹ ${subtotal.toStringAsFixed(2)}',
                ),
                if (totalDiscount > 0)
                  _buildSummaryRow(
                    'Discount',
                    '-₹ ${totalDiscount.toStringAsFixed(2)}',
                  ),
                if (gstAmount > 0)
                  _buildSummaryRow(
                    'GST (18%)',
                    '₹ ${gstAmount.toStringAsFixed(2)}',
                  ),
                const Divider(height: 16),
                _buildSummaryRow(
                  'Total Amount',
                  '₹ ${totalAmount.toStringAsFixed(2)}',
                  isTotal: true,
                ),
              ],
            ),
          ),

          // Notes (if available)
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                notes,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ),
          ],

          // Close Button
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
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Close Details'),
            ),
          ),
          const SizedBox(height: 8),
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
