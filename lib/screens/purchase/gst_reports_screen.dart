// gst_reports_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sales_stock/services/firestore_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_file/open_file.dart';

class GSTReportsScreen extends StatefulWidget {
  const GSTReportsScreen({Key? key}) : super(key: key);

  @override
  State<GSTReportsScreen> createState() => _GSTReportsScreenState();
}

class _GSTReportsScreenState extends State<GSTReportsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Color _primaryGreen = const Color(0xFF2E7D32);
  final Color _lightGreen = const Color(0xFF4CAF50);
  final Color _backgroundColor = const Color(0xFFF5F9F5);

  DateTime _selectedStartDate = DateTime.now().subtract(
    const Duration(days: 30),
  );
  DateTime _selectedEndDate = DateTime.now();
  bool _isLoading = false;
  bool _isExporting = false;
  List<Map<String, dynamic>> _gstReports = [];
  double _totalPurchase = 0;
  double _totalGST = 0;

  @override
  void initState() {
    super.initState();
    _fetchGSTReports();
  }

  Future<void> _fetchGSTReports() async {
    setState(() => _isLoading = true);

    try {
      final purchases = await _firestoreService.getPurchasesByDateRange(
        _selectedStartDate,
        _selectedEndDate,
      );

      double totalPurchase = 0;
      double totalGST = 0;
      final List<Map<String, dynamic>> reports = [];

      for (var purchase in purchases) {
        final subtotal = _parseDouble(purchase['subtotal']) ?? 0.0;
        final gstAmount = _parseDouble(purchase['gstAmount']) ?? 0.0;
        final totalAmount = _parseDouble(purchase['totalAmount']) ?? 0.0;
        final invoiceNo = purchase['invoiceNumber']?.toString() ?? 'N/A';
        final supplierName = purchase['supplierName']?.toString() ?? 'Unknown';
        final gstNumber = purchase['supplierGST']?.toString() ?? 'N/A';
        final purchaseDate = purchase['purchaseDate'];

        String formattedDate = 'N/A';
        if (purchaseDate is Timestamp) {
          formattedDate = DateFormat(
            'dd/MM/yyyy', // Changed from 'dd-MMM-yyyy' to 'dd/MM/yyyy'
          ).format(purchaseDate.toDate());
        } else if (purchaseDate is DateTime) {
          formattedDate = DateFormat(
            'dd/MM/yyyy',
          ).format(purchaseDate); // Changed here
        }

        totalPurchase += totalAmount;
        totalGST += gstAmount;

        reports.add({
          'date': formattedDate,
          'invoiceNo': invoiceNo,
          'supplierName': supplierName,
          'gstNumber': gstNumber,
          'subtotal': subtotal,
          'gstAmount': gstAmount,
          'totalAmount': totalAmount,
          'purchaseDate': purchaseDate,
        });
      }

      setState(() {
        _gstReports = reports;
        _totalPurchase = totalPurchase;
        _totalGST = totalGST;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching GST reports: $e');
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load GST reports: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedStartDate) {
      setState(() => _selectedStartDate = picked);
      _fetchGSTReports();
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedEndDate) {
      setState(() => _selectedEndDate = picked);
      _fetchGSTReports();
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }

  String formatDateManual(dynamic dateValue) {
    print(dateValue);
    // Convert to string first
    final dateString = dateValue?.toString()?.trim() ?? '';

    if (dateString == 'N/A' || dateString.isEmpty || dateString == 'null') {
      return 'N/A';
    }

    try {
      final parts = dateString.split('/');
      if (parts.length != 3) return dateString;

      // Expanded month map with more variations
      const monthMap = {
        // Standard 3-letter abbreviations
        'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
        'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
        'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',

        // Sometimes with period
        'jan.': '01', 'feb.': '02', 'mar.': '03', 'apr.': '04',
        'may.': '05', 'jun.': '06', 'jul.': '07', 'aug.': '08',
        'sep.': '09', 'oct.': '10', 'nov.': '11', 'dec.': '12',

        // Full month names
        'january': '01', 'february': '02', 'march': '03', 'april': '04',
        'june': '06', 'july': '07', 'august': '08', 'september': '09',
        'october': '10', 'november': '11', 'december': '12',
      };

      final day = parts[0].padLeft(2, '0');
      final monthAbbr = parts[1].toLowerCase().trim();
      final year = parts[2].trim();

      // Check if month is already a number (01-12)
      if (RegExp(r'^\d{1,2}$').hasMatch(monthAbbr)) {
        final monthNum = int.tryParse(monthAbbr);
        if (monthNum != null && monthNum >= 1 && monthNum <= 12) {
          return '$day/${monthAbbr.padLeft(2, '0')}/$year';
        }
      }

      // Look up month abbreviation
      final monthNumber = monthMap[monthAbbr];

      if (monthNumber == null) {
        // Try removing any trailing period
        final monthAbbrNoPeriod = monthAbbr.replaceAll(RegExp(r'\.$'), '');
        final monthNumber2 = monthMap[monthAbbrNoPeriod];

        if (monthNumber2 != null) {
          return '$day/$monthNumber2/$year';
        }

        // Return original if month not found
        return dateString;
      }

      return '$day/$monthNumber/$year';
    } catch (e) {
      return dateString;
    }
  }

  Future<Uint8List> _generatePDF() async {
    final pdf = pw.Document();

    // Use built-in font to avoid loading issues
    final textStyle = pw.TextStyle(fontSize: 10);
    final headerStyle = pw.TextStyle(
      fontSize: 24,
      fontWeight: pw.FontWeight.bold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('MOBILE HOUSE', style: headerStyle),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Period: ${DateFormat('dd/MM/yyyy').format(_selectedStartDate)} - ${DateFormat('dd/MM/yyyy').format(_selectedEndDate)}', // Changed here
                  style: textStyle,
                ),

                pw.Divider(thickness: 1),
                pw.SizedBox(height: 20),
              ],
            ),

            // GST Reports Table
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey.shade(300)),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.black,
              ),
              // headerDecoration: pw.BoxDecoration(color: PdfColors.green),
              headers: [
                'Date',
                'Invoice No',
                'Supplier',
                'GST',
                'Amount',
                'GST',
                'Total',
              ],
              data: _gstReports.map((report) {
                return [
                  report['date'] != null && report['date'].toString().isNotEmpty
                      ? formatDateManual(report['date'].toString())
                      : 'N/A',
                  report['invoiceNo'] ?? 'N/A',
                  report['supplierName'] ?? 'Unknown',
                  report['18%'] ?? '18%',
                  ' ${_formatCurrency(report['subtotal'] as double)}',
                  ' ${_formatCurrency(report['gstAmount'] as double)}',
                  ' ${_formatCurrency(report['totalAmount'] as double)}',
                ];
              }).toList(),
              cellStyle: textStyle,
              cellPadding: pw.EdgeInsets.all(8),
            ),

            pw.SizedBox(height: 30),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey.shade(300)),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Summary',
                    style: textStyle.copyWith(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Purchase Amount:', style: textStyle),
                      pw.Text(
                        ' ${_formatCurrency(_totalPurchase)}',
                        style: textStyle.copyWith(
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total GST Amount:', style: textStyle),
                      pw.Text(
                        ' ${_formatCurrency(_totalGST)}',
                        style: textStyle.copyWith(
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Net Amount:', style: textStyle),
                      pw.Text(
                        ' ${_formatCurrency(_totalPurchase - _totalGST)}',
                        style: textStyle.copyWith(
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfStatCard(
    String title,
    String value,
    PdfColor color, {
    required pw.TextStyle textStyle,
  }) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color.shade(50),
        border: pw.Border.all(color: color.shade(200), width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            value,
            style: textStyle.copyWith(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: textStyle.copyWith(fontSize: 10, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _savePDF() async {
    if (_gstReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      // Check and request storage permission for Android
      if (Platform.isAndroid) {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }

        // Also request manage external storage for Android 11+
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }
      }

      // Generate PDF
      final pdfBytes = await _generatePDF();

      // Get directory - use getExternalStorageDirectory for better visibility
      Directory directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory =
              await getExternalStorageDirectory() ??
              await getTemporaryDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory =
            await getDownloadsDirectory() ?? await getTemporaryDirectory();
      }

      final fileName =
          'GST_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final filePath = '${directory.path}/$fileName';

      // Save file
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);

      // Open the file after saving
      if (await file.exists()) {
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved successfully to Downloads folder'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('File not found after saving');
      }
    } catch (e) {
      print('Error saving PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('GST Reports', style: TextStyle(color: Colors.white)),
        backgroundColor: _primaryGreen,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Date Range Selector
          Container(
            padding: const EdgeInsets.all(12),
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
            child: Column(
              children: [
                Text(
                  'Select Date Range',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectStartDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _backgroundColor,
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
                                    'From',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'dd/MM/yyyy', // Changed from 'dd-MMM-yyyy' to 'dd/MM/yyyy'
                                    ).format(_selectedStartDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: _primaryGreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 14, color: _primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectEndDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _backgroundColor,
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
                                    'To',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'dd/MM/yyyy', // Changed from 'dd-MMM-yyyy' to 'dd/MM/yyyy'
                                    ).format(_selectedEndDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: _primaryGreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.refresh, size: 14),
                        label: Text('Refresh', style: TextStyle(fontSize: 12)),
                        onPressed: _fetchGSTReports,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _isExporting
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.picture_as_pdf, size: 14),
                        label: Text(
                          _isExporting ? 'Saving...' : 'Save PDF',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: _isExporting ? null : _savePDF,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Summary Cards
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                _buildSummaryCard(
                  'Total Purchase',
                  ' ${_formatCurrency(_totalPurchase)}',
                  Colors.blue.shade700,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  'Total GST',
                  ' ${_formatCurrency(_totalGST)}',
                  _lightGreen,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  'Count',
                  '${_gstReports.length}',
                  Colors.orange.shade700,
                ),
              ],
            ),
          ),

          // Reports List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryGreen))
                : _gstReports.isEmpty
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
                          'No GST Data Found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No purchases with GST found in the selected date range',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _gstReports.length,
                    itemBuilder: (context, index) {
                      final report = _gstReports[index];
                      return _buildReportItem(report);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportItem(Map<String, dynamic> report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _lightGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.receipt, size: 20, color: _lightGreen),
        ),
        title: Text(
          report['invoiceNo'] ?? 'N/A',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              report['supplierName'] ?? 'Unknown',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  'Date: ${report['date']}', // This will now show 03/01/2026 instead of 03/JAN/2026
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 12),
                Text(
                  'GST: ${report['gstNumber']}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              ' ${_formatCurrency(report['totalAmount'] as double)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'GST:  ${_formatCurrency(report['gstAmount'] as double)}',
              style: TextStyle(
                fontSize: 11,
                color: _lightGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
