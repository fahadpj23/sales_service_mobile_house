import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sale.dart';

class TransactionsDetailsScreen extends StatelessWidget {
  final List<Sale> sales;
  final String Function(double) formatNumber;

  TransactionsDetailsScreen({required this.sales, required this.formatNumber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transactions Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Total Transactions',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${sales.length}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '₹${formatNumber(sales.fold(0.0, (sum, sale) => sum + sale.amount))}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A7D4A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: sales.length,
              itemBuilder: (context, index) {
                final sale = sales[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(
                          sale.category,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          _getCategoryIcon(sale.category),
                          color: _getCategoryColor(sale.category),
                          size: 20,
                        ),
                      ),
                    ),
                    title: Text(
                      sale.customerName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${sale.category} • ${sale.shopName}',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(sale.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${formatNumber(sale.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                        SizedBox(height: 2),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF1A7D4A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sale.type.replaceAll('_', ' '),
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF1A7D4A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      _showTransactionDetails(context, sale);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Sale sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transaction Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Customer', sale.customerName),
              _buildDetailRow('Category', sale.category),
              _buildDetailRow('Shop', sale.shopName),
              _buildDetailRow(
                'Date',
                DateFormat('dd MMM yyyy, hh:mm a').format(sale.date),
              ),
              _buildDetailRow('Amount', '₹${formatNumber(sale.amount)}'),
              if (sale.customerPhone != null)
                _buildDetailRow('Phone', sale.customerPhone!),
              if (sale.brand != null) _buildDetailRow('Brand', sale.brand!),
              if (sale.model != null) _buildDetailRow('Model', sale.model!),
              if (sale.imei != null) _buildDetailRow('IMEI', sale.imei!),
              if (sale.salesPersonName != null)
                _buildDetailRow('Sales Person', sale.salesPersonName!),
              if (sale.cashAmount != null && sale.cashAmount! > 0)
                _buildDetailRow('Cash', '₹${formatNumber(sale.cashAmount!)}'),
              if (sale.cardAmount != null && sale.cardAmount! > 0)
                _buildDetailRow('Card', '₹${formatNumber(sale.cardAmount!)}'),
              if (sale.gpayAmount != null && sale.gpayAmount! > 0)
                _buildDetailRow('GPay', '₹${formatNumber(sale.gpayAmount!)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'New Phone':
        return Color(0xFF4CAF50);
      case 'Base Model':
        return Color(0xFF2196F3);
      case 'Second Phone':
        return Color(0xFF9C27B0);
      case 'Service':
        return Color(0xFFFF9800);
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'New Phone':
        return Icons.phone_android;
      case 'Base Model':
        return Icons.phone_iphone;
      case 'Second Phone':
        return Icons.phone_iphone_outlined;
      case 'Service':
        return Icons.build;
      default:
        return Icons.category;
    }
  }
}
