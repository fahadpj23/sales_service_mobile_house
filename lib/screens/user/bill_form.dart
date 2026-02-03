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
      final ByteData logoData = await rootBundle.load(
        'assets/mobileHouseLogo.png',
      );
      _logoImage = logoData.buffer.asUint8List();

      final ByteData sealData = await rootBundle.load(
        'assets/mobileHouseSeal.jpeg',
      );
      _sealImage = sealData.buffer.asUint8List();
    } catch (e) {
      print('Error loading images: $e');
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

      await _saveBillRecord();
      final pdf = await _generatePdf();

      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
      } catch (e) {
        print('Printing error: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bill created and phone marked as sold successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(Duration(seconds: 1));
      Navigator.pop(context, true);
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
    List<String> thousands = ['', 'Thousand', 'Lakh', 'Crore'];

    String words = '';
    int temp = number;
    int index = 0;

    while (temp > 0) {
      int part = temp % 1000;
      if (part > 0) {
        String partWords = _convertThreeDigit(part);
        if (thousands[index] != '') {
          partWords += ' ${thousands[index]} ';
        }
        words = partWords + words;
      }
      temp = temp ~/ 1000;
      index++;
    }

    return words.trim();
  }

  String _convertThreeDigit(int number) {
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
    int hundreds = number ~/ 100;
    int remainder = number % 100;

    if (hundreds > 0) {
      words += '${units[hundreds]} Hundred ';
    }

    if (remainder > 0) {
      if (remainder < 10) {
        words += '${units[remainder]} ';
      } else if (remainder < 20) {
        words += '${teens[remainder - 10]} ';
      } else {
        words += '${tens[remainder ~/ 10]} ';
        if (remainder % 10 > 0) {
          words += '${units[remainder % 10]} ';
        }
      }
    }

    return words;
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();
    String currentDate =
        '${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // GSTIN
              pw.Text(
                'GSTIN: 32BSGPJ3340H1Z4',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),

              // Logo and Shop Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  if (_logoImage != null)
                    pw.Column(
                      children: [
                        pw.Image(pw.MemoryImage(_logoImage!), height: 35),
                        pw.SizedBox(height: 4),
                        _selectedShop == 'Peringottukara'
                            ? pw.Column(
                                children: [
                                  pw.Text(
                                    "3way junction Peringottukara",
                                    style: pw.TextStyle(fontSize: 9),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    "Mob: 9072430483, 8304830868",
                                    style: pw.TextStyle(fontSize: 9),
                                  ),
                                ],
                              )
                            : pw.Column(
                                children: [
                                  pw.Text(
                                    "Cherpu, Thayamkulangara",
                                    style: pw.TextStyle(fontSize: 9),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    "Mob: 9544466724",
                                    style: pw.TextStyle(fontSize: 9),
                                  ),
                                ],
                              ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          "Mobile house",
                          style: pw.TextStyle(fontSize: 9),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          "GST TAX INVOICE (TYPE-B2C) - CASH SALE",
                          style: pw.TextStyle(fontSize: 7),
                        ),
                      ],
                    )
                  else
                    pw.Text(
                      'MOBILE HOUSE',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Invoice Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'STATE : KERALA',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Invoice No. : MH-${billNoController.text}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                          color: PdfColors.green,
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
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Invoice Date : $currentDate',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Customer Details
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Customer  : ${customerNameController.text}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Address     :',
                        style: pw.TextStyle(fontSize: 9),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Expanded(
                        child: pw.Text(
                          addressController.text,
                          style: pw.TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Mobile Tel  :  ${mobileNumberController.text}',
                    style: pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Product Table
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(0.5),
                  1: pw.FlexColumnWidth(2.5),
                  2: pw.FlexColumnWidth(0.7),
                  3: pw.FlexColumnWidth(0.7),
                  4: pw.FlexColumnWidth(0.9),
                  5: pw.FlexColumnWidth(0.7),
                  6: pw.FlexColumnWidth(0.7),
                  7: pw.FlexColumnWidth(0.9),
                  8: pw.FlexColumnWidth(1.0),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildTableCell('SLNO', true),
                      _buildTableCell('Description', true),
                      _buildTableCell('HSN', true),
                      _buildTableCell('Qty', true),
                      _buildTableCell('Rate', true),
                      _buildTableCell('Disc', true),
                      _buildTableCell('GST%', true),
                      _buildTableCell('GST Amt', true),
                      _buildTableCell('Total', true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('1', false),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              phoneModelController.text,
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              'IMEI: ${imei1Controller.text}',
                              style: pw.TextStyle(fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                      _buildTableCell('8517', false),
                      _buildTableCell('1', false),
                      _buildTableCell(
                        '₹${taxableAmountController.text}',
                        false,
                      ),
                      _buildTableCell('₹0.00', false),
                      _buildTableCell('18%', false),
                      _buildTableCell('₹${gstAmountController.text}', false),
                      _buildTableCell(
                        '₹${totalAmountController.text}.00',
                        false,
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Seal Image
              if (_sealImage != null && _sealChecked)
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Transform.rotate(
                    angle: 25 * 3.14159 / 180,
                    child: pw.Image(
                      pw.MemoryImage(_sealImage!),
                      width: 80,
                      height: 80,
                    ),
                  ),
                ),
              pw.SizedBox(height: 8),

              // Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total', style: pw.TextStyle(fontSize: 9)),
                  pw.Text('1', style: pw.TextStyle(fontSize: 9)),
                  pw.Text(
                    '₹${taxableAmountController.text}',
                    style: pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    '₹${gstAmountController.text}',
                    style: pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    '₹${totalAmountController.text}.00',
                    style: pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Amount in Words
              pw.Text(
                'In Words: ${_amountToWords(totalAmountController.text)}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.SizedBox(height: 16),

              // GST Summary Table
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(1.5),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                  4: pw.FlexColumnWidth(1),
                  5: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildTableCell('', true),
                      _buildTableCell('GST 0%', true),
                      _buildTableCell('GST 5%', true),
                      _buildTableCell('GST 12%', true),
                      _buildTableCell('GST 18%', true),
                      _buildTableCell('GST 28%', true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('Taxable', false),
                      _buildTableCell('0.00', false),
                      _buildTableCell('0.00', false),
                      _buildTableCell('0.00', false),
                      _buildTableCell(taxableAmountController.text, false),
                      _buildTableCell('0.00', false),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('CGST Amt', false),
                      _buildTableCell('0.00', false),
                      _buildTableCell('0.00', false),
                      _buildTableCell('0.00', false),
                      _buildTableCell(
                        (double.parse(gstAmountController.text) / 2)
                            .toStringAsFixed(2),
                        false,
                      ),
                      _buildTableCell('0.00', false),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('SGST Amt', false),
                      _buildTableCell('0.00', false),
                      _buildTableCell('0.00', false),
                      _buildTableCell('0.00', false),
                      _buildTableCell(
                        (double.parse(gstAmountController.text) / 2)
                            .toStringAsFixed(2),
                        false,
                      ),
                      _buildTableCell('0.00', false),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Certified that the particulars given above are true and correct',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'For MOBILE HOUSE',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 16),
                      pw.Container(width: 120, child: pw.Divider()),
                      pw.Text(
                        'Authorised Signatory',
                        style: pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildTableCell(String text, bool isHeader) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  String _getMonthName(int month) {
    List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
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
