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
  String _searchMode = 'All'; // 'All' | 'IMEI' | 'Product'

  String? _selectedFilter;
  DateTime? _startDate;
  DateTime? _endDate;

  // ✅ Shop-wise filter
  String? _selectedShopId; // null = all shops
  final Map<String, String> _shopIdToName = {}; // stockShopId -> stockShopName

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
    'This Year',
    'Last Year',
    'Custom Range',
  ];

  final List<String> _searchModes = ['All', 'IMEI', 'Product'];

  @override
  void initState() {
    super.initState();
    _selectedFilter = 'This Month';
    _loadPurchases();
  }

  bool _isDateInRange(DateTime date, DateTime startDate, DateTime? endDate) {
    if (endDate == null) {
      return date.isAfter(startDate) || date.isAtSameMomentAs(startDate);
    }
    return (date.isAfter(startDate) || date.isAtSameMomentAs(startDate)) &&
        (date.isBefore(endDate) || date.isAtSameMomentAs(endDate));
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);

    try {
      Query query = _firestore
          .collection('purchases')
          .orderBy('createdAt', descending: true);
      QuerySnapshot snapshot = await query.get();

      _purchases = [];
      _shopIdToName.clear();

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

        // Pre-compute searchable strings per item
        final imeiList = <String>[];
        final productNames = <String>[];
        for (final it in items) {
          final imeis = List<dynamic>.from(it['imeiOrSerialNumbers'] ?? []);
          for (final i in imeis) {
            final s = i.toString();
            if (s.isNotEmpty) imeiList.add(s);
          }
          final pn = (it['productName'] ?? '').toString();
          if (pn.isNotEmpty) productNames.add(pn);
        }

        final shopId = (data['stockShopId'] ?? '').toString();
        final shopName = (data['stockShopName'] ?? '').toString();

        if (shopId.isNotEmpty) {
          _shopIdToName.putIfAbsent(
            shopId,
            () => shopName.isEmpty ? shopId : shopName,
          );
        }

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
          'items': items,
          'itemCount': items.length,
          'taxableAmount': (data['totalAmount'] ?? 0).toDouble(),
          'taxPercentage': 18,
          'purchaseBillUrl': data['purchaseBillUrl'] ?? '',
          'stockShopId': shopId,
          'stockShopName': shopName,
          'imeiSearchStr': imeiList.join('|').toLowerCase(),
          'productSearchStr': productNames.join('|').toLowerCase(),
        });
      }

      _applyFilters();
    } catch (e) {
      if (!mounted) return;
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_purchases);

    // Date filter
    if (_selectedFilter != null && _selectedFilter != 'All') {
      DateTime now = DateTime.now();
      DateTime startDate;
      DateTime? endDate;

      switch (_selectedFilter) {
        case 'Last 7 Days':
          startDate = now.subtract(const Duration(days: 7));
          filtered = filtered
              .where((p) => _isDateInRange(p['date'], startDate, null))
              .toList();
          break;
        case 'Last 30 Days':
          startDate = now.subtract(const Duration(days: 30));
          filtered = filtered
              .where((p) => _isDateInRange(p['date'], startDate, null))
              .toList();
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          filtered = filtered
              .where((p) => _isDateInRange(p['date'], startDate, null))
              .toList();
          break;
        case 'Last Month':
          startDate = DateTime(now.year, now.month - 1, 1);
          endDate = DateTime(now.year, now.month, 0);
          filtered = filtered
              .where((p) => _isDateInRange(p['date'], startDate, endDate))
              .toList();
          break;
        case 'This Year':
          startDate = DateTime(now.year, 1, 1);
          filtered = filtered
              .where((p) => _isDateInRange(p['date'], startDate, null))
              .toList();
          break;
        case 'Last Year':
          startDate = DateTime(now.year - 1, 1, 1);
          endDate = DateTime(now.year, 1, 1);
          filtered = filtered
              .where((p) => _isDateInRange(p['date'], startDate, endDate))
              .toList();
          break;
        case 'Custom Range':
          if (_startDate != null && _endDate != null) {
            final endOfDay = DateTime(
              _endDate!.year,
              _endDate!.month,
              _endDate!.day,
              23,
              59,
              59,
            );
            filtered = filtered
                .where((p) => _isDateInRange(p['date'], _startDate!, endOfDay))
                .toList();
          }
          break;
      }
    }

    // ✅ Shop filter
    if (_selectedShopId != null && _selectedShopId!.isNotEmpty) {
      filtered = filtered
          .where((p) => p['stockShopId'] == _selectedShopId)
          .toList();
    }

    // ✅ Text search — All / IMEI / Product
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((p) {
        final supplier = (p['supplierName'] ?? '').toString().toLowerCase();
        final invoice = (p['invoiceNo'] ?? '').toString().toLowerCase();
        final imeis = (p['imeiSearchStr'] ?? '').toString();
        final products = (p['productSearchStr'] ?? '').toString();

        switch (_searchMode) {
          case 'IMEI':
            return imeis.contains(q) || invoice.contains(q);
          case 'Product':
            return products.contains(q) || supplier.contains(q);
          case 'All':
          default:
            return supplier.contains(q) ||
                invoice.contains(q) ||
                imeis.contains(q) ||
                products.contains(q);
        }
      }).toList();
    }

    _calculateSummary(filtered);

    setState(() => _filteredPurchases = filtered);
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
      List<Map<String, dynamic>> sortedPurchases = List.from(
        _filteredPurchases,
      );
      sortedPurchases.sort((a, b) => a['date'].compareTo(b['date']));

      double totalTaxable = 0;
      double totalTax = 0;
      double totalRounding = 0;
      double totalBillAmount = 0;

      for (var purchase in sortedPurchases) {
        totalTaxable += purchase['taxableAmount'] ?? 0;
        totalTax += purchase['gstAmount'] ?? 0;
        totalRounding += purchase['roundingAmount'] ?? 0;
        totalBillAmount += purchase['grandTotal'] ?? 0;
      }

      final calculatedTotal = totalTaxable + totalTax + totalRounding;
      if ((calculatedTotal - totalBillAmount).abs() > 0.01) {
        totalRounding = totalBillAmount - totalTaxable - totalTax;
      }

      final pdf = pw.Document();

      final shopLabel = _selectedShopId != null
          ? 'Shop: ${_shopIdToName[_selectedShopId] ?? _selectedShopId}'
          : 'All Shops';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
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
                    pw.Text(shopLabel, style: const pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Period: ${_getFilterDisplayText()}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(thickness: 1),
                    pw.SizedBox(height: 10),
                  ],
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(0.13),
                  1: pw.FlexColumnWidth(0.15),
                  2: pw.FlexColumnWidth(0.20),
                  3: pw.FlexColumnWidth(0.13),
                  4: pw.FlexColumnWidth(0.11),
                  5: pw.FlexColumnWidth(0.09),
                  6: pw.FlexColumnWidth(0.09),
                  7: pw.FlexColumnWidth(0.10),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _pdfHeaderCell('Inv Date'),
                      _pdfHeaderCell('Bill No'),
                      _pdfHeaderCell('Seller Name'),
                      _pdfHeaderCell('Taxable', align: pw.TextAlign.right),
                      _pdfHeaderCell('Tax', align: pw.TextAlign.right),
                      _pdfHeaderCell('Cess', align: pw.TextAlign.right),
                      _pdfHeaderCell('Rounding', align: pw.TextAlign.right),
                      _pdfHeaderCell('Bill Amt', align: pw.TextAlign.right),
                    ],
                  ),
                  ...sortedPurchases.map((purchase) {
                    return pw.TableRow(
                      children: [
                        _pdfDataCell(
                          DateFormat('dd/MM/yy').format(purchase['date']),
                          align: pw.TextAlign.center,
                        ),
                        _pdfDataCell(
                          purchase['invoiceNo'] ?? 'N/A',
                          align: pw.TextAlign.center,
                        ),
                        _pdfDataCell(
                          purchase['supplierName'] ?? 'Unknown',
                          align: pw.TextAlign.left,
                        ),
                        _pdfDataCell(
                          (purchase['taxableAmount'] ?? 0).toStringAsFixed(2),
                          align: pw.TextAlign.right,
                        ),
                        _pdfDataCell(
                          (purchase['gstAmount'] ?? 0).toStringAsFixed(2),
                          align: pw.TextAlign.right,
                        ),
                        _pdfDataCell('0.00', align: pw.TextAlign.right),
                        _pdfDataCell(
                          (purchase['roundingAmount'] ?? 0).toStringAsFixed(2),
                          align: pw.TextAlign.right,
                        ),
                        _pdfDataCell(
                          (purchase['grandTotal'] ?? 0).toStringAsFixed(2),
                          align: pw.TextAlign.right,
                          bold: true,
                        ),
                      ],
                    );
                  }).toList(),
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfHeaderCell('TOTAL'),
                      _pdfDataCell('', align: pw.TextAlign.center),
                      _pdfDataCell('', align: pw.TextAlign.center),
                      _pdfDataCell(
                        totalTaxable.toStringAsFixed(2),
                        align: pw.TextAlign.right,
                        bold: true,
                        color: PdfColors.blue,
                      ),
                      _pdfDataCell(
                        totalTax.toStringAsFixed(2),
                        align: pw.TextAlign.right,
                        bold: true,
                        color: PdfColors.blue,
                      ),
                      _pdfDataCell(
                        '0.00',
                        align: pw.TextAlign.right,
                        bold: true,
                        color: PdfColors.blue,
                      ),
                      _pdfDataCell(
                        totalRounding.toStringAsFixed(2),
                        align: pw.TextAlign.right,
                        bold: true,
                        color: PdfColors.blue,
                      ),
                      _pdfDataCell(
                        totalBillAmount.toStringAsFixed(2),
                        align: pw.TextAlign.right,
                        bold: true,
                        color: PdfColors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final fileName =
          'purchase_report_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Purchase Report - MOBILE HOUSE\n'
            '$shopLabel\n'
            'Period: ${_getFilterDisplayText()}\n'
            'Total Bills: ${_filteredPurchases.length}\n'
            'Total Products: $_totalProducts\n'
            'Total Taxable: ${totalTaxable.toStringAsFixed(2)}\n'
            'Total Tax: ${totalTax.toStringAsFixed(2)}\n'
            'Total Rounding: ${totalRounding.toStringAsFixed(2)}\n'
            'Grand Total: ${totalBillAmount.toStringAsFixed(2)}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generated and shared successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPDF = false);
    }
  }

  // ================= PURCHASE BILL =================

  Widget _buildPurchaseBillSection(Map<String, dynamic> purchase) {
    final imageUrl = (purchase['purchaseBillUrl'] ?? '').toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt, size: 14, color: Colors.green[800]),
              const SizedBox(width: 6),
              Text(
                'Uploaded Purchase Bill',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (imageUrl.isEmpty)
            Container(
              height: 90,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.grey[500],
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No bill image uploaded',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 180,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    height: 180,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes == null
                            ? null
                            : progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  width: double.infinity,
                  color: Colors.grey[100],
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey[500],
                        size: 30,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Unable to load bill image',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewPurchaseBill(imageUrl),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text(
                      'View Image',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[700],
                      side: BorderSide(color: Colors.green[700]!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _downloadPurchaseBill(imageUrl),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text(
                      'Download',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _viewPurchaseBill(String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text(
                        'Unable to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _downloadPurchaseBill(imageUrl),
                    icon: const Icon(Icons.download, color: Colors.white),
                    tooltip: 'Download',
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadPurchaseBill(String imageUrl) async {
    if (imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bill image available to download')),
      );
      return;
    }

    HttpClient? client;
    try {
      final uri = Uri.parse(imageUrl);
      if (uri.scheme != 'https' && uri.scheme != 'http') {
        throw const FormatException('Invalid image URL');
      }

      client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Download failed (${response.statusCode})');
      }
      final bytes = await response.fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      );

      Directory dir;
      if (Platform.isAndroid) {
        final dl = Directory('/storage/emulated/0/Download');
        dir = await dl.exists() ? dl : await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      if (!await dir.exists()) await dir.create(recursive: true);

      var extension = uri.path.toLowerCase().split('.').last;
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        extension = 'jpg';
      }
      final invoice = 'report';
      final file = File(
        '${dir.path}${Platform.pathSeparator}'
        'Purchase_Bill_${invoice}_${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: ${file.path}'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFile.open(file.path),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      client?.close(force: true);
    }
  }

  pw.Widget _pdfHeaderCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        textAlign: align,
      ),
    );
  }

  pw.Widget _pdfDataCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
        textAlign: align,
      ),
    );
  }

  String _getFilterDisplayText() {
    if (_selectedFilter == 'Custom Range' &&
        _startDate != null &&
        _endDate != null) {
      return '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}';
    } else if (_selectedFilter == 'This Year') {
      return 'January ${DateTime.now().year} - December ${DateTime.now().year}';
    } else if (_selectedFilter == 'Last Year') {
      return 'January ${DateTime.now().year - 1} - December ${DateTime.now().year - 1}';
    } else if (_selectedFilter == 'This Month') {
      return DateFormat('MMMM yyyy').format(DateTime.now());
    } else if (_selectedFilter == 'Last Month') {
      DateTime lastMonth = DateTime(
        DateTime.now().year,
        DateTime.now().month - 1,
      );
      return DateFormat('MMMM yyyy').format(lastMonth);
    } else if (_selectedFilter == 'Last 7 Days') {
      return 'Last 7 Days';
    } else if (_selectedFilter == 'Last 30 Days') {
      return 'Last 30 Days';
    }
    return 'All Time';
  }

  Future<void> _deletePurchase(Map<String, dynamic> purchase) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 22),
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
                    'Amount: ${purchase['grandTotal'].toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  Text(
                    'Added: ${DateFormat('dd/MM/yyyy HH:mm').format(purchase['createdAt'])}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  Text(
                    'Invoice Date: ${DateFormat('dd/MM/yyyy').format(purchase['date'])}',
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
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
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
      ),
    );

    if (confirmDelete == true) {
      setState(() => _isLoading = true);
      try {
        await _firestore.collection('purchases').doc(purchase['id']).delete();
        setState(() {
          _purchases.removeWhere((p) => p['id'] == purchase['id']);
          _filteredPurchases.removeWhere((p) => p['id'] == purchase['id']);
        });
        _calculateSummary(_filteredPurchases);
        if (!mounted) return;
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting purchase: $e',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
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
        initialChildSize: 0.85,
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
                      _buildShopInfoSection(purchase),
                      const SizedBox(height: 10),
                      _buildSupplierInfoSection(purchase),
                      const SizedBox(height: 10),
                      _buildPurchaseBillSection(
                        purchase,
                      ), // ✅ bill image view/download
                      const SizedBox(height: 10),
                      _buildItemsSection(purchase),
                      const SizedBox(height: 10),
                      _buildSummarySection(purchase),
                      const SizedBox(height: 16),
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

  // ✅ NEW: Shop info in details view
  Widget _buildShopInfoSection(Map<String, dynamic> purchase) {
    final shopId = (purchase['stockShopId'] ?? '').toString();
    final shopName = (purchase['stockShopName'] ?? '').toString();

    if (shopId.isEmpty && shopName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront, size: 14, color: Colors.blue[800]),
              const SizedBox(width: 6),
              Text(
                'Shop Information',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (shopName.isNotEmpty) _buildDetailRow('Shop Name', shopName),
          if (shopId.isNotEmpty) _buildDetailRow('Shop ID', shopId),
        ],
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
              'Invoice Date',
              DateFormat('dd/MM/yyyy').format(purchase['date']),
            ),
            _buildDetailRow(
              'Added Date & Time',
              DateFormat('dd/MM/yyyy hh:mm a').format(purchase['createdAt']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(Map<String, dynamic> purchase) {
    final items = List<Map<String, dynamic>>.from(purchase['items'] ?? []);

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
            ...items.map<Widget>((item) {
              final imeis =
                  List<dynamic>.from(item['imeiOrSerialNumbers'] ?? [])
                      .map((e) => e.toString().trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['productName'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${(item['total'] ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      children: [
                        if ((item['brand'] ?? '').toString().isNotEmpty)
                          Text(
                            'Brand: ${item['brand']}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                            ),
                          ),
                        Text(
                          'Qty: ${item['quantity'] ?? 1}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (item['rate'] != null)
                          Text(
                            'Rate: ${(item['rate'] as num).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                            ),
                          ),
                      ],
                    ),
                    if (imeis.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.qr_code_2,
                                  size: 12,
                                  color: Colors.blue[800],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item['identifierType']?.toString() ??
                                      'IMEI / Serial',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${imeis.length})',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            ...imeis.map(
                              (imei) => Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.blue[700],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: SelectableText(
                                        imei,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontFamily: 'monospace',
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
            value.toStringAsFixed(2),
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

  // Summary Card Widget
  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[700]!, Colors.green[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green[700]!.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total Bills
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: Colors.white.withOpacity(0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Total Bills',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_totalBills',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Total Products
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart,
                        color: Colors.white.withOpacity(0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Products',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_totalProducts',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Total Amount
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.attach_money,
                        color: Colors.white.withOpacity(0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
          // Summary Card
          if (!_isLoading && _filteredPurchases.isNotEmpty) _buildSummaryCard(),
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
                  height: 40,
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
                        vertical: 0,
                        horizontal: 8,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.transparent,
                    ),
                    style: const TextStyle(fontSize: 11, height: 1.0),
                    textAlignVertical: TextAlignVertical.center,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                height: 40,
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
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[800],
                      fontWeight: _selectedFilter != 'All'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    underline: Container(),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                  ),
                ),
              ),
            ],
          ),
          // Show active filter indicator
          if (_selectedFilter != null && _selectedFilter != 'All')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.filter_alt, size: 12, color: Colors.green[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Filter: $_selectedFilter',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_startDate != null && _endDate != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)})',
                      style: TextStyle(fontSize: 9, color: Colors.green[600]),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${_filteredPurchases.length} records',
                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                  ),
                ],
              ),
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
                              'Added: ${DateFormat('dd/MM/yy').format(purchase['createdAt'])}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Inv: ${DateFormat('dd/MM/yy').format(purchase['date'])}',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
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
                        purchase['grandTotal'].toStringAsFixed(2),
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
