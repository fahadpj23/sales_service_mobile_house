// lib/screens/admin/reports/bills_report_pdf.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BillsReportPDF {
  final Function(double) formatNumber;

  BillsReportPDF({required this.formatNumber});

  // Shortcut method to format numbers without commas and symbols
  String _fmt(num value) {
    if (value == null) return '0';
    if (value is double) {
      if (value == value.toInt()) {
        return value.toInt().toString();
      }
      return value.toStringAsFixed(2);
    }
    return value.toString();
  }

  Future<void> generateAndShareSalesReport({
    required BuildContext context,
    required List<Map<String, dynamic>> phoneBills,
    required List<Map<String, dynamic>> accessoriesBills,
    required List<Map<String, dynamic>> tvBills,
    required String periodLabel,
    required String periodDateRange,
    required String shopName,
    required bool isLoading,
    required Function(bool) setLoading,
  }) async {
    if (phoneBills.isEmpty && accessoriesBills.isEmpty && tvBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No bills available to generate report'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setLoading(true);

    try {
      final pdf = pw.Document();

      // Combine all bills
      final allBills = [...phoneBills, ...accessoriesBills, ...tvBills];

      // Calculate totals
      final totalTaxable = allBills.fold(0.0, (sum, bill) {
        return sum + ((bill['taxableAmount'] as num?)?.toDouble() ?? 0.0);
      });
      final totalGst = allBills.fold(0.0, (sum, bill) {
        return sum + ((bill['gstAmount'] as num?)?.toDouble() ?? 0.0);
      });
      final totalCgst = totalGst / 2;
      final totalSgst = totalGst / 2;
      final totalAmount = allBills.fold(0.0, (sum, bill) {
        return sum + ((bill['totalAmount'] as num?)?.toDouble() ?? 0.0);
      });

      // Sort bills by date
      allBills.sort((a, b) {
        final dateA = _getBillDate(a);
        final dateB = _getBillDate(b);
        return dateA.compareTo(dateB);
      });

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Header
              _buildHeader(periodLabel, periodDateRange, shopName),
              pw.SizedBox(height: 12),
              _buildSalesTable(allBills),
              pw.SizedBox(height: 12),
              _buildFooter(
                totalTaxable,
                totalGst,
                totalCgst,
                totalSgst,
                totalAmount,
              ),
            ];
          },
        ),
      );

      // Save PDF
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final fileName =
          'sales_report_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Share the PDF
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Sales Report - MOBILE HOUSE\n'
            'Period: $periodDateRange\n'
            'Total Bills: ${allBills.length}\n'
            'Total Sales: ${_fmt(totalAmount)}\n'
            'Total Taxable: ${_fmt(totalTaxable)}\n'
            'Total GST: ${_fmt(totalGst)}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sales report generated and shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error generating PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating sales report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setLoading(false);
    }
  }

  pw.Widget _buildHeader(
    String periodLabel,
    String periodDateRange,
    String shopName,
  ) {
    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'MOBILE HOUSE',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Sales Report',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          // Date in a row with label
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Date: ',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.Text(
                periodDateRange,
                style: pw.TextStyle(fontSize: 11, color: PdfColors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSalesTable(List<Map<String, dynamic>> bills) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: pw.FlexColumnWidth(0.10), // Date
        1: pw.FlexColumnWidth(0.12), // Bill No
        2: pw.FlexColumnWidth(0.18), // Customer Name
        3: pw.FlexColumnWidth(0.14), // Taxable
        4: pw.FlexColumnWidth(0.10), // Tax (18%)
        5: pw.FlexColumnWidth(0.10), // CGST
        6: pw.FlexColumnWidth(0.10), // SGST
        7: pw.FlexColumnWidth(0.16), // Total Amount
      },
      children: [
        // Table Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey800),
          children: [
            _buildHeaderCell('Date'),
            _buildHeaderCell('Bill No'),
            _buildHeaderCell('Customer'),
            _buildHeaderCell('Taxable'),
            _buildHeaderCell('Tax (18%)'),
            _buildHeaderCell('CGST'),
            _buildHeaderCell('SGST'),
            _buildHeaderCell('Total'),
          ],
        ),
        // Table Rows
        ...bills.map((bill) {
          final date = _getBillDate(bill);
          final taxable = (bill['taxableAmount'] as num?)?.toDouble() ?? 0.0;
          final gst = (bill['gstAmount'] as num?)?.toDouble() ?? 0.0;
          final cgst = gst / 2;
          final sgst = gst / 2;
          final total = (bill['totalAmount'] as num?)?.toDouble() ?? 0.0;
          // Tax amount at 18%
          final taxAmount = (taxable * 0.18);

          return pw.TableRow(
            children: [
              _buildDataCell(
                DateFormat('dd/MM/yy').format(date),
                textAlign: pw.TextAlign.center,
              ),
              _buildDataCell(
                bill['billNumber'] ?? 'N/A',
                textAlign: pw.TextAlign.center,
              ),
              _buildDataCell(
                bill['customerName'] ?? 'N/A',
                textAlign: pw.TextAlign.left,
              ),
              _buildDataCell(_fmt(taxable), textAlign: pw.TextAlign.right),
              _buildDataCell(_fmt(taxAmount), textAlign: pw.TextAlign.right),
              _buildDataCell(_fmt(cgst), textAlign: pw.TextAlign.right),
              _buildDataCell(_fmt(sgst), textAlign: pw.TextAlign.right),
              _buildDataCell(
                _fmt(total),
                textAlign: pw.TextAlign.right,
                isBold: true,
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildDataCell(
    String text, {
    pw.TextAlign textAlign = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
        textAlign: textAlign,
      ),
    );
  }

  pw.Widget _buildFooter(
    double totalTaxable,
    double totalGst,
    double totalCgst,
    double totalSgst,
    double totalAmount,
  ) {
    // Calculate total tax at 18%
    final totalTax = totalTaxable * 0.18;

    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          _buildFooterItem('Total Taxable', _fmt(totalTaxable)),
          _buildFooterItem('Total Tax (18%)', _fmt(totalTax)),
          _buildFooterItem('Total GST', _fmt(totalGst)),
          _buildFooterItem('Grand Total', _fmt(totalAmount), isTotal: true),
        ],
      ),
    );
  }

  pw.Widget _buildFooterItem(
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.black,
            fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: isTotal ? 14 : 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  DateTime _getBillDate(Map<String, dynamic> bill) {
    if (bill['billDate'] is Timestamp) {
      return (bill['billDate'] as Timestamp).toDate();
    } else if (bill['createdAt'] is Timestamp) {
      return (bill['createdAt'] as Timestamp).toDate();
    }
    return DateTime.now();
  }
}
