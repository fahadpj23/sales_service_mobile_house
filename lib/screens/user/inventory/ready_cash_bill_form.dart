import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../providers/auth_provider.dart';

/// Bill form for Ready Cash phones.
/// - Bill is saved to `readyCashPhoneBill` (not `bills`).
/// - The phone in `ReadyCashPhone` is marked `sold` when the bill is saved.
class ReadyCashBillFormScreen extends StatefulWidget {
  final Map<String, dynamic>? phoneData;
  final String? imei;
  final String? phoneId;

  const ReadyCashBillFormScreen({
    super.key,
    this.phoneData,
    this.imei,
    this.phoneId,
  });

  @override
  State<ReadyCashBillFormScreen> createState() =>
      _ReadyCashBillFormScreenState();
}

class _ReadyCashBillFormScreenState extends State<ReadyCashBillFormScreen> {
  static const String _billCollection = 'readyCashPhoneBill';
  static const String _stockCollection = 'ReadyCashPhone';
  static const String _statusField = 'ReadyCashStatus';
  static const String _billPrefix = 'MH-';

  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TextEditingController billNoController;
  late TextEditingController customerNameController;
  late TextEditingController mobileNumberController;
  late TextEditingController phoneModelController;
  late TextEditingController imei1Controller;
  late TextEditingController addressController;
  late TextEditingController totalAmountController;
  late TextEditingController taxableAmountController;
  late TextEditingController gstAmountController;

  bool _sealChecked = false;
  bool _isLoading = false;
  bool _isSoldSaved = false;
  String? _selectedShop = 'Peringottukara';

  String? _selectedPurchaseMode = 'Ready Cash';
  String? _selectedFinanceType;
  bool _showFinanceFields = false;

  bool _isEditMode = false;
  String? _currentBillId;
  String? _currentPhoneDocId;

  final List<String> _purchaseModes = ['Ready Cash', 'Credit Card', 'EMI'];
  final List<String> _financeCompaniesList = [
    'Bajaj Finance',
    'TVS Credit',
    'HDB Financial',
    'Home Credit',
    'Samsung Finance',
    'Oppo Finance',
    'Vivo Finance',
    'yoga kshema Finance',
    'MI Finance',
    'First credit private Finance',
    'Chola Murugappa',
    'Other',
  ];

  static Uint8List? _logoImage;
  static Uint8List? _sealImage;

  File? _savedPdfFile;

  // ───────────────────────── lifecycle ─────────────────────────

