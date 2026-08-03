import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../providers/auth_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

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

  // Controllers
  late TextEditingController billNoController;
  late TextEditingController customerNameController;
  late TextEditingController mobileNumberController;
  late TextEditingController phoneModelController;
  late TextEditingController imei1Controller;
  late TextEditingController addressController;
  late TextEditingController totalAmountController;
  late TextEditingController taxableAmountController;
  late TextEditingController gstAmountController;

  // State variables
  bool _isScanning = false;
  bool _sealChecked = false;
  bool _isLoading = false;
  bool _isSoldSaved = false;
  String? _selectedShop = 'Peringottukara';

  // Purchase Mode and Finance Type
  String? _selectedPurchaseMode = 'Ready Cash';
  String? _selectedFinanceType;
  bool _showFinanceFields = false;

  // Edit mode variables
  bool _isEditMode = false;
  String? _currentBillId;

  final List<String> _purchaseModes = ['Ready Cash', 'Credit Card', 'EMI'];
  final List<String> _financeCompaniesList = [
    'Bajaj Finance',
    'TVS Credit',
    'HDB Financial',
    'Samsung Finance',
    'Oppo Finance',
    'Vivo Finance',
    'yoga kshema Finance',
    'MI Finance',
    'First credit private Finance',
    'Chola Murugappa',
    'Other',
  ];

  // Static images - shared across all instances
  static Uint8List? _logoImage;
  static Uint8List? _sealImage;
  static bool _imagesLoaded = false;

  File? _savedPdfFile;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    billNoController = TextEditingController();
    customerNameController = TextEditingController();
    mobileNumberController = TextEditingController();
    phoneModelController = TextEditingController();
    imei1Controller = TextEditingController();
    addressController = TextEditingController();
    totalAmountController = TextEditingController();
    taxableAmountController = TextEditingController();
    gstAmountController = TextEditingController();

    // Initialize data
    _initData();

    // Generate bill number when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateAndSetBillNumber();
    });
  }

  void _initData() async {
    await _requestCameraPermission();
    await _loadImages();

    // Auto set shop based on shop ID
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user?.shopId == 'mG9QgP0dPMP8hGk2yQQO') {
      setState(() {
        _selectedShop = 'Cherpu';
      });
    } else {
      setState(() {
        _selectedShop = 'Peringottukara';
      });
    }

    _autoFillData();
    totalAmountController.addListener(_calculateGST);
  }

  // ==================== BILL NUMBER AUTO-GENERATION ====================

  Future<String> _generateBillNumber() async {
    try {
      final billsQuery = await _firestore
          .collection('bills')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      int nextSequenceNumber = 1;

      if (billsQuery.docs.isNotEmpty) {
        final lastBill = billsQuery.docs.first;
        final lastBillNumber = lastBill['billNumber'] as String? ?? '';

        if (lastBillNumber.startsWith('MH-')) {
          final lastSequenceStr = lastBillNumber.substring(3);
          final lastSequence = int.tryParse(lastSequenceStr) ?? 0;
          nextSequenceNumber = lastSequence + 1;
        }
      }

      return nextSequenceNumber.toString();
    } catch (e) {
      print('Error generating bill number: $e');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return timestamp.toString().substring(timestamp.toString().length - 6);
    }
  }

  Future<void> _generateAndSetBillNumber() async {
    try {
      final billNumber = await _generateBillNumber();
      if (mounted) {
        setState(() {
          billNoController.text = billNumber;
        });
      }
    } catch (e) {
      print('Error setting bill number: $e');
    }
  }

  Future<void> _regenerateBillNumber() async {
    if (_isLoading) return;

    final newBillNumber = await _generateBillNumber();
    setState(() {
      billNoController.text = newBillNumber;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bill number regenerated: MH-$newBillNumber')),
      );
    }
  }

  // ==================== END BILL NUMBER GENERATION ====================

  // ==================== IMEI VALIDATION ====================

  Future<bool> _isImeiAlreadySold(String imei) async {
    try {
      final querySnapshot = await _firestore
          .collection('phoneStock')
          .where('imei', isEqualTo: imei)
          .where('status', isEqualTo: 'sold')
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking IMEI status: $e');
      return false;
    }
  }

  void _showImeiAlreadySoldDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
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
              Text('This product with IMEI:', style: TextStyle(fontSize: 14)),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.all(8),
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
              SizedBox(height: 12),
              Text(
                'has already been marked as SOLD and cannot be sold again.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                'Please check the IMEI number or contact administrator.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'OK',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  // ==================== END IMEI VALIDATION ====================

  // ==================== EDIT CURRENT BILL FUNCTIONALITY ====================

  void _enableEditMode() {
    setState(() {
      _isEditMode = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit mode enabled. Make your changes and save.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit cancelled'), backgroundColor: Colors.orange),
    );
  }

  Future<void> _updateCurrentBill() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_selectedPurchaseMode == 'EMI' && _selectedFinanceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select finance company for EMI')),
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

      await _updateBillRecord();
      await _updatePhoneStockForEdit();

      final pdfBytes = await _generateBillPdf();
      final filePath = await _savePdfToStorage(pdfBytes);

      final pdfFile = File(filePath);
      setState(() {
        _savedPdfFile = pdfFile;
        _isEditMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bill updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        await _sharePdf(pdfFile);
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateBillRecord() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    final billNumber = billNoController.text.startsWith('MH-')
        ? billNoController.text
        : 'MH-${billNoController.text}';

    final updateData = {
      'billNumber': billNumber,
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
      'sealApplied': _sealChecked,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user?.email,
      'purchaseMode': _selectedPurchaseMode,
      'financeType': _selectedFinanceType,
    };

    await _firestore.collection('bills').doc(_currentBillId).update(updateData);
  }

  Future<void> _updatePhoneStockForEdit() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    final billNumber = billNoController.text.startsWith('MH-')
        ? billNoController.text
        : 'MH-${billNoController.text}';

    final imei = imei1Controller.text.trim();
    if (imei.isNotEmpty) {
      final querySnapshot = await _firestore
          .collection('phoneStock')
          .where('imei', isEqualTo: imei)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await _firestore
            .collection('phoneStock')
            .doc(querySnapshot.docs.first.id)
            .update({
              'soldTo': customerNameController.text,
              'soldBillNo': billNumber,
              'soldAmount': double.parse(totalAmountController.text),
              'soldShop': _selectedShop,
              'purchaseMode': _selectedPurchaseMode,
              'financeType': _selectedFinanceType,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
    }
  }

  // ==================== END EDIT CURRENT BILL FUNCTIONALITY ====================

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
      _logoImage = logoByteData.buffer.asUint8List();
      print('Logo loaded successfully, size: ${_logoImage?.length} bytes');
    } catch (e) {
      print('Error loading logo: $e');
    }

    try {
      // Load seal
      final sealByteData = await rootBundle.load('assets/mobileHouseSeal.jpeg');
      _sealImage = sealByteData.buffer.asUint8List();
      print('Seal loaded successfully, size: ${_sealImage?.length} bytes');
    } catch (e) {
      print('Error loading seal: $e');
    }

    _imagesLoaded = true;
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera permission is required for scanning')),
        );
      }
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
    if (barcodes.barcodes.isNotEmpty && mounted) {
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

  Future<void> _markAsSoldAndPrint() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_selectedPurchaseMode == 'EMI' && _selectedFinanceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select finance company for EMI')),
      );
      return;
    }

    if (billNoController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter bill number')));
      return;
    }

    final imei = imei1Controller.text.trim();
    if (imei.isNotEmpty) {
      setState(() => _isLoading = true);

      final isSold = await _isImeiAlreadySold(imei);

      if (isSold) {
        setState(() => _isLoading = false);
        _showImeiAlreadySoldDialog();
        return;
      }
    }

    try {
      setState(() => _isLoading = true);

      await _markPhoneAsSold();
      _currentBillId = await _saveBillRecord();

      final pdfBytes = await _generateBillPdf();
      final filePath = await _savePdfToStorage(pdfBytes);

      final pdfFile = File(filePath);
      setState(() {
        _savedPdfFile = pdfFile;
        _isSoldSaved = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bill created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        await _sharePdf(pdfFile);
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markPhoneAsSold() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    final billNumber = billNoController.text.startsWith('MH-')
        ? billNoController.text
        : 'MH-${billNoController.text}';

    final updateData = {
      'status': 'sold',
      'soldAt': FieldValue.serverTimestamp(),
      'soldTo': customerNameController.text,
      'soldBillNo': billNumber,
      'soldAmount': double.parse(totalAmountController.text),
      'soldShop': _selectedShop,
      'soldBy': user?.email,
      'purchaseMode': _selectedPurchaseMode,
      'financeType': _selectedFinanceType,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.phoneId != null) {
      final phoneDoc = await _firestore
          .collection('phoneStock')
          .doc(widget.phoneId)
          .get();

      if (phoneDoc.exists && phoneDoc.data()?['status'] == 'sold') {
        throw Exception('This product is already marked as sold');
      }

      await _firestore
          .collection('phoneStock')
          .doc(widget.phoneId)
          .update(updateData);
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
          await _firestore
              .collection('phoneStock')
              .doc(querySnapshot.docs.first.id)
              .update(updateData);
        } else {
          final soldCheck = await _firestore
              .collection('phoneStock')
              .where('imei', isEqualTo: imei)
              .where('status', isEqualTo: 'sold')
              .limit(1)
              .get();

          if (soldCheck.docs.isNotEmpty) {
            throw Exception('Product with this IMEI is already sold');
          } else {
            throw Exception(
              'Product with this IMEI not found in available stock',
            );
          }
        }
      }
    }
  }

  Future<String> _saveBillRecord() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    final billNumber = billNoController.text.startsWith('MH-')
        ? billNoController.text
        : 'MH-${billNoController.text}';

    final billData = {
      'billNumber': billNumber,
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
      'purchaseMode': _selectedPurchaseMode,
      'financeType': _selectedFinanceType,
    };

    final docRef = await _firestore.collection('bills').add(billData);
    return docRef.id;
  }

  Future<String> _savePdfToStorage(Uint8List pdfBytes) async {
    try {
      if (Platform.isAndroid) {
        await [Permission.storage, Permission.manageExternalStorage].request();

        if (await Permission.storage.isGranted == false) {
          await Permission.storage.request();
        }

        if (Platform.isAndroid &&
            await DeviceInfoPlugin().androidInfo.then(
                  (info) => info.version.sdkInt,
                ) >=
                30) {
          if (await Permission.manageExternalStorage.isGranted == false) {
            await Permission.manageExternalStorage.request();
          }
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

      final mobileHouseDir = Directory('${directory.path}/MobileHouse');
      if (!await mobileHouseDir.exists()) {
        await mobileHouseDir.create(recursive: true);
      }

      final billNo = billNoController.text;
      final customerName = customerNameController.text
          .replaceAll(RegExp(r'[^\w\s-]'), '_')
          .replaceAll(' ', '_');
      final fileName = 'MH_${billNo}_${customerName}.pdf';

      final filePath = '${mobileHouseDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(pdfBytes, flush: true);

      print('PDF saved at: $filePath');
      return filePath;
    } catch (e) {
      print('Error saving PDF: $e');
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'MH_${billNoController.text}.pdf';
        final filePath = '${appDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes, flush: true);
        return filePath;
      } catch (e2) {
        rethrow;
      }
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
        text: 'Mobile House Bill - ${customerNameController.text}',
        subject: 'Mobile House Bill - MH-${billNoController.text}',
      );
    } catch (e) {
      print('Error sharing PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareSavedPdf() async {
    if (_savedPdfFile == null || !await _savedPdfFile!.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No PDF file found. Please create a bill first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _sharePdf(_savedPdfFile!);
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

  // ==================== PDF GENERATION - MATCHING BILL REPRINT DESIGN ====================

  Future<Uint8List> _generateBillPdf() async {
    final pdf = pw.Document();
    final pageFormat = PdfPageFormat.a4;
    String currentDate = DateFormat('dd MMMM yyyy').format(DateTime.now());

    final billNumber = billNoController.text;
    final customerName = customerNameController.text;
    final customerMobile = mobileNumberController.text;
    final customerAddress = addressController.text;
    final totalAmount = double.tryParse(totalAmountController.text) ?? 0.0;
    final taxableAmount = double.tryParse(taxableAmountController.text) ?? 0.0;
    final gstAmount = double.tryParse(gstAmountController.text) ?? 0.0;

    // Check if address is null or empty
    final bool hasAddress =
        customerAddress.isNotEmpty && customerAddress != 'N/A';

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
                _buildPdfHeader(currentDate, billNumber),
                _buildPdfCustomerDetails(
                  customerName,
                  customerMobile,
                  customerAddress,
                  _selectedPurchaseMode,
                  _selectedFinanceType,
                ),
                pw.SizedBox(height: 4),
                _buildPdfMainTable(
                  phoneModelController.text,
                  imei1Controller.text,
                  taxableAmount,
                  gstAmount,
                  totalAmount,
                ),
                // Conditional container height based on address presence
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
                _buildPdfTotalSection(totalAmount, taxableAmount, gstAmount),
                _buildPdfBottomSection(taxableAmount, gstAmount),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfHeader(String currentDate, String billNumber) {
    final fullBillNumber = billNumber.startsWith('MH-')
        ? billNumber
        : 'MH-$billNumber';

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
                        ? "3way junction Peringottukara"
                        : "Cherpu, Thayamkulangara",
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
                    'Invoice No. : $fullBillNumber',
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
    String? purchaseMode,
    String? financeType,
  ) {
    final bool hasAddress = address.isNotEmpty && address != 'N/A';

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
            if (hasAddress)
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
    String imei,
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
              '$productName\nIMEI: $imei',
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

  pw.Widget _buildPdfBottomSection(double taxableAmount, double gstAmount) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: pw.EdgeInsets.all(2),
              child: _buildPdfGstBreakdownTable(taxableAmount, gstAmount),
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

  pw.Table _buildPdfGstBreakdownTable(double taxableAmount, double gstAmount) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: pw.FixedColumnWidth(40),
        1: pw.FixedColumnWidth(40),
        2: pw.FixedColumnWidth(40),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: [
            _buildPdfTableCell('CGST 9%', isHeader: true, fontSize: 9),
            _buildPdfTableCell('SGST 9%', isHeader: true, fontSize: 9),
            _buildPdfTableCell('GST 18%', isHeader: true, fontSize: 9),
          ],
        ),
        pw.TableRow(
          children: [
            _buildPdfTableCell((gstAmount / 2).toStringAsFixed(2), fontSize: 9),
            _buildPdfTableCell((gstAmount / 2).toStringAsFixed(2), fontSize: 9),
            _buildPdfTableCell(gstAmount.toStringAsFixed(2), fontSize: 9),
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

  // ==================== END PDF GENERATION ====================

  @override
  Widget build(BuildContext context) {
    final bool isReadOnly = _isSoldSaved && !_isEditMode;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Bill' : 'Sales Bill',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: _isEditMode ? Colors.orange[700] : Colors.green[700],
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_isEditMode) {
              _cancelEdit();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (!_isSoldSaved && !_isEditMode)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _isLoading ? null : () => _regenerateBillNumber(),
              tooltip: 'Regenerate Bill Number',
            ),
          if (_savedPdfFile != null && !_isEditMode)
            IconButton(
              icon: Icon(Icons.share, color: Colors.white),
              onPressed: _shareSavedPdf,
              tooltip: 'Share Last Bill',
            ),
        ],
      ),
      body: _isScanning ? _buildScanner() : _buildForm(isReadOnly),
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

  Widget _buildForm(bool isReadOnly) {
    final isButtonDisabled = (_isLoading || _isSoldSaved) && !_isEditMode;

    return SingleChildScrollView(
      padding: EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bill Number Display
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              margin: EdgeInsets.only(bottom: 8),
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
                  SizedBox(width: 8),
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
                    'MH-${billNoController.text}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isEditMode
                          ? Colors.orange[900]
                          : Colors.blue[900],
                    ),
                  ),
                  if (!_isSoldSaved && !_isEditMode) Spacer(),
                  if (!_isSoldSaved && !_isEditMode)
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: _isEditMode
                            ? Colors.orange[700]
                            : Colors.blue[700],
                        size: 20,
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _regenerateBillNumber(),
                      tooltip: 'Regenerate',
                      constraints: BoxConstraints(),
                      padding: EdgeInsets.all(4),
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),
            _buildInputCard(isReadOnly),
            SizedBox(height: 16),

            if (_isSoldSaved && !_isEditMode) _buildEditButton(),

            if (_isEditMode) _buildUpdateButton(),

            if (!_isSoldSaved && !_isEditMode)
              _buildSaveButton(isButtonDisabled),

            SizedBox(height: 16),

            if (_savedPdfFile != null && !_isEditMode) _buildShareButton(),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEditButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _enableEditMode,
          icon: Icon(Icons.edit, size: 22),
          label: Text('Edit Bill', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[700],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _updateCurrentBill,
          icon: _isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.update, size: 22),
          label: Text(
            _isLoading ? 'Updating...' : 'Update Bill & Save Changes',
            style: TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[700],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool isButtonDisabled) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: isButtonDisabled
                ? Colors.grey.withOpacity(0.2)
                : Colors.green.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isButtonDisabled ? null : _markAsSoldAndPrint,
          icon: _isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.save, size: 22),
          label: Text(
            _isLoading ? 'Processing...' : 'Save Bill & Mark as Sold',
            style: TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isButtonDisabled ? Colors.grey : Colors.green[700],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _shareSavedPdf,
          icon: Icon(Icons.share, size: 22),
          label: Text('Share Bill Again', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
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
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildShopDisplay(),
            SizedBox(height: 12),

            _buildTextField(
              billNoController,
              'Bill No *',
              Icons.receipt,
              validator: _validateRequired,
              readOnly: !_isEditMode,
            ),
            SizedBox(height: 12),
            _buildTextField(
              customerNameController,
              'Customer Name *',
              Icons.person,
              validator: _validateRequired,
              readOnly: isReadOnly,
            ),
            SizedBox(height: 12),
            _buildTextField(
              mobileNumberController,
              'Mobile Number *',
              Icons.phone,
              keyboardType: TextInputType.phone,
              validator: _validateMobile,
              readOnly: isReadOnly,
            ),
            SizedBox(height: 12),
            _buildTextField(
              phoneModelController,
              'Phone Model *',
              Icons.phone_android,
              readOnly:
                  (widget.phoneData != null && !_isEditMode) || isReadOnly,
              validator: _validateRequired,
            ),
            SizedBox(height: 12),
            _buildImeiField(isReadOnly),
            SizedBox(height: 12),
            _buildTextField(
              addressController,
              'Address',
              Icons.location_on,
              maxLines: 2,
              readOnly: isReadOnly,
            ),
            SizedBox(height: 12),
            _buildTextField(
              totalAmountController,
              'Total Amount *',
              Icons.attach_money,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) => _calculateGST(),
              validator: _validateAmount,
              readOnly: isReadOnly,
            ),
            SizedBox(height: 12),
            _buildPurchaseModeDropdown(isReadOnly),
            SizedBox(height: 12),
            if (_showFinanceFields) ...[
              SizedBox(height: 12),
              _buildFinanceTypeDropdown(isReadOnly),
            ],
            SizedBox(height: 12),
            _buildGstInfoCard(),
            SizedBox(height: 12),
            _buildSealCheckbox(isReadOnly),
          ],
        ),
      ),
    );
  }

  Widget _buildShopDisplay() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green[100]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.store, color: Colors.green[700]),
          SizedBox(width: 10),
          Text(
            'Shop:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          SizedBox(width: 12),
          Text(
            _selectedShop ?? 'Peringottukara',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
      padding: EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(width: 10),
          Icon(Icons.shopping_cart, color: Colors.green[700]),
          SizedBox(width: 10),
          Text(
            'Purchase Mode:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPurchaseMode,
                isExpanded: true,
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                items: _purchaseModes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: isReadOnly ? null : _onPurchaseModeSelected,
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
              ),
            ),
          ),
          SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildFinanceTypeDropdown(bool isReadOnly) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(width: 10),
          Icon(Icons.account_balance, color: Colors.grey[700]),
          SizedBox(width: 10),
          Text(
            'Finance:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFinanceType,
                isExpanded: true,
                hint: Text(
                  'Select Finance Company',
                  style: TextStyle(fontSize: 13),
                ),
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                items: _financeCompaniesList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: isReadOnly
                    ? null
                    : (String? newValue) =>
                          setState(() => _selectedFinanceType = newValue),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
              ),
            ),
          ),
          SizedBox(width: 10),
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
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(fontSize: 14),
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 14),
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
          borderSide: BorderSide(color: Colors.green),
        ),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[50] : null,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildImeiField(bool isReadOnly) {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            imei1Controller,
            'IMEI *',
            Icons.qr_code,
            readOnly: (widget.phoneData != null && !_isEditMode) || isReadOnly,
            validator: _validateImei,
          ),
        ),
        SizedBox(width: 8),
        if ((widget.phoneData == null || _isEditMode) && !isReadOnly)
          Container(
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: _startScanningIMEI,
              icon: Icon(Icons.qr_code_scanner, color: Colors.white),
              tooltip: 'Scan IMEI',
              padding: EdgeInsets.all(10),
            ),
          ),
      ],
    );
  }

  Widget _buildGstInfoCard() {
    return Container(
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
              Text('Taxable Amount:', style: TextStyle(fontSize: 13)),
              Text(
                '₹${taxableAmountController.text}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GST Amount:', style: TextStyle(fontSize: 13)),
              Text(
                '₹${gstAmountController.text}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSealCheckbox(bool isReadOnly) {
    return Container(
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
            onChanged: isReadOnly
                ? null
                : (value) => setState(() => _sealChecked = value ?? false),
            activeColor: Colors.green,
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text('Apply Seal on Bill', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // Validation methods
  String? _validateRequired(String? value) {
    if (value == null || value.isEmpty) return 'This field is required';
    return null;
  }

  String? _validateMobile(String? value) {
    if (value == null || value.isEmpty) return 'Mobile number is required';
    if (value.length != 10) return 'Enter valid 10-digit mobile number';
    return null;
  }

  String? _validateImei(String? value) {
    if (value == null || value.isEmpty) return 'IMEI is required';
    if (value.length < 15) return 'IMEI must be at least 15 digits';
    return null;
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) return 'Total amount is required';
    if (double.tryParse(value) == null) return 'Enter valid amount';
    return null;
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
