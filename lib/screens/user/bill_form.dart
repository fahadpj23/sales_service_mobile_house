import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';

class BillFormScreen extends StatefulWidget {
  final Map<String, dynamic>? phoneData;
  final String? imei;
  final String? phoneId;

  const BillFormScreen({super.key, this.phoneData, this.imei, this.phoneId});

  @override
  _BillFormScreenState createState() => _BillFormScreenState();
}

class _BillFormScreenState extends State<BillFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TextEditingController billNoController = TextEditingController();
  TextEditingController customerNameController = TextEditingController();
  TextEditingController mobileNumberController = TextEditingController();
  TextEditingController phoneModelController = TextEditingController();
  TextEditingController imei1Controller = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController totalAmountController = TextEditingController();
  TextEditingController taxableAmountController = TextEditingController();
  TextEditingController gstAmountController = TextEditingController();

  bool _isScanning = false;
  bool _sealChecked = false;
  bool _isLoading = false;

  String? _selectedShop = 'Peringottukara';
  final List<String> _shopOptions = ['Peringottukara', 'Cherpu'];

  Uint8List? _logoImage;
  Uint8List? _sealImage;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    _loadImages();
    _autoFillData();
    totalAmountController.addListener(_calculateGST);
  }

  void _autoFillData() {
    if (widget.phoneData != null) {
      setState(() {
        phoneModelController.text = widget.phoneData!['productName'] ?? '';
        final price = widget.phoneData!['productPrice'];
        if (price != null) {
          totalAmountController.text = price.toString();
          _calculateGST();
        }
        if (widget.imei != null) {
          imei1Controller.text = widget.imei!;
        } else {
          imei1Controller.text = widget.phoneData!['imei'] ?? '';
        }
      });
    }
  }

  void _calculateGST() {
    if (totalAmountController.text.isNotEmpty) {
      try {
        double totalAmount = double.parse(totalAmountController.text);
        double gstPercent = 18.0;
        double taxableAmount = totalAmount / (1 + gstPercent / 100);
        double gstAmount = totalAmount - taxableAmount;

        setState(() {
          taxableAmountController.text = taxableAmount.toStringAsFixed(2);
          gstAmountController.text = gstAmount.toStringAsFixed(2);
        });
      } catch (e) {
        setState(() {
          taxableAmountController.text = '';
          gstAmountController.text = '';
        });
      }
    } else {
      setState(() {
        taxableAmountController.text = '';
        gstAmountController.text = '';
      });
    }
  }

  Future<void> _loadImages() async {
    try {
      // Load logo
      final logoByteData = await rootBundle.load('assets/mobileHouseLogo.png');
      _logoImage = Uint8List.view(
        logoByteData.buffer,
        logoByteData.offsetInBytes,
        logoByteData.lengthInBytes,
      );

      print('Logo image loaded: ${_logoImage?.length} bytes');

      // Load seal
      final sealByteData = await rootBundle.load('assets/mobileHouseSeal.jpeg');
      _sealImage = Uint8List.view(
        sealByteData.buffer,
        sealByteData.offsetInBytes,
        sealByteData.lengthInBytes,
      );

      print('Seal image loaded: ${_sealImage?.length} bytes');
    } catch (e) {
      print('Error loading images: $e');
      _logoImage = null;
      _sealImage = null;
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      // Handle permission denial
    }
  }

  void _startScanningIMEI() {
    setState(() {
      _isScanning = true;
    });
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
    });
  }

  void _onBarcodeScanned(BarcodeCapture barcodes) {
    if (barcodes.barcodes.isNotEmpty) {
      final String barcode = barcodes.barcodes.first.rawValue ?? '';
      setState(() {
        imei1Controller.text = barcode;
        _isScanning = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Scanned IMEI: $barcode')));
    }
  }

  Future<void> _markAsSoldAndPrint() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (billNoController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter bill number')));
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Mark phone as sold in inventory
      if (widget.phoneId != null) {
        await _firestore.collection('phoneStock').doc(widget.phoneId).update({
          'status': 'sold',
          'soldAt': FieldValue.serverTimestamp(),
          'soldTo': customerNameController.text,
          'soldBillNo': 'MH-${billNoController.text}',
          'soldAmount': double.parse(totalAmountController.text),
          'soldShop': _selectedShop,
          'soldBy': Provider.of<AuthProvider>(
            context,
            listen: false,
          ).user?.email,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final imei = imei1Controller.text.trim();
        if (imei.isNotEmpty) {
          final querySnapshot = await _firestore
              .collection('phoneStock')
              .where('imei', isEqualTo: imei)
              .where('status', isEqualTo: 'available')
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final docId = querySnapshot.docs.first.id;
            await _firestore.collection('phoneStock').doc(docId).update({
              'status': 'sold',
              'soldAt': FieldValue.serverTimestamp(),
              'soldTo': customerNameController.text,
              'soldBillNo': 'MH-${billNoController.text}',
              'soldAmount': double.parse(totalAmountController.text),
              'soldShop': _selectedShop,
              'soldBy': Provider.of<AuthProvider>(
                context,
                listen: false,
              ).user?.email,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // Save bill record
      await _saveBillRecord();

      // Generate and print PDF
      final pdfBytes = await _generatePdf();

      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
        );
      } catch (e) {
        print('Printing error: $e');
        // Still show success even if printing fails
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bill created and phone marked as sold successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(Duration(seconds: 1));
      // Navigator.pop(context, true);
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveBillRecord() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      final billData = {
        'billNumber': 'MH-${billNoController.text}',
        'billDate': FieldValue.serverTimestamp(),
        'customerName': customerNameController.text,
        'customerMobile': mobileNumberController.text,
        'customerAddress': addressController.text,
        'productName': phoneModelController.text,
        'imei': imei1Controller.text,
        'totalAmount': double.parse(totalAmountController.text),
        'taxableAmount': double.parse(taxableAmountController.text),
        'gstAmount': double.parse(gstAmountController.text),
        'shop': _selectedShop,
        'shopId': user?.shopId,
        'createdBy': user?.email,
        'createdById': user?.uid,
        'sealApplied': _sealChecked,
        'createdAt': FieldValue.serverTimestamp(),
        'phoneStockId': widget.phoneId,
        'originalPhoneData': widget.phoneData,
      };

      await _firestore.collection('bills').add(billData);
    } catch (e) {
      print('Error saving bill record: $e');
      throw e;
    }
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

      return '${rupeeWords.trim()} Rupees${paiseWords} Only';
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
      words += _convertNumberToWords(number ~/ 10000000) + ' Crore ';
      number %= 10000000;
    }

    if (number >= 100000) {
      words += _convertNumberToWords(number ~/ 100000) + ' Lakh ';
      number %= 100000;
    }

    if (number >= 1000) {
      words += _convertNumberToWords(number ~/ 1000) + ' Thousand ';
      number %= 1000;
    }

    if (number >= 100) {
      words += _convertNumberToWords(number ~/ 100) + ' Hundred ';
      number %= 100;
    }

    if (number > 0) {
      if (words.isNotEmpty) {
        words += 'and ';
      }

      if (number < 10) {
        words += units[number];
      } else if (number < 20) {
        words += teens[number - 10];
      } else {
        words += tens[number ~/ 10];
        if (number % 10 > 0) {
          words += ' ' + units[number % 10];
        }
      }
    }

    return words.trim();
  }

  Future<Uint8List> _generatePdf() async {
    print('Generating PDF - Logo loaded: ${_logoImage != null}');
    print('Generating PDF - Seal loaded: ${_sealImage != null}');

    final pdf = pw.Document();
    final PdfPageFormat pageFormat = PdfPageFormat.a4;

    // Get current date
    String currentDate = DateFormat('dd MMMM yyyy').format(DateTime.now());

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
                // GSTIN at top
                pw.Padding(
                  padding: pw.EdgeInsets.all(8),

                  child: pw.Text(
                    'GSTIN: 32BSGPJ3340H1Z4',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                // Header with Logo
                pw.Padding(
                  padding: pw.EdgeInsets.all(8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Column(
                        children: [
                          if (_logoImage != null)
                            pw.SizedBox(
                              height: 45,
                              child: pw.Image(
                                pw.MemoryImage(_logoImage!),
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

                          // Shop address based on selection
                          if (_selectedShop == 'Peringottukara')
                            pw.Text(
                              "3way junction Peringottukara",
                              style: pw.TextStyle(fontSize: 11),
                            )
                          else if (_selectedShop == 'Cherpu')
                            pw.Text(
                              "Cherpu, Thayamkulangara",
                              style: pw.TextStyle(fontSize: 11),
                            ),

                          pw.SizedBox(height: 2),
                          pw.Text(
                            _selectedShop == 'Peringottukara'
                                ? "Mob: 9072430483, 8304830868"
                                : "Mob: 9544466724",
                            style: pw.TextStyle(fontSize: 11),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            "Mobile house",
                            style: pw.TextStyle(fontSize: 11),
                          ),
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

                // State and Invoice Details
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
                            'Invoice No. : MH-${billNoController.text}',
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

                // Divider that touches border
                pw.Divider(color: PdfColors.black, thickness: 0.2, height: 0),

                pw.SizedBox(height: 4),

                // Customer Details with padding
                pw.Padding(
                  padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: pw.Container(
                    padding: pw.EdgeInsets.all(2),

                    width: pageFormat.width - 46,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Customer  : ${customerNameController.text}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Address     :',
                              style: pw.TextStyle(fontSize: 11),
                            ),
                            pw.SizedBox(width: 4),
                            pw.Expanded(
                              child: pw.Text(
                                addressController.text.isNotEmpty
                                    ? addressController.text
                                    : "N/A",
                                style: pw.TextStyle(fontSize: 11),
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Mobile Tel  : ${mobileNumberController.text}',
                          style: pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),

                pw.SizedBox(height: 4),

                // Main Table
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.black,
                    width: 0.5,
                  ),
                  columnWidths: {
                    0: pw.FixedColumnWidth(40), // SLNO
                    1: pw.FlexColumnWidth(2.5), // Item
                    2: pw.FixedColumnWidth(60), // HSN
                    3: pw.FixedColumnWidth(25), // Qty
                    4: pw.FixedColumnWidth(50), // Rate
                    5: pw.FixedColumnWidth(70), // Disc
                    6: pw.FixedColumnWidth(45), // GST%
                    7: pw.FixedColumnWidth(50), // GST Amt
                    8: pw.FixedColumnWidth(60), // Total
                  },
                  defaultVerticalAlignment:
                      pw.TableCellVerticalAlignment.middle, // Center vertically
                  children: [
                    // Table Header
                    pw.TableRow(
                      verticalAlignment: pw.TableCellVerticalAlignment.middle,
                      children: [
                        _buildTableCell('SLNO', isHeader: true),
                        _buildTableCell(
                          'Name of Item/Commodity',
                          isHeader: true,
                        ),
                        _buildTableCell('HSNCode', isHeader: true),
                        _buildTableCell('Qty', isHeader: true),
                        _buildTableCell(' Rate', isHeader: true),
                        _buildTableCell(' Discount', isHeader: true),
                        _buildTableCell('GST%', isHeader: true),
                        _buildTableCell('GST Amt', isHeader: true),
                        _buildTableCell('Total ', isHeader: true),
                      ],
                    ),

                    // Product Row
                    pw.TableRow(
                      verticalAlignment: pw.TableCellVerticalAlignment.middle,
                      children: [
                        _buildTableCell('1'),
                        _buildTableCell(
                          '${phoneModelController.text.isNotEmpty ? phoneModelController.text : ""}\nIMEI: ${imei1Controller.text.isNotEmpty ? imei1Controller.text : ""}',
                          textAlign: pw.TextAlign.left,
                          fontSize: 11,
                          maxLines: 3,
                        ),
                        _buildTableCell('85171300'),
                        _buildTableCell('1'),
                        _buildTableCell(
                          taxableAmountController.text.isNotEmpty
                              ? '${taxableAmountController.text}'
                              : "0.00",
                        ),
                        _buildTableCell('0.00'),
                        _buildTableCell('18'),
                        _buildTableCell(
                          gstAmountController.text.isNotEmpty
                              ? '${gstAmountController.text}'
                              : "₹0.00",
                        ),
                        _buildTableCell(
                          totalAmountController.text.isNotEmpty
                              ? '${totalAmountController.text}.00'
                              : '0.00',
                        ),
                      ],
                    ),
                  ],
                ),

                // Empty space for seal
                pw.Container(
                  height: 300,
                  child: pw.Stack(
                    children: [
                      // Seal Image
                      if (_sealImage != null && _sealChecked)
                        pw.Positioned(
                          right: 15,
                          bottom: 18,
                          child: pw.Transform.rotate(
                            angle: 25 * 3.14159 / 180,
                            child: pw.SizedBox(
                              width: 150,
                              height: 150,
                              child: pw.Image(
                                pw.MemoryImage(_sealImage!),
                                fit: pw.BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 8),

                // Total Section
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
                        taxableAmountController.text.isNotEmpty
                            ? '${taxableAmountController.text}'
                            : '₹0.00',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        gstAmountController.text.isNotEmpty
                            ? '${gstAmountController.text}'
                            : '0.00',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        totalAmountController.text.isNotEmpty
                            ? '${totalAmountController.text}.00'
                            : '0.00',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Divider(color: PdfColors.black, thickness: 0.5, height: 0),

                // Amount in Words
                pw.Padding(
                  padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'In Words: ${totalAmountController.text.isNotEmpty ? _amountToWords(totalAmountController.text) : ""}',
                        style: pw.TextStyle(fontSize: 11),
                        maxLines: 2,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          'Total Amount: ${totalAmountController.text.isNotEmpty ? '${totalAmountController.text}.00' : "0.00"}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 4),

                // Bottom Section
                pw.Padding(
                  padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // GST Breakdown Table with padding
                      pw.Expanded(
                        flex: 2,
                        child: pw.Container(
                          padding: pw.EdgeInsets.all(2),

                          child: pw.Table(
                            border: pw.TableBorder.all(
                              color: PdfColors.grey400,
                              width: 0.5,
                            ),
                            columnWidths: {
                              0: pw.FixedColumnWidth(40),
                              1: pw.FixedColumnWidth(35),
                              2: pw.FixedColumnWidth(35),
                              3: pw.FixedColumnWidth(35),
                              4: pw.FixedColumnWidth(40),
                              5: pw.FixedColumnWidth(40),
                            },
                            defaultVerticalAlignment:
                                pw.TableCellVerticalAlignment.middle,
                            children: [
                              pw.TableRow(
                                verticalAlignment:
                                    pw.TableCellVerticalAlignment.middle,
                                children: [
                                  _buildTableCell(
                                    '',
                                    isHeader: true,
                                    fontSize: 9,
                                  ),
                                  _buildTableCell(
                                    'GST 0%',
                                    isHeader: true,
                                    fontSize: 9,
                                  ),
                                  _buildTableCell(
                                    'GST 5%',
                                    isHeader: true,
                                    fontSize: 9,
                                  ),
                                  _buildTableCell(
                                    'GST 12%',
                                    isHeader: true,
                                    fontSize: 9,
                                  ),
                                  _buildTableCell(
                                    'GST 18%',
                                    isHeader: true,
                                    fontSize: 9,
                                  ),
                                  _buildTableCell(
                                    'GST 28%',
                                    isHeader: true,
                                    fontSize: 9,
                                  ),
                                ],
                              ),
                              pw.TableRow(
                                verticalAlignment:
                                    pw.TableCellVerticalAlignment.middle,
                                children: [
                                  _buildTableCell('Taxable', fontSize: 9),
                                  _buildTableCell('0.00', fontSize: 9),
                                  _buildTableCell('0.00', fontSize: 9),
                                  _buildTableCell('0.00', fontSize: 9),
                                  _buildTableCell(
                                    gstAmountController.text.isNotEmpty
                                        ? gstAmountController.text
                                        : "0.00",
                                    fontSize: 9,
                                  ),
                                  _buildTableCell('0.00', fontSize: 9),
                                ],
                              ),
                              pw.TableRow(
                                verticalAlignment:
                                    pw.TableCellVerticalAlignment.middle,
                                children: [
                                  _buildTableCell('CGST Amt', fontSize: 9),
                                  _buildTableCell('0.00', fontSize: 9),
                                  _buildTableCell('0.00', fontSize: 9),
                                  _buildTableCell('0.00', fontSize: 9),
                                  _buildTableCell(
                                    gstAmountController.text.isNotEmpty
                                        ? (double.parse(
                                                    gstAmountController.text,
                                                  ) /
                                                  2)
                                              .toStringAsFixed(2)
                                        : "0.00",
                                    fontSize: 9,
                                  ),
                                  _buildTableCell('0.00', fontSize: 9),
                                ],
                              ),
                              pw.TableRow(
                                verticalAlignment:
                                    pw.TableCellVerticalAlignment.middle,
                                children: [
                                  _buildTableCell('SGST Amt', fontSize: 9),
                                  _buildTableCell('0.00', fontSize: 9),
                                  _buildTableCell('0.00', fontSize: 9),
                                  _buildTableCell('0.00', fontSize: 9),
                                  _buildTableCell(
                                    gstAmountController.text.isNotEmpty
                                        ? (double.parse(
                                                    gstAmountController.text,
                                                  ) /
                                                  2)
                                              .toStringAsFixed(2)
                                        : "0.00",
                                    fontSize: 9,
                                  ),
                                  _buildTableCell('0.00', fontSize: 9),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      pw.SizedBox(width: 10),

                      // Authorized Signatory
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
                              pw.Divider(
                                color: PdfColors.black,
                                thickness: 0.5,
                              ),
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
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // Updated _buildTableCell function with more parameters for better control
  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    double fontSize = 11,
    pw.TextAlign textAlign = pw.TextAlign.center,
    int maxLines = 1,
  }) {
    // Split the text into lines
    final lines = text.split('\n');

    // If maxLines is 1 or less, or there's only one line, use simple Text
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

    // For multi-line text with different styling
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment:
            pw.CrossAxisAlignment.center, // Force center for all lines
        children: [
          // First line with bold styling
          pw.Text(
            lines[0],
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center, // Force center alignment
          ),
          pw.SizedBox(height: 3),
          // Second and subsequent lines with smaller font, normal weight
          for (int i = 1; i < lines.length && i < maxLines; i++)
            pw.Text(
              lines[i],
              style: pw.TextStyle(
                fontSize: fontSize * 0.9, // 90% of original font size
                fontWeight: pw.FontWeight.normal,
              ),
              textAlign:
                  pw.TextAlign.center, // Force center alignment for second line
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
        title: Text(
          'Sales Bill',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green[700],
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isScanning ? _buildScanner() : _buildForm(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        Column(
          children: [
            AppBar(
              title: Text('Scan IMEI Barcode'),
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: _stopScanning,
              ),
              backgroundColor: Colors.black87,
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    onDetect: _onBarcodeScanned,
                    controller: MobileScannerController(
                      detectionSpeed: DetectionSpeed.normal,
                      facing: CameraFacing.back,
                      torchEnabled: false,
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.35,
                    left: MediaQuery.of(context).size.width * 0.1,
                    right: MediaQuery.of(context).size.width * 0.1,
                    bottom: MediaQuery.of(context).size.height * 0.35,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.red.withOpacity(0.6),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.green[100]!, width: 1),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SALES BILL',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 6),
                    if (widget.phoneData != null)
                      Text(
                        'Selling: ${phoneModelController.text}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildShopDropdown(),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: billNoController,
                      style: TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Bill No *',
                        labelStyle: TextStyle(fontSize: 14),
                        prefixIcon: Icon(Icons.receipt, color: Colors.green),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green),
                        ),
                        hintText: 'Enter bill number',
                        hintStyle: TextStyle(fontSize: 13),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Bill number is required';
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: customerNameController,
                      style: TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Customer Name *',
                        labelStyle: TextStyle(fontSize: 14),
                        prefixIcon: Icon(Icons.person, color: Colors.green),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Customer name is required';
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: mobileNumberController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Mobile Number *',
                        labelStyle: TextStyle(fontSize: 14),
                        prefixIcon: Icon(Icons.phone, color: Colors.green),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Mobile number is required';
                        if (value.length != 10)
                          return 'Enter valid 10-digit mobile number';
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: phoneModelController,
                      readOnly: widget.phoneData != null,
                      style: TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Phone Model *',
                        labelStyle: TextStyle(fontSize: 14),
                        prefixIcon: Icon(
                          Icons.phone_android,
                          color: Colors.green,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green),
                        ),
                        filled: widget.phoneData != null,
                        fillColor: widget.phoneData != null
                            ? Colors.grey[50]
                            : null,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Phone model is required';
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: imei1Controller,
                            readOnly: widget.phoneData != null,
                            style: TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'IMEI *',
                              labelStyle: TextStyle(fontSize: 14),
                              prefixIcon: Icon(
                                Icons.qr_code,
                                color: Colors.green,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.green),
                              ),
                              filled: widget.phoneData != null,
                              fillColor: widget.phoneData != null
                                  ? Colors.grey[50]
                                  : null,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return 'IMEI is required';
                              if (value.length < 15)
                                return 'IMEI must be at least 15 digits';
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        if (widget.phoneData == null)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: _startScanningIMEI,
                              icon: Icon(
                                Icons.qr_code_scanner,
                                color: Colors.white,
                              ),
                              tooltip: 'Scan IMEI',
                              padding: EdgeInsets.all(10),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: addressController,
                      maxLines: 2,
                      style: TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Address',
                        labelStyle: TextStyle(fontSize: 14),
                        prefixIcon: Icon(
                          Icons.location_on,
                          color: Colors.green,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: totalAmountController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Total Amount *',
                        labelStyle: TextStyle(fontSize: 14),
                        prefixIcon: Icon(
                          Icons.attach_money,
                          color: Colors.green,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) => _calculateGST(),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Total amount is required';
                        if (double.tryParse(value) == null)
                          return 'Enter valid amount';
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GST Calculation (18%)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Taxable Amount:',
                                style: TextStyle(fontSize: 13),
                              ),
                              Text(
                                '₹${taxableAmountController.text}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'GST Amount:',
                                style: TextStyle(fontSize: 13),
                              ),
                              Text(
                                '₹${gstAmountController.text}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[100]!),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _sealChecked,
                            onChanged: (value) =>
                                setState(() => _sealChecked = value ?? false),
                            activeColor: Colors.green,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Apply Seal on Bill',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            _buildActionButton(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShopDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green[100]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(width: 10),
          Icon(Icons.store, color: Colors.green[700]),
          SizedBox(width: 10),
          Text(
            'Shop:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedShop,
                isExpanded: true,
                style: TextStyle(fontSize: 14, color: Colors.green[800]),
                items: _shopOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (String? newValue) =>
                    setState(() => _selectedShop = newValue),
                icon: Icon(Icons.arrow_drop_down, color: Colors.green[700]),
              ),
            ),
          ),
          SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _markAsSoldAndPrint,
          icon: _isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.print, size: 22),
          label: Text(
            _isLoading ? 'Processing...' : 'Print Bill & Mark as Sold',
            style: TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    billNoController.dispose();
    customerNameController.dispose();
    mobileNumberController.dispose();
    phoneModelController.dispose();
    imei1Controller.dispose();
    addressController.dispose();
    totalAmountController.dispose();
    taxableAmountController.dispose();
    gstAmountController.dispose();
    super.dispose();
  }
}
