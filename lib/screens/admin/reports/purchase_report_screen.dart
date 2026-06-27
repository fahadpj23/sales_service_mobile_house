import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class PurchaseReportScreen extends StatefulWidget {
  const PurchaseReportScreen({super.key});

  @override
  State<PurchaseReportScreen> createState() => _PurchaseReportScreenState();
}

class _PurchaseReportScreenState extends State<PurchaseReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _searchQuery = '';
  String? _selectedFilter;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;
  bool _isGeneratingPDF = false;
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _filteredPurchases = [];

  // Summary statistics
  int _totalBills = 0;
  int _totalProducts = 0;
  double _totalAmount = 0.0;

  final List<String> _filterOptions = [
    'All',
    'Last 7 Days',
    'Last 30 Days',
    'This Month',
    'Last Month',
    'Custom Range',
  ];

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);

    try {
      Query query = _firestore
          .collection('purchases')
          .orderBy('date', descending: true);
      QuerySnapshot snapshot = await query.get();

      _purchases = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        _purchases.add({
          'id': doc.id,
          'supplierName': data['supplierName'] ?? 'Unknown',
          'supplierId': data['supplierId'] ?? '',
          'invoiceNo': data['invoiceNo'] ?? 'N/A',
          'date': data['date'] != null
              ? (data['date'] as Timestamp).toDate()
              : DateTime.now(),
          'createdAt': data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
          'totalAmount': (data['totalAmount'] ?? 0).toDouble(),
          'gstAmount': (data['gstAmount'] ?? 0).toDouble(),
          'roundingAmount': (data['roundingAmount'] ?? 0).toDouble(),
          'grandTotal': (data['grandTotal'] ?? 0).toDouble(),
          'items': List<Map<String, dynamic>>.from(data['items'] ?? []),
          'itemCount': (data['items'] ?? []).length,
          'taxableAmount': (data['totalAmount'] ?? 0).toDouble(),
          'taxPercentage': 18, // Default GST percentage
        });
      }

      _applyFilters();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error loading purchases: $e',
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_purchases);

    if (_selectedFilter != null && _selectedFilter != 'All') {
      DateTime now = DateTime.now();
      DateTime startDate;

      switch (_selectedFilter) {
        case 'Last 7 Days':
          startDate = now.subtract(const Duration(days: 7));
          filtered = filtered
              .where((p) => p['date'].isAfter(startDate))
              .toList();
          break;
        case 'Last 30 Days':
          startDate = now.subtract(const Duration(days: 30));
          filtered = filtered
              .where((p) => p['date'].isAfter(startDate))
              .toList();
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          filtered = filtered
              .where((p) => p['date'].isAfter(startDate))
              .toList();
          break;
        case 'Last Month':
          startDate = DateTime(now.year, now.month - 1, 1);
          DateTime endDate = DateTime(now.year, now.month, 0);
          filtered = filtered
              .where(
                (p) =>
                    p['date'].isAfter(startDate) && p['date'].isBefore(endDate),
              )
              .toList();
          break;
        case 'Custom Range':
          if (_startDate != null && _endDate != null) {
            filtered = filtered
                .where(
                  (p) =>
                      p['date'].isAfter(_startDate!) &&
                      p['date'].isBefore(
                        _endDate!.add(const Duration(days: 1)),
                      ),
                )
                .toList();
          }
          break;
      }
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (p) =>
                p['supplierName'].toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                p['invoiceNo'].toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    // Calculate summary statistics
    _calculateSummary(filtered);

    setState(() {
      _filteredPurchases = filtered;
    });
  }

  void _calculateSummary(List<Map<String, dynamic>> purchases) {
    _totalBills = purchases.length;
    _totalProducts = 0;
    _totalAmount = 0.0;

    for (var purchase in purchases) {
      _totalProducts += (purchase['itemCount'] ?? 0) as int;
      _totalAmount += (purchase['grandTotal'] ?? 0.0) as double;
    }
  }

  Future<void> _selectDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedFilter = 'Custom Range';
      });
      _applyFilters();
    }
  }

  // PDF Generation Method with Share functionality
  Future<void> _generateAndSharePDF() async {
    if (_filteredPurchases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No purchases to generate report'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGeneratingPDF = true);

    try {
      // Sort purchases by date
      List<Map<String, dynamic>> sortedPurchases = List.from(
        _filteredPurchases,
      );
      sortedPurchases.sort((a, b) => a['date'].compareTo(b['date']));

      // Calculate totals
      double totalTaxable = 0;
      double totalTax = 0;
      double totalRounding = 0;
      double totalBillAmount = 0;
      int totalItems = 0;

      for (var purchase in sortedPurchases) {
        totalTaxable += purchase['taxableAmount'] ?? 0;
        totalTax += purchase['gstAmount'] ?? 0;
        totalRounding += purchase['roundingAmount'] ?? 0;
        totalBillAmount += purchase['grandTotal'] ?? 0;
        totalItems += (purchase['itemCount'] ?? 0) as int;
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Header
              pw.Center(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'MOBILE HOUSE',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Purchase Register',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Period: ${DateFormat('dd/MM/yyyy').format(_startDate ?? DateTime.now().subtract(const Duration(days: 30)))} - ${DateFormat('dd/MM/yyyy').format(_endDate ?? DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(thickness: 1),
                    pw.SizedBox(height: 10),
                  ],
                ),
              ),
              // Summary Cards
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          'Total Bills',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          sortedPurchases.length.toString(),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'Total Products',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          totalItems.toString(),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'Total Amount',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          '₹${totalBillAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              // Table Header
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(0.12), // Date
                  1: pw.FlexColumnWidth(0.15), // Bill No
                  2: pw.FlexColumnWidth(0.20), // Seller Name
                  3: pw.FlexColumnWidth(0.13), // Taxable
                  4: pw.FlexColumnWidth(0.10), // Tax
                  5: pw.FlexColumnWidth(0.10), // Cess
                  6: pw.FlexColumnWidth(0.10), // Rounding
                  7: pw.FlexColumnWidth(0.10), // Bill Amt
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Date',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Bill No',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Seller Name',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Taxable',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Tax',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Cess',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Rounding',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Bill Amt',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Table Rows
                  ...sortedPurchases.map((purchase) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            DateFormat('dd/MM/yyyy').format(purchase['date']),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            purchase['invoiceNo'] ?? 'N/A',
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            purchase['supplierName'] ?? 'Unknown',
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            (purchase['taxableAmount'] ?? 0).toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            (purchase['gstAmount'] ?? 0).toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            '0.00',
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            (purchase['roundingAmount'] ?? 0).toStringAsFixed(
                              2,
                            ),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            (purchase['grandTotal'] ?? 0).toStringAsFixed(2),
                            style: const pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 10),
              // Summary Section - Row layout
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side - Taxable and Tax
                    pw.Row(
                      children: [
                        pw.Text(
                          'Taxable Total: ',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          totalTaxable.toStringAsFixed(2),
                          style: const pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Text(
                          'Tax Total: ',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          totalTax.toStringAsFixed(2),
                          style: const pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(width: 20),
                      ],
                    ),
                    // Right side - Grand Total
                    pw.Row(
                      children: [
                        pw.Text(
                          'Grand Total: ',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          totalBillAmount.toStringAsFixed(2),
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
            ];
          },
        ),
      );

      // Save PDF to temporary file
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final fileName =
          'purchase_report_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Share the PDF
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Purchase Report - MOBILE HOUSE\nPeriod: ${DateFormat('dd/MM/yyyy').format(_startDate ?? DateTime.now().subtract(const Duration(days: 30)))} to ${DateFormat('dd/MM/yyyy').format(_endDate ?? DateTime.now())}\nTotal Bills: ${_filteredPurchases.length}\nTotal Products: ${_totalProducts}\nTotal Amount: ₹${_totalAmount.toStringAsFixed(2)}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generated and shared successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isGeneratingPDF = false);
    }
  }

  Future<void> _deletePurchase(Map<String, dynamic> purchase) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red[700],
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'Delete Purchase',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this purchase?',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice: ${purchase['invoiceNo']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Supplier: ${purchase['supplierName']}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      'Amount: ₹${purchase['grandTotal'].toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(purchase['date'])}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This action cannot be undone!',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Delete', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      setState(() => _isLoading = true);

      try {
        await _firestore.collection('purchases').doc(purchase['id']).delete();

        setState(() {
          _purchases.removeWhere((p) => p['id'] == purchase['id']);
          _filteredPurchases.removeWhere((p) => p['id'] == purchase['id']);
        });

        // Recalculate summary after deletion
        _calculateSummary(_filteredPurchases);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Purchase deleted successfully!',
              style: TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting purchase: $e',
              style: TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPurchaseDetails(Map<String, dynamic> purchase) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        color: Colors.green[700],
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchase Details',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          Text(
                            'Invoice: ${purchase['invoiceNo']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _deletePurchase(purchase);
                          },
                          icon: Icon(
                            Icons.delete,
                            color: Colors.red[700],
                            size: 18,
                          ),
                          tooltip: 'Delete',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildSupplierInfoSection(purchase),
                      const SizedBox(height: 10),
                      _buildItemsSection(purchase),
                      const SizedBox(height: 10),
                      _buildSummarySection(purchase),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text(
                                'Download',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green[700],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                side: BorderSide(color: Colors.green[700]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text(
                                'Close',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
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
          );
        },
      ),
    );
  }

  Widget _buildSupplierInfoSection(Map<String, dynamic> purchase) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supplier Information',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 6),
            _buildDetailRow('Invoice No', purchase['invoiceNo']),
            _buildDetailRow('Supplier', purchase['supplierName']),
            _buildDetailRow(
              'Date',
              DateFormat('dd/MM/yyyy hh:mm a').format(purchase['date']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(Map<String, dynamic> purchase) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Items (${purchase['itemCount']})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 6),
            ...purchase['items'].map<Widget>((item) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item['productName'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Qty: ${item['quantity']}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '₹${(item['total'] ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(Map<String, dynamic> purchase) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', purchase['totalAmount']),
          _buildSummaryRow('GST', purchase['gstAmount']),
          if (purchase['roundingAmount'] != 0)
            _buildSummaryRow(
              'Rounding',
              purchase['roundingAmount'],
              color: purchase['roundingAmount'] > 0
                  ? Colors.orange
                  : Colors.blue,
            ),
          const Divider(height: 12),
          _buildSummaryRow(
            'Grand Total',
            purchase['grandTotal'],
            isBold: true,
            color: Colors.green[700]!,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 13 : 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? (isBold ? Colors.green[700] : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Row(
        children: [
          _buildSummaryCard(
            'Total Bills',
            _totalBills.toString(),
            Icons.receipt_long,
            Colors.blue,
          ),
          const SizedBox(width: 8),
          _buildSummaryCard(
            'Total Products',
            _totalProducts.toString(),
            Icons.shopping_cart,
            Colors.orange,
          ),
          const SizedBox(width: 8),
          _buildSummaryCard(
            'Total Amount',
            '₹${_totalAmount.toStringAsFixed(2)}',
            Icons.currency_rupee,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Purchase Report',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_filteredPurchases.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Report',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _isGeneratingPDF ? null : _generateAndSharePDF,
                  icon: _isGeneratingPDF
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.share,
                          color: Colors.white.withOpacity(0.8),
                          size: 20,
                        ),
                  tooltip: 'Generate & Share PDF Report',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          IconButton(
            onPressed: _loadPurchases,
            icon: Icon(
              Icons.refresh,
              color: Colors.white.withOpacity(0.8),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          if (!_isLoading && _filteredPurchases.isNotEmpty)
            _buildSummaryCards(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPurchases.isEmpty
                ? _buildEmptyState()
                : _buildPurchaseList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40, // Set fixed height for proper vertical centering
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _applyFilters();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search supplier, invoice...',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0, // Remove vertical padding
                        horizontal: 8,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.transparent,
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.0, // Ensures text is centered vertically
                    ),
                    textAlignVertical:
                        TextAlignVertical.center, // Center text vertically
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                height: 40, // Match height with search field
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    hint: const Text('Filter', style: TextStyle(fontSize: 11)),
                    items: _filterOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      if (value == 'Custom Range') {
                        _selectDateRange();
                      } else {
                        setState(() {
                          _selectedFilter = value;
                          _startDate = null;
                          _endDate = null;
                        });
                        _applyFilters();
                      }
                    },
                    icon: Icon(
                      Icons.filter_list,
                      color: Colors.green[700],
                      size: 18,
                    ),
                    dropdownColor: Colors.white,
                    style: TextStyle(fontSize: 11, color: Colors.green[800]),
                    underline: Container(),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center, // Center the dropdown content
                  ),
                ),
              ),
            ],
          ),
          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range, size: 12, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}',
                      style: TextStyle(fontSize: 10, color: Colors.blue[800]),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                          _selectedFilter = 'All';
                        });
                        _applyFilters();
                      },
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No purchases found',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your filters',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadPurchases,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseList() {
    return ListView.builder(
      padding: const EdgeInsets.all(6),
      itemCount: _filteredPurchases.length,
      itemBuilder: (context, index) {
        final purchase = _filteredPurchases[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showPurchaseDetails(purchase),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: Colors.green[700],
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                purchase['invoiceNo'],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                purchase['supplierName'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 10,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd/MM/yyyy').format(purchase['date']),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${purchase['itemCount']} items',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${purchase['grandTotal'].toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _deletePurchase(purchase),
                            icon: Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.red[700],
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Delete',
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