  @override
  void initState() {
    super.initState();

    billNoController = TextEditingController();
    customerNameController = TextEditingController();
    mobileNumberController = TextEditingController();
    phoneModelController = TextEditingController();
    imei1Controller = TextEditingController();
    addressController = TextEditingController();
    totalAmountController = TextEditingController();
    taxableAmountController = TextEditingController();
    gstAmountController = TextEditingController();

    _currentPhoneDocId = widget.phoneId;

    _initData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateAndSetBillNumber();
    });
  }

  Future<void> _initData() async {
    await _loadImages();
    if (!mounted) return;

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    setState(() {
      _selectedShop = user?.shopId == 'mG9QgP0dPMP8hGk2yQQO'
          ? 'Cherpu'
          : 'Peringottukara';
    });

    _autoFillData();
    totalAmountController.addListener(_calculateGST);
  }

  @override
  void dispose() {
    totalAmountController.removeListener(_calculateGST);
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

  // ───────────────────────── bill number ─────────────────────────

  Future<String> _generateBillNumber() async {
    try {
      final q = await _firestore
          .collection(_billCollection)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      int next = 1;
      if (q.docs.isNotEmpty) {
        final last = q.docs.first.data()['billNumber'] as String? ?? '';
        if (last.startsWith(_billPrefix)) {
          next = (int.tryParse(last.substring(_billPrefix.length)) ?? 0) + 1;
        }
      }
      return next.toString();
    } catch (e) {
      debugPrint('Error generating bill number: $e');
      final t = DateTime.now().millisecondsSinceEpoch.toString();
      return t.substring(t.length - 6);
    }
  }

  Future<void> _generateAndSetBillNumber() async {
    final n = await _generateBillNumber();
    if (mounted) setState(() => billNoController.text = n);
  }

  Future<void> _regenerateBillNumber() async {
    if (_isLoading) return;
    final n = await _generateBillNumber();
    if (!mounted) return;
    setState(() => billNoController.text = n);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bill number regenerated: $_billPrefix$n')),
    );
  }

  String get _fullBillNumber => billNoController.text.startsWith(_billPrefix)
      ? billNoController.text
      : '$_billPrefix${billNoController.text}';

  // ───────────────────────── helpers ─────────────────────────

  void _autoFillData() {
    final d = widget.phoneData;
    if (d == null) return;
    setState(() {
      phoneModelController.text = d['productName'] ?? '';
      final price = d['productPrice'];
      if (price != null) {
        totalAmountController.text =
            price is double && price == price.roundToDouble()
            ? price.toStringAsFixed(0)
            : price.toString();
        _calculateGST();
      }
      imei1Controller.text = widget.imei ?? d['imei'] ?? '';
    });
  }

  void _calculateGST() {
    final text = totalAmountController.text;
    if (text.isEmpty) {
      setState(() {
        taxableAmountController.text = '';
        gstAmountController.text = '';
      });
      return;
    }
    final total = double.tryParse(text);
    if (total == null) {
      setState(() {
        taxableAmountController.text = '';
        gstAmountController.text = '';
      });
      return;
    }
    final taxable = total / 1.18;
    final gst = total - taxable;
    setState(() {
      taxableAmountController.text = taxable.toStringAsFixed(2);
      gstAmountController.text = gst.toStringAsFixed(2);
    });
  }

  Future<void> _loadImages() async {
    try {
      final b = await rootBundle.load('assets/mobileHouseLogo.png');
      _logoImage = b.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error loading logo: $e');
    }
    try {
      final b = await rootBundle.load('assets/mobileHouseSeal.jpeg');
      _sealImage = b.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error loading seal: $e');
    }
  }

  void _onPurchaseModeSelected(String? mode) {
    setState(() {
      _selectedPurchaseMode = mode;
      if (mode == 'EMI') {
        _showFinanceFields = true;
      } else {
        _selectedFinanceType = null;
        _showFinanceFields = false;
      }
    });
  }

  void _snack(String msg, {Color? color, int seconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: Duration(seconds: seconds),
      ),
    );
  }

  /// Finds the ReadyCashPhone doc for this sale.
  Future<DocumentReference<Map<String, dynamic>>?> _resolvePhoneRef() async {
    if (_currentPhoneDocId != null && _currentPhoneDocId!.isNotEmpty) {
      return _firestore.collection(_stockCollection).doc(_currentPhoneDocId);
    }
    final imei = imei1Controller.text.trim();
    if (imei.isEmpty) return null;
    final q = await _firestore
        .collection(_stockCollection)
        .where('imei', isEqualTo: imei)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.reference;
  }

  void _showAlreadySoldDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'Product Already Sold',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This product with IMEI:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                imei1Controller.text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'has already been marked as SOLD and cannot be sold again.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── save (bill + mark sold) ─────────────────────────

  Future<void> _saveBillAndMarkSold() async {
    if (!_formKey.currentState!.validate()) {
      _snack('Please fill all required fields');
      return;
    }
    if (_selectedPurchaseMode == 'EMI' && _selectedFinanceType == null) {
      _snack('Please select finance company for EMI');
      return;
    }
    if (billNoController.text.isEmpty) {
      _snack('Please enter bill number');
      return;
    }

    try {
      setState(() => _isLoading = true);

      final phoneRef = await _resolvePhoneRef();
      if (phoneRef == null) {
        throw Exception('Phone not found in Ready Cash stock');
      }

      final phoneDoc = await phoneRef.get();
      if (!phoneDoc.exists) {
        throw Exception('Phone not found in Ready Cash stock');
      }
      if (phoneDoc.data()?[_statusField] == 'sold') {
        if (mounted) setState(() => _isLoading = false);
        _showAlreadySoldDialog();
        return;
      }

      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final phone = phoneDoc.data()!;
      final billRef = _firestore.collection(_billCollection).doc();
      final totalAmount = double.parse(totalAmountController.text);

      final billData = <String, dynamic>{
        'billNumber': _fullBillNumber,
        'billDate': FieldValue.serverTimestamp(),
        'customerName': customerNameController.text.trim(),
        'customerMobile': mobileNumberController.text.trim(),
        'customerAddress': addressController.text.trim(),
        'productName': phoneModelController.text.trim(),
        'productBrand': phone['productBrand'],
        'imei': imei1Controller.text.trim(),
        'totalAmount': totalAmount,
        'taxableAmount': double.parse(taxableAmountController.text),
        'gstAmount': double.parse(gstAmountController.text),
        'shop': _selectedShop,
        'shopId': user?.shopId,
        // shop that was holding the phone
        'stockShopId': phone['shopId'],
        'stockShopName': phone['shopName'] ?? phone['shop'],
        'createdBy': user?.email,
        'createdById': user?.uid,
        'sealApplied': _sealChecked,
        'purchaseMode': _selectedPurchaseMode,
        'financeType': _selectedFinanceType,
        'readyCashPhoneId': phoneRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final batch = _firestore.batch();
      batch.set(billRef, billData);
      batch.update(phoneRef, {
        _statusField: 'sold',
        'soldAt': FieldValue.serverTimestamp(),
        'soldTo': customerNameController.text.trim(),
        'customerName': customerNameController.text.trim(),
        'soldBillNo': _fullBillNumber,
        'billNumber': _fullBillNumber,
        'billId': billRef.id,
        'soldAmount': totalAmount,
        'soldShop': _selectedShop,
        'soldBy': user?.email,
        'purchaseMode': _selectedPurchaseMode,
        'financeType': _selectedFinanceType,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      _currentBillId = billRef.id;
      _currentPhoneDocId = phoneRef.id;

      final pdfBytes = await _generateBillPdf();
      final filePath = await _savePdfToStorage(pdfBytes);
      final pdfFile = File(filePath);

      if (!mounted) return;
      setState(() {
        _savedPdfFile = pdfFile;
        _isSoldSaved = true;
      });

      _snack(
        'Bill created and phone marked as sold!',
        color: Colors.green,
        seconds: 3,
      );
      await _sharePdf(pdfFile);
    } catch (e) {
      debugPrint('Error: $e');
      _snack('Error: ${e.toString()}', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───────────────────────── edit saved bill ─────────────────────────

  void _enableEditMode() {
    setState(() => _isEditMode = true);
    _snack(
      'Edit mode enabled. Make your changes and save.',
      color: Colors.orange,
      seconds: 2,
    );
  }

  void _cancelEdit() {
    setState(() => _isEditMode = false);
    _snack('Edit cancelled', color: Colors.orange);
  }

  Future<void> _updateCurrentBill() async {
    if (!_formKey.currentState!.validate()) {
      _snack('Please fill all required fields');
      return;
    }
    if (_selectedPurchaseMode == 'EMI' && _selectedFinanceType == null) {
      _snack('Please select finance company for EMI');
      return;
    }
    if (_currentBillId == null) {
      _snack('Bill not found', color: Colors.red);
      return;
    }

    try {
      setState(() => _isLoading = true);

      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final totalAmount = double.parse(totalAmountController.text);

      final batch = _firestore.batch();
      batch.update(_firestore.collection(_billCollection).doc(_currentBillId), {
        'customerName': customerNameController.text.trim(),
        'customerMobile': mobileNumberController.text.trim(),
        'customerAddress': addressController.text.trim(),
        'totalAmount': totalAmount,
        'taxableAmount': double.parse(taxableAmountController.text),
        'gstAmount': double.parse(gstAmountController.text),
        'sealApplied': _sealChecked,
        'purchaseMode': _selectedPurchaseMode,
        'financeType': _selectedFinanceType,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user?.email,
      });

      if (_currentPhoneDocId != null) {
        batch.update(
          _firestore.collection(_stockCollection).doc(_currentPhoneDocId),
          {
            'soldTo': customerNameController.text.trim(),
            'customerName': customerNameController.text.trim(),
            'soldAmount': totalAmount,
            'purchaseMode': _selectedPurchaseMode,
            'financeType': _selectedFinanceType,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
      await batch.commit();

      final pdfBytes = await _generateBillPdf();
      final filePath = await _savePdfToStorage(pdfBytes);
      final pdfFile = File(filePath);

      if (!mounted) return;
      setState(() {
        _savedPdfFile = pdfFile;
        _isEditMode = false;
      });

      _snack('Bill updated successfully!', color: Colors.green);
      await _sharePdf(pdfFile);
    } catch (e) {
      debugPrint('Error: $e');
      _snack('Error: ${e.toString()}', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───────────────────────── pdf file / share ─────────────────────────

  Future<String> _savePdfToStorage(Uint8List pdfBytes) async {
    try {
      if (Platform.isAndroid) {
        await [Permission.storage, Permission.manageExternalStorage].request();
        final sdk = await DeviceInfoPlugin().androidInfo.then(
          (i) => i.version.sdkInt,
        );
        if (sdk >= 30 && !await Permission.manageExternalStorage.isGranted) {
          await Permission.manageExternalStorage.request();
        }
      }

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

      final dir = Directory('${directory.path}/MobileHouse');
      if (!await dir.exists()) await dir.create(recursive: true);

      final customer = customerNameController.text
          .replaceAll(RegExp(r'[^\w\s-]'), '_')
          .replaceAll(' ', '_');
      final file = File(
        '${dir.path}/MH_RC_${billNoController.text}_$customer.pdf',
      );
      await file.writeAsBytes(pdfBytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/MH_RC_${billNoController.text}.pdf');
      await file.writeAsBytes(pdfBytes, flush: true);
      return file.path;
    }
  }

  Future<void> _sharePdf(File pdfFile) async {
    try {
      if (!await pdfFile.exists()) throw Exception('PDF file not found');
      final fileName = pdfFile.path.split('/').last;
      await Share.shareXFiles(
        [XFile(pdfFile.path, mimeType: 'application/pdf', name: fileName)],
        text: 'Mobile House Bill - ${customerNameController.text}',
        subject: 'Mobile House Bill - $_fullBillNumber',
      );
    } catch (e) {
      _snack('Error sharing PDF: ${e.toString()}', color: Colors.red);
    }
  }

  Future<void> _shareSavedPdf() async {
    if (_savedPdfFile == null || !await _savedPdfFile!.exists()) {
      _snack(
        'No PDF file found. Please create a bill first.',
        color: Colors.orange,
      );
      return;
    }
    await _sharePdf(_savedPdfFile!);
  }

  // ───────────────────────── amount in words ─────────────────────────

  String _amountToWords(String amount) {
    try {
      final value = double.parse(amount);
      if (value == 0) return 'Zero Rupees Only';
      final rupees = value.toInt();
      final paise = ((value - rupees) * 100).round();
      final rupeeWords = _convertNumberToWords(rupees);
      final paiseWords = paise > 0
          ? ' and ${_convertNumberToWords(paise)} Paise'
          : '';
      return '${rupeeWords.trim()} Rupees$paiseWords Only';
    } catch (e) {
      return 'Amount in words conversion failed';
    }
  }

  String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';

    const units = [
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
    const teens = [
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
    const tens = [
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
        if (number % 10 > 0) words += ' ${units[number % 10]}';
      }
    }
    return words.trim();
  }

  // ───────────────────────── PDF ─────────────────────────

  Future<Uint8List> _generateBillPdf() async {
    final pdf = pw.Document();
    final currentDate = DateFormat('dd MMMM yyyy').format(DateTime.now());

    final customerAddress = addressController.text;
    final totalAmount = double.tryParse(totalAmountController.text) ?? 0.0;
    final taxableAmount = double.tryParse(taxableAmountController.text) ?? 0.0;
    final gstAmount = double.tryParse(gstAmountController.text) ?? 0.0;
    final hasAddress = customerAddress.isNotEmpty && customerAddress != 'N/A';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.0),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfHeader(currentDate),
                _pdfCustomerDetails(
                  customerNameController.text,
                  mobileNumberController.text,
                  customerAddress,
                  _selectedPurchaseMode,
                  _selectedFinanceType,
                ),
                pw.SizedBox(height: 4),
                _pdfMainTable(
                  phoneModelController.text,
                  imei1Controller.text,
                  taxableAmount,
                  gstAmount,
                  totalAmount,
                ),
                pw.Container(
                  height: hasAddress ? 250 : 280,
                  child: pw.Stack(
                    children: [
                      if (_sealChecked && _sealImage != null)
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
                _pdfTotalSection(totalAmount, taxableAmount, gstAmount),
                _pdfBottomSection(taxableAmount, gstAmount),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfHeader(String currentDate) {
    return pw.Column(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              'GSTIN: 32BSGPJ3340H1Z4',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (_logoImage != null)
                    pw.SizedBox(
                      height: 50,
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
                  pw.Text(
                    _selectedShop == 'Peringottukara'
                        ? '3way junction Peringottukara'
                        : 'Cherpu, Thayamkulangara',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _selectedShop == 'Peringottukara'
                        ? 'Mob: 9072430483, 8304830868'
                        : 'Mob: 9544466724',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Mobile house',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'GST TAX INVOICE (TYPE-B2C) - CASH SALE',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                    'Invoice No. : $_fullBillNumber',
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

  pw.Widget _pdfCustomerDetails(
    String name,
    String mobile,
    String address,
    String? purchaseMode,
    String? financeType,
  ) {
    final hasAddress = address.isNotEmpty && address != 'N/A';

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: pw.Container(
        padding: const pw.EdgeInsets.all(2),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Customer  : $name',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            if (hasAddress)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Address     :',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Text(
                      address,
                      style: const pw.TextStyle(fontSize: 11),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Mobile Tel  : $mobile',
              style: const pw.TextStyle(fontSize: 11),
            ),
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
                  pw.Text(financeType, style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfMainTable(
    String productName,
    String imei,
    double taxableAmount,
    double gstAmount,
    double totalAmount,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FixedColumnWidth(60),
        3: const pw.FixedColumnWidth(25),
        4: const pw.FixedColumnWidth(50),
        5: const pw.FixedColumnWidth(70),
        6: const pw.FixedColumnWidth(45),
        7: const pw.FixedColumnWidth(50),
        8: const pw.FixedColumnWidth(60),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: [
            _pdfCell('SLNO', isHeader: true),
            _pdfCell('Name of Item/Commodity', isHeader: true),
            _pdfCell('HSNCode', isHeader: true),
            _pdfCell('Qty', isHeader: true),
            _pdfCell(' Rate', isHeader: true),
            _pdfCell(' Discount', isHeader: true),
            _pdfCell('GST%', isHeader: true),
            _pdfCell('GST Amt', isHeader: true),
            _pdfCell('Total ', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _pdfCell('1'),
            _pdfCell('$productName\nIMEI: $imei', fontSize: 11, maxLines: 3),
            _pdfCell('85171300'),
            _pdfCell('1'),
            _pdfCell(taxableAmount.toStringAsFixed(2)),
            _pdfCell('0.00'),
            _pdfCell('18'),
            _pdfCell(gstAmount.toStringAsFixed(2)),
            _pdfCell(totalAmount.toStringAsFixed(2)),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfTotalSection(
    double totalAmount,
    double taxableAmount,
    double gstAmount,
  ) {
    final amountInWords = _amountToWords(totalAmount.toString());
    final bold = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);

    return pw.Column(
      children: [
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.black, thickness: 0.5, height: 0),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total', style: bold),
              pw.Text('1', style: bold),
              pw.Text(taxableAmount.toStringAsFixed(2), style: bold),
              pw.Text(gstAmount.toStringAsFixed(2), style: bold),
              pw.Text(totalAmount.toStringAsFixed(2), style: bold),
            ],
          ),
        ),
        pw.Divider(color: PdfColors.black, thickness: 0.5, height: 0),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'In Words: $amountInWords',
                style: const pw.TextStyle(fontSize: 11),
                maxLines: 2,
              ),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total Amount: ${totalAmount.toStringAsFixed(2)}',
                  style: bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfBottomSection(double taxableAmount, double gstAmount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(2),
              child: _pdfGstBreakdownTable(taxableAmount, gstAmount),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            flex: 1,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
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
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Table _pdfGstBreakdownTable(double taxableAmount, double gstAmount) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FixedColumnWidth(40),
        2: const pw.FixedColumnWidth(40),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: [
            _pdfCell('CGST 9%', isHeader: true, fontSize: 9),
            _pdfCell('SGST 9%', isHeader: true, fontSize: 9),
            _pdfCell('GST 18%', isHeader: true, fontSize: 9),
          ],
        ),
        pw.TableRow(
          children: [
            _pdfCell((gstAmount / 2).toStringAsFixed(2), fontSize: 9),
            _pdfCell((gstAmount / 2).toStringAsFixed(2), fontSize: 9),
            _pdfCell(gstAmount.toStringAsFixed(2), fontSize: 9),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfCell(
    String text, {
    bool isHeader = false,
    double fontSize = 11,
    int maxLines = 1,
  }) {
    final lines = text.split('\n');

    if (maxLines <= 1 || lines.length <= 1) {
      return pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
          textAlign: pw.TextAlign.center,
          maxLines: maxLines,
        ),
      );
    }

    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            lines[0],
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          for (int i = 1; i < lines.length && i < maxLines; i++)
            pw.Text(
              lines[i],
              style: pw.TextStyle(fontSize: fontSize * 0.9),
              textAlign: pw.TextAlign.center,
            ),
        ],
      ),
    );
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isReadOnly = _isSoldSaved && !_isEditMode;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Ready Cash Bill' : 'Ready Cash Bill',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: _isEditMode ? Colors.orange[700] : Colors.green[700],
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_isEditMode) {
              _cancelEdit();
            } else {
              Navigator.pop(context, _isSoldSaved);
            }
          },
        ),
        actions: [
          if (!_isSoldSaved && !_isEditMode)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _isLoading ? null : _regenerateBillNumber,
              tooltip: 'Regenerate Bill Number',
            ),
          if (_savedPdfFile != null && !_isEditMode)
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _shareSavedPdf,
              tooltip: 'Share Last Bill',
            ),
        ],
      ),
      body: _buildForm(isReadOnly),
    );
  }

  Widget _buildForm(bool isReadOnly) {
    final isButtonDisabled = (_isLoading || _isSoldSaved) && !_isEditMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _isEditMode ? Colors.orange[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isEditMode ? Colors.orange[100]! : Colors.blue[100]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt,
                    color: _isEditMode ? Colors.orange[700] : Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Bill Number: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _isEditMode
                          ? Colors.orange[800]
                          : Colors.blue[800],
                    ),
                  ),
                  Text(
                    '$_billPrefix${billNoController.text}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isEditMode
                          ? Colors.orange[900]
                          : Colors.blue[900],
                    ),
                  ),
                  if (!_isSoldSaved && !_isEditMode) const Spacer(),
                  if (!_isSoldSaved && !_isEditMode)
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      onPressed: _isLoading ? null : _regenerateBillNumber,
                      tooltip: 'Regenerate',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildInputCard(isReadOnly),
            const SizedBox(height: 16),
            if (_isSoldSaved && !_isEditMode)
              _bigButton(
                label: 'Edit Bill',
                icon: Icons.edit,
                color: Colors.orange[700]!,
                onPressed: _enableEditMode,
              ),
            if (_isEditMode)
              _bigButton(
                label: _isLoading
                    ? 'Updating...'
                    : 'Update Bill & Save Changes',
                icon: Icons.update,
                color: Colors.orange[700]!,
                loading: _isLoading,
                onPressed: _isLoading ? null : _updateCurrentBill,
              ),
            if (!_isSoldSaved && !_isEditMode)
              _bigButton(
                label: _isLoading
                    ? 'Processing...'
                    : 'Save Bill & Mark as Sold',
                icon: Icons.save,
                color: isButtonDisabled ? Colors.grey : Colors.green[700]!,
                loading: _isLoading,
                onPressed: isButtonDisabled ? null : _saveBillAndMarkSold,
              ),
            const SizedBox(height: 16),
            if (_savedPdfFile != null && !_isEditMode)
              _bigButton(
                label: 'Share Bill Again',
                icon: Icons.share,
                color: Colors.blue[700]!,
                onPressed: _shareSavedPdf,
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _bigButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, size: 22),
          label: Text(label, style: const TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(bool isReadOnly) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildShopDisplay(),
            const SizedBox(height: 12),
            _buildTextField(
              billNoController,
              'Bill No *',
              Icons.receipt,
              validator: _validateRequired,
              readOnly: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              customerNameController,
              'Customer Name *',
              Icons.person,
              validator: _validateRequired,
              readOnly: isReadOnly,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              mobileNumberController,
              'Mobile Number *',
              Icons.phone,
              keyboardType: TextInputType.phone,
              validator: _validateMobile,
              readOnly: isReadOnly,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              phoneModelController,
              'Phone Model *',
              Icons.phone_android,
              readOnly: true,
              validator: _validateRequired,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              imei1Controller,
              'IMEI *',
              Icons.qr_code,
              readOnly: true,
              validator: _validateImei,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              addressController,
              'Address',
              Icons.location_on,
              maxLines: 2,
              readOnly: isReadOnly,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              totalAmountController,
              'Total Amount *',
              Icons.attach_money,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validateAmount,
              readOnly: isReadOnly,
            ),
            const SizedBox(height: 12),
            _buildPurchaseModeDropdown(isReadOnly),
            if (_showFinanceFields) ...[
              const SizedBox(height: 12),
              _buildFinanceTypeDropdown(isReadOnly),
            ],
            const SizedBox(height: 12),
            _buildGstInfoCard(),
            const SizedBox(height: 12),
            _buildSealCheckbox(isReadOnly),
          ],
        ),
      ),
    );
  }

  Widget _buildShopDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green[100]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.store, color: Colors.green[700]),
          const SizedBox(width: 10),
          const Text(
            'Shop:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Text(
            _selectedShop ?? 'Peringottukara',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Auto-set',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseModeDropdown(bool isReadOnly) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(Icons.shopping_cart, color: Colors.green[700]),
          const SizedBox(width: 10),
          const Text(
            'Purchase Mode:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPurchaseMode,
                isExpanded: true,
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                items: _purchaseModes
                    .map(
                      (v) => DropdownMenuItem<String>(
                        value: v,
                        child: Text(v, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: isReadOnly ? null : _onPurchaseModeSelected,
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildFinanceTypeDropdown(bool isReadOnly) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(Icons.account_balance, color: Colors.grey[700]),
          const SizedBox(width: 10),
          const Text(
            'Finance:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFinanceType,
                isExpanded: true,
                hint: const Text(
                  'Select Finance Company',
                  style: TextStyle(fontSize: 13),
                ),
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                items: _financeCompaniesList
                    .map(
                      (v) => DropdownMenuItem<String>(
                        value: v,
                        child: Text(v, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: isReadOnly
                    ? null
                    : (v) => setState(() => _selectedFinanceType = v),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool readOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 14),
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.green),
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
          borderSide: const BorderSide(color: Colors.green),
        ),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[50] : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildGstInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Taxable Amount:', style: TextStyle(fontSize: 13)),
              Text(
                '₹${taxableAmountController.text}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('GST Amount:', style: TextStyle(fontSize: 13)),
              Text(
                '₹${gstAmountController.text}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSealCheckbox(bool isReadOnly) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber[100]!),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _sealChecked,
            onChanged: isReadOnly
                ? null
                : (v) => setState(() => _sealChecked = v ?? false),
            activeColor: Colors.green,
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text('Apply Seal on Bill', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── validators ─────────────────────────

  String? _validateRequired(String? v) =>
      (v == null || v.isEmpty) ? 'This field is required' : null;

  String? _validateMobile(String? v) {
    if (v == null || v.isEmpty) return 'Mobile number is required';
    if (v.length != 10) return 'Enter valid 10-digit mobile number';
    return null;
  }

  String? _validateImei(String? v) {
    if (v == null || v.isEmpty) return 'IMEI is required';
    if (v.length < 15) return 'IMEI must be at least 15 digits';
    return null;
  }

  String? _validateAmount(String? v) {
    if (v == null || v.isEmpty) return 'Total amount is required';
    if (double.tryParse(v) == null) return 'Enter valid amount';
    return null;
  }
}
