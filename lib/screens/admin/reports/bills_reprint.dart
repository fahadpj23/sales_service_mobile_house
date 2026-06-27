// lib/screens/admin/reports/bills_report_print.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';

class BillRePrint {
  Uint8List? logoImage;
  Uint8List? sealImage;

  BillRePrint({this.logoImage, this.sealImage});

  Future<void> printAndShareBill({
    required BuildContext context,
    required Map<String, dynamic> bill,
    required void Function(void Function()) setState,
  }) async {
    try {
      setState(() {
        // Show loading
      });

      final pdfBytes = await _generateBillPdf(bill);
      final filePath = await _savePdfToStorage(pdfBytes, bill);
      final pdfFile = File(filePath);

      setState(() {
        // Hide loading
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Bill Actions'),
          content: Text('What would you like to do with the bill?'),
          actions: [
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _sharePdf(pdfFile);
              },
              icon: Icon(Icons.share, color: Colors.blue),
              label: Text('Share'),
            ),
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _printPdf(pdfFile);
              },
              icon: Icon(Icons.print, color: Colors.green),
              label: Text('Print'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Uint8List> _generateBillPdf(Map<String, dynamic> bill) async {
    final pdf = pw.Document();
    final pageFormat = PdfPageFormat.a4;
    String currentDate = DateFormat('dd MMMM yyyy').format(DateTime.now());

    final billNumber = bill['billNumber'] ?? 'N/A';
    final customerName = bill['customerName'] ?? 'N/A';
    final customerMobile = bill['customerMobile'] ?? 'N/A';
    final customerAddress = bill['customerAddress'] ?? 'N/A';
    final totalAmount = (bill['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final taxableAmount = (bill['taxableAmount'] as num?)?.toDouble() ?? 0.0;
    final gstAmount = (bill['gstAmount'] as num?)?.toDouble() ?? 0.0;
    final shop = bill['shop'] ?? 'Peringottukara';
    final purchaseMode = bill['purchaseMode'] ?? 'Ready Cash';
    final financeType = bill['financeType'];
    final sealApplied = bill['sealApplied'] == true;

    // Get product details based on type
    String productName = bill['productName'] ?? '';
    String identifier = '';
    String identifierLabel = '';

    final billType = bill['billType'] as String?;
    final type = bill['type'] as String?;

    if (billType == 'GST Accessories') {
      productName = bill['productName'] ?? '';
      identifier = bill['imei'] ?? '';
      identifierLabel = 'IMEI';
    } else if (type == 'tv') {
      productName = bill['modelName'] ?? bill['productName'] ?? '';
      identifier = bill['serialNumber'] ?? '';
      identifierLabel = 'Serial No';
      final originalTvData = bill['originalTvData'];
      if (originalTvData != null && originalTvData is Map<String, dynamic>) {
        if (productName.isEmpty)
          productName = originalTvData['modelName'] ?? '';
        if (identifier.isEmpty)
          identifier = originalTvData['serialNumber'] ?? '';
      }
    } else {
      productName = bill['productName'] ?? '';
      identifier = bill['imei'] ?? '';
      identifierLabel = 'IMEI';
      final originalPhoneData = bill['originalPhoneData'];
      if (originalPhoneData != null &&
          originalPhoneData is Map<String, dynamic>) {
        if (productName.isEmpty)
          productName = originalPhoneData['productName'] ?? '';
        if (identifier.isEmpty) identifier = originalPhoneData['imei'] ?? '';
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(15),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.0),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfHeader(currentDate, billNumber, shop),
                _buildPdfCustomerDetails(
                  customerName,
                  customerMobile,
                  customerAddress,
                  purchaseMode,
                  financeType,
                ),
                pw.SizedBox(height: 4),
                _buildPdfMainTable(
                  productName,
                  identifier,
                  identifierLabel,
                  taxableAmount,
                  gstAmount,
                  totalAmount,
                ),
                pw.Container(
                  height: 280,
                  child: pw.Stack(
                    children: [
                      if (sealApplied && sealImage != null)
                        pw.Positioned(
                          right: 15,
                          bottom: 18,
                          child: pw.Transform.rotate(
                            angle: 25 * 3.14159 / 180,
                            child: pw.SizedBox(
                              width: 150,
                              height: 150,
                              child: pw.Image(
                                pw.MemoryImage(sealImage!),
                                fit: pw.BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildPdfTotalSection(totalAmount, taxableAmount, gstAmount),
                _buildPdfBottomSection(),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfHeader(
    String currentDate,
    String billNumber,
    String shop,
  ) {
    return pw.Column(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              'GSTIN: 32BSGPJ3340H1Z4',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Column(
                children: [
                  if (logoImage != null)
                    pw.SizedBox(
                      height: 45,
                      child: pw.Image(
                        pw.MemoryImage(logoImage!),
                        fit: pw.BoxFit.contain,
                      ),
                    )
                  else
                    pw.Text(
                      'MOBILE HOUSE',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    shop == 'Peringottukara'
                        ? "3way junction Peringottukara"
                        : "Cherpu, Thayamkulangara",
                    style: pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    shop == 'Peringottukara'
                        ? "Mob: 9072430483, 8304830868"
                        : "Mob: 9544466724",
                    style: pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text("Mobile house", style: pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    "GST TAX INVOICE (TYPE-B2C) - CASH SALE",
                    style: pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'STATE : KERALA',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Invoice No. : $billNumber',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'STATE CODE : 32',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Invoice Date : $currentDate',
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
        pw.Divider(color: PdfColors.black, thickness: 0.2, height: 0),
      ],
    );
  }

  pw.Widget _buildPdfCustomerDetails(
    String name,
    String mobile,
    String address,
    String purchaseMode,
    String? financeType,
  ) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: pw.Container(
        padding: pw.EdgeInsets.all(2),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Customer  : $name',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            if (address.isNotEmpty && address != 'N/A')
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Address     :', style: pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Text(
                      address.isNotEmpty ? address : "N/A",
                      style: pw.TextStyle(fontSize: 11),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            pw.SizedBox(height: 4),
            pw.Text('Mobile Tel  : $mobile', style: pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 6),
            if (purchaseMode == 'EMI' && financeType != null)
              pw.Row(
                children: [
                  pw.Text(
                    'Finance       : ',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    financeType,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPdfMainTable(
    String productName,
    String identifier,
    String identifierLabel,
    double taxableAmount,
    double gstAmount,
    double totalAmount,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: pw.FixedColumnWidth(40),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FixedColumnWidth(60),
        3: pw.FixedColumnWidth(25),
        4: pw.FixedColumnWidth(50),
        5: pw.FixedColumnWidth(70),
        6: pw.FixedColumnWidth(45),
        7: pw.FixedColumnWidth(50),
        8: pw.FixedColumnWidth(60),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: [
            _buildPdfTableCell('SLNO', isHeader: true),
            _buildPdfTableCell('Name of Item/Commodity', isHeader: true),
            _buildPdfTableCell('HSNCode', isHeader: true),
            _buildPdfTableCell('Qty', isHeader: true),
            _buildPdfTableCell(' Rate', isHeader: true),
            _buildPdfTableCell(' Discount', isHeader: true),
            _buildPdfTableCell('GST%', isHeader: true),
            _buildPdfTableCell('GST Amt', isHeader: true),
            _buildPdfTableCell('Total ', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _buildPdfTableCell('1'),
            _buildPdfTableCell(
              '$productName\n$identifierLabel: $identifier',
              textAlign: pw.TextAlign.left,
              fontSize: 11,
              maxLines: 3,
            ),
            _buildPdfTableCell('85171300'),
            _buildPdfTableCell('1'),
            _buildPdfTableCell(taxableAmount.toStringAsFixed(2)),
            _buildPdfTableCell('0.00'),
            _buildPdfTableCell('18'),
            _buildPdfTableCell(gstAmount.toStringAsFixed(2)),
            _buildPdfTableCell(totalAmount.toStringAsFixed(2)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfTotalSection(
    double totalAmount,
    double taxableAmount,
    double gstAmount,
  ) {
    String amountInWords = _amountToWords(totalAmount.toString());

    return pw.Column(
      children: [
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.black, thickness: 0.5, height: 0),
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '1',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                taxableAmount.toStringAsFixed(2),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                gstAmount.toStringAsFixed(2),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                totalAmount.toStringAsFixed(2),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.Divider(color: PdfColors.black, thickness: 0.5, height: 0),
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'In Words: $amountInWords',
                style: pw.TextStyle(fontSize: 11),
                maxLines: 2,
              ),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total Amount: ${totalAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfBottomSection() {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: pw.EdgeInsets.all(2),
              child: _buildPdfGstBreakdownTable(),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            flex: 1,
            child: pw.Container(
              padding: pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Certified that the particulars given above are true and correct',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 15),
                  pw.Text(
                    'For MOBILE HOUSE',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: PdfColors.black, thickness: 0.5),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Authorised Signatory',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Table _buildPdfGstBreakdownTable() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: pw.FixedColumnWidth(40),
        1: pw.FixedColumnWidth(35),
        2: pw.FixedColumnWidth(35),
        3: pw.FixedColumnWidth(35),
        4: pw.FixedColumnWidth(40),
        5: pw.FixedColumnWidth(40),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: [
            _buildPdfTableCell('', isHeader: true, fontSize: 9),
            _buildPdfTableCell('GST 0%', isHeader: true, fontSize: 9),
            _buildPdfTableCell('GST 5%', isHeader: true, fontSize: 9),
            _buildPdfTableCell('GST 12%', isHeader: true, fontSize: 9),
            _buildPdfTableCell('GST 18%', isHeader: true, fontSize: 9),
            _buildPdfTableCell('GST 28%', isHeader: true, fontSize: 9),
          ],
        ),
        pw.TableRow(
          children: [
            _buildPdfTableCell('Taxable', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
          ],
        ),
        pw.TableRow(
          children: [
            _buildPdfTableCell('CGST Amt', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
          ],
        ),
        pw.TableRow(
          children: [
            _buildPdfTableCell('SGST Amt', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
            _buildPdfTableCell('0.00', fontSize: 9),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfTableCell(
    String text, {
    bool isHeader = false,
    double fontSize = 11,
    pw.TextAlign textAlign = pw.TextAlign.center,
    int maxLines = 1,
  }) {
    final lines = text.split('\n');

    if (maxLines <= 1 || lines.length <= 1) {
      return pw.Container(
        alignment: pw.Alignment.center,
        padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
          textAlign: textAlign,
          maxLines: maxLines,
        ),
      );
    }

    return pw.Container(
      alignment: pw.Alignment.center,
      padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            lines[0],
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          for (int i = 1; i < lines.length && i < maxLines; i++)
            pw.Text(
              lines[i],
              style: pw.TextStyle(
                fontSize: fontSize * 0.9,
                fontWeight: pw.FontWeight.normal,
              ),
              textAlign: pw.TextAlign.center,
            ),
        ],
      ),
    );
  }

  String _amountToWords(String amount) {
    try {
      double value = double.parse(amount);
      if (value == 0) return 'Zero Rupees Only';

      int rupees = value.toInt();
      int paise = ((value - rupees) * 100).round();

      String rupeeWords = _convertNumberToWords(rupees);
      String paiseWords = paise > 0
          ? ' and ${_convertNumberToWords(paise)} Paise'
          : '';

      return '${rupeeWords.trim()} Rupees$paiseWords Only';
    } catch (e) {
      return 'Amount in words conversion failed';
    }
  }

  String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';

    List<String> units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
    ];
    List<String> teens = [
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    List<String> tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    String words = '';

    if (number >= 10000000) {
      words += '${_convertNumberToWords(number ~/ 10000000)} Crore ';
      number %= 10000000;
    }

    if (number >= 100000) {
      words += '${_convertNumberToWords(number ~/ 100000)} Lakh ';
      number %= 100000;
    }

    if (number >= 1000) {
      words += '${_convertNumberToWords(number ~/ 1000)} Thousand ';
      number %= 1000;
    }

    if (number >= 100) {
      words += '${_convertNumberToWords(number ~/ 100)} Hundred ';
      number %= 100;
    }

    if (number > 0) {
      if (words.isNotEmpty) words += 'and ';

      if (number < 10) {
        words += units[number];
      } else if (number < 20) {
        words += teens[number - 10];
      } else {
        words += tens[number ~/ 10];
        if (number % 10 > 0) {
          words += ' ${units[number % 10]}';
        }
      }
    }

    return words.trim();
  }

  Future<String> _savePdfToStorage(
    Uint8List pdfBytes,
    Map<String, dynamic> bill,
  ) async {
    try {
      Directory directory;
      if (Platform.isAndroid) {
        try {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = Directory('/storage/emulated/0/Downloads');
            if (!await directory.exists()) {
              directory =
                  await getExternalStorageDirectory() ??
                  await getApplicationDocumentsDirectory();
            }
          }
        } catch (e) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final mobileHouseDir = Directory('${directory.path}/MobileHouse');
      if (!await mobileHouseDir.exists()) {
        await mobileHouseDir.create(recursive: true);
      }

      final billNo =
          bill['billNumber']?.toString().replaceAll('MH-', '') ?? 'bill';
      final customerName = (bill['customerName'] ?? 'customer')
          .toString()
          .replaceAll(RegExp(r'[^\w\s-]'), '_')
          .replaceAll(' ', '_');
      final fileName = 'MH_${billNo}_${customerName}.pdf';

      final filePath = '${mobileHouseDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(pdfBytes, flush: true);
      return filePath;
    } catch (e) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'MH_${bill['billNumber']}.pdf';
      final filePath = '${appDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);
      return filePath;
    }
  }

  Future<void> _sharePdf(File pdfFile) async {
    try {
      if (!await pdfFile.exists()) {
        throw Exception('PDF file not found');
      }

      final fileName = pdfFile.path.split('/').last;

      await Share.shareXFiles(
        [XFile(pdfFile.path, mimeType: 'application/pdf', name: fileName)],
        text: 'Mobile House Bill',
        subject: 'Mobile House Bill',
      );
    } catch (e) {
      print('Error sharing PDF: $e');
    }
  }

  Future<void> _printPdf(File pdfFile) async {
    try {
      await Share.shareXFiles([
        XFile(pdfFile.path, mimeType: 'application/pdf'),
      ], text: 'Print Mobile House Bill');
    } catch (e) {
      print('Error printing: $e');
    }
  }
}
