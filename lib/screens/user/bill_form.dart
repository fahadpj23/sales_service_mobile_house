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
    // Removed automatic bill number generation

    // Add listener for total amount changes
    totalAmountController.addListener(_calculateGST);
  }

  void _autoFillData() {
    if (widget.phoneData != null) {
      setState(() {
        phoneModelController.text = widget.phoneData!['productName'] ?? '';

        final price = widget.phoneData!['productPrice'];
        if (price != null) {
          totalAmountController.text = price.toString();
          // Calculate GST immediately when auto-filling
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

  // Removed _generateBillNumber() function entirely

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
        // Clear fields if parsing fails
        setState(() {
          taxableAmountController.text = '';
          gstAmountController.text = '';
        });
      }
    } else {
      // Clear fields if total amount is empty
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

    // Validate bill number (should not be empty)
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
          'soldBillNo': billNoController.text,
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
              'soldBillNo': billNoController.text,
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
        'billNumber': billNoController.text,
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

    final a4NoMargin = PdfPageFormat(
      PdfPageFormat.a4.width,
      PdfPageFormat.a4.height,
      marginLeft: 20,
      marginTop: 20,
      marginRight: 20,
      marginBottom: 20,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: a4NoMargin,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: pw.EdgeInsets.all(10),
                  child: pw.Text(
                    'GSTIN: 32BSGPJ3340H1Z4',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    if (_logoImage != null)
                      pw.Container(
                        child: pw.FittedBox(
                          child: pw.Column(
                            children: [
                              pw.Container(
                                height: 40,
                                child: pw.Image(pw.MemoryImage(_logoImage!)),
                              ),
                              pw.SizedBox(height: 3),
                              if (_selectedShop == 'Peringottukara')
                                pw.Column(
                                  children: [
                                    pw.Text(
                                      "3way junction Peringottukara",
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.normal,
                                      ),
                                    ),
                                    pw.SizedBox(height: 3),
                                    pw.Text(
                                      "Mob: 9072430483, 8304830868",
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                )
                              else if (_selectedShop == 'Cherpu')
                                pw.Column(
                                  children: [
                                    pw.Text(
                                      "Cherpu, Thayamkulangara",
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.normal,
                                      ),
                                    ),
                                    pw.SizedBox(height: 3),
                                    pw.Text(
                                      "Mob: 9544466724",
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                "Mobile house",
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.normal,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                "GST TAX INVOICE (TYPE-B2C) - CASH SALE",
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      pw.Text(
                        'MOBILE HOUSE',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                  ],
                ),

                pw.SizedBox(height: 2),

                pw.Container(
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'STATE : KERALA',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Invoice No. : ${billNoController.text.isNotEmpty ? billNoController.text : ""}',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
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
                              fontSize: 9,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Invoice Date : $currentDate',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Divider(color: PdfColors.black, thickness: 1),

                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Customer  : ${customerNameController.text.isNotEmpty ? customerNameController.text : ""}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Address     :',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.normal,
                            ),
                          ),
                          pw.SizedBox(width: 5),
                          pw.Expanded(
                            child: pw.Text(
                              addressController.text.isNotEmpty
                                  ? addressController.text
                                  : "",
                              style: pw.TextStyle(fontSize: 10),
                              softWrap: true,
                              maxLines: null,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Mobile Tel  :  ${mobileNumberController.text.isNotEmpty ? mobileNumberController.text : ""}',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 3),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                  columnWidths: {
                    0: pw.FlexColumnWidth(0.5),
                    1: pw.FlexColumnWidth(2.5),
                    2: pw.FlexColumnWidth(0.8),
                    3: pw.FlexColumnWidth(0.8),
                    4: pw.FlexColumnWidth(1.0),
                    5: pw.FlexColumnWidth(0.8),
                    6: pw.FlexColumnWidth(0.8),
                    7: pw.FlexColumnWidth(1.0),
                    8: pw.FlexColumnWidth(1.2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        _buildTableHeaderCell('SLNO'),
                        _buildTableHeaderCell('Description'),
                        _buildTableHeaderCell('HSN'),
                        _buildTableHeaderCell('Qty'),
                        _buildTableHeaderCell('Rate'),
                        _buildTableHeaderCell('Disc'),
                        _buildTableHeaderCell('GST%'),
                        _buildTableHeaderCell('GST Amt'),
                        _buildTableHeaderCell('Total'),
                      ],
                    ),

                    pw.TableRow(
                      children: [
                        _buildTableCell('1'),
                        pw.Container(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                phoneModelController.text.isNotEmpty
                                    ? phoneModelController.text
                                    : "",
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              imei1Controller.text.isNotEmpty
                                  ? pw.Text(
                                      'IMEI: ${imei1Controller.text}',
                                      style: pw.TextStyle(fontSize: 9),
                                    )
                                  : pw.SizedBox(),
                            ],
                          ),
                        ),
                        _buildTableCell('8517'),
                        _buildTableCell('1'),
                        _buildTableCell(
                          taxableAmountController.text.isNotEmpty
                              ? '₹${taxableAmountController.text}'
                              : "₹0.00",
                        ),
                        _buildTableCell('₹0.00'),
                        _buildTableCell('18%'),
                        _buildTableCell(
                          gstAmountController.text.isNotEmpty
                              ? '₹${gstAmountController.text}'
                              : "₹0.00",
                        ),
                        _buildTableCell(
                          totalAmountController.text.isNotEmpty
                              ? '₹${totalAmountController.text}.00'
                              : '₹0.00',
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),

                if (_sealImage != null && _sealChecked)
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Transform.rotate(
                      angle: 25 * 3.14159 / 180,
                      child: pw.Image(
                        pw.MemoryImage(_sealImage!),
                        width: 100,
                        height: 100,
                      ),
                    ),
                  ),

                pw.SizedBox(height: 10),

                pw.Container(
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total'),
                      pw.Text('1'),
                      pw.Text(
                        taxableAmountController.text.isNotEmpty
                            ? '₹${taxableAmountController.text}'
                            : '₹0.00',
                      ),
                      pw.Text(
                        gstAmountController.text.isNotEmpty
                            ? '₹${gstAmountController.text}'
                            : '₹0.00',
                      ),
                      pw.Text(
                        totalAmountController.text.isNotEmpty
                            ? '₹${totalAmountController.text}.00'
                            : '₹0.00',
                      ),
                    ],
                  ),
                ),

                pw.Divider(color: PdfColors.black, thickness: 1),

                pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'In Words: ${totalAmountController.text.isNotEmpty ? _amountToWords(totalAmountController.text) : ""}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),

                pw.SizedBox(height: 10),

                pw.Container(
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.grey400,
                      width: 0.5,
                    ),
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
                          _buildTableHeaderCell(''),
                          _buildTableHeaderCell('GST 0%'),
                          _buildTableHeaderCell('GST 5%'),
                          _buildTableHeaderCell('GST 12%'),
                          _buildTableHeaderCell('GST 18%'),
                          _buildTableHeaderCell('GST 28%'),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          _buildTableCell('Taxable'),
                          _buildTableCell('0.00'),
                          _buildTableCell('0.00'),
                          _buildTableCell('0.00'),
                          _buildTableCell(
                            taxableAmountController.text.isNotEmpty
                                ? taxableAmountController.text
                                : '0.00',
                          ),
                          _buildTableCell('0.00'),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          _buildTableCell('CGST Amt'),
                          _buildTableCell('0.00'),
                          _buildTableCell('0.00'),
                          _buildTableCell('0.00'),
                          _buildTableCell(
                            gstAmountController.text.isNotEmpty
                                ? (double.parse(gstAmountController.text) / 2)
                                      .toStringAsFixed(2)
                                : '0.00',
                          ),
                          _buildTableCell('0.00'),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          _buildTableCell('SGST Amt'),
                          _buildTableCell('0.00'),
                          _buildTableCell('0.00'),
                          _buildTableCell('0.00'),
                          _buildTableCell(
                            gstAmountController.text.isNotEmpty
                                ? (double.parse(gstAmountController.text) / 2)
                                      .toStringAsFixed(2)
                                : '0.00',
                          ),
                          _buildTableCell('0.00'),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Container(
                      width: 200,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Certified that the particulars given above are true and correct',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'For MOBILE HOUSE',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 20),
                        pw.Container(
                          width: 150,
                          child: pw.Divider(
                            color: PdfColors.black,
                            thickness: 1,
                          ),
                        ),
                        pw.Text(
                          'Authorised Signatory',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
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

  pw.Widget _buildTableHeaderCell(String text) {
    return pw.Container(
      padding: pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildTableCell(String text) {
    return pw.Container(
      padding: pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Sales Bill',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SALES BILL',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    if (widget.phoneData != null)
                      Text(
                        'Selling: ${phoneModelController.text}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildShopDropdown(),
                    SizedBox(height: 16),

                    TextFormField(
                      controller: billNoController,
                      decoration: InputDecoration(
                        labelText: 'Bill No *',
                        prefixIcon: Icon(Icons.receipt, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'Enter bill number',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Bill number is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    TextFormField(
                      controller: customerNameController,
                      decoration: InputDecoration(
                        labelText: 'Customer Name *',
                        prefixIcon: Icon(Icons.person, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Customer name is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    TextFormField(
                      controller: mobileNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number *',
                        prefixIcon: Icon(Icons.phone, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Mobile number is required';
                        }
                        if (value.length != 10) {
                          return 'Enter valid 10-digit mobile number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    TextFormField(
                      controller: phoneModelController,
                      readOnly: widget.phoneData != null,
                      decoration: InputDecoration(
                        labelText: 'Phone Model *',
                        prefixIcon: Icon(
                          Icons.phone_android,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: widget.phoneData != null,
                        fillColor: widget.phoneData != null
                            ? Colors.grey[100]
                            : null,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Phone model is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: imei1Controller,
                            readOnly: widget.phoneData != null,
                            decoration: InputDecoration(
                              labelText: 'IMEI *',
                              prefixIcon: Icon(
                                Icons.qr_code,
                                color: Colors.blue,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: widget.phoneData != null,
                              fillColor: widget.phoneData != null
                                  ? Colors.grey[100]
                                  : null,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'IMEI is required';
                              }
                              if (value.length < 15) {
                                return 'IMEI must be at least 15 digits';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        widget.phoneData == null
                            ? ElevatedButton(
                                onPressed: _startScanningIMEI,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.all(12),
                                ),
                                child: Icon(Icons.qr_code_scanner),
                              )
                            : SizedBox(),
                      ],
                    ),
                    SizedBox(height: 16),

                    TextFormField(
                      controller: addressController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.location_on, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    TextFormField(
                      controller: totalAmountController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Total Amount *',
                        prefixIcon: Icon(
                          Icons.attach_money,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        // This will trigger the GST calculation as user types
                        _calculateGST();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Total amount is required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Enter valid amount';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GST Calculation (18%)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Taxable Amount:'),
                                Text(
                                  taxableAmountController.text.isNotEmpty
                                      ? '₹${taxableAmountController.text}'
                                      : '₹0.00',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('GST Amount:'),
                                Text(
                                  gstAmountController.text.isNotEmpty
                                      ? '₹${gstAmountController.text}'
                                      : '₹0.00',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    Row(
                      children: [
                        Checkbox(
                          value: _sealChecked,
                          onChanged: (value) {
                            setState(() {
                              _sealChecked = value ?? false;
                            });
                          },
                        ),
                        SizedBox(width: 8),
                        Text('Apply Seal on Bill'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            _buildActionButton(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildShopDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(width: 12),
          Icon(Icons.store, color: Colors.blue),
          SizedBox(width: 12),
          Text(
            'Shop:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(width: 16),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedShop,
                isExpanded: true,
                items: _shopOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedShop = newValue;
                  });
                },
              ),
            ),
          ),
          SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _markAsSoldAndPrint,
        icon: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(Icons.print, size: 24),
        label: Text(
          _isLoading ? 'Processing...' : 'Print Bill & Mark as Sold',
          style: TextStyle(fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 3,
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
