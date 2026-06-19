// lib/screens/admin/reports/bills_report_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import 'dart:typed_data';

class BillsReportScreen extends StatefulWidget {
  final Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;
  final String? initialShopId;
  final String? initialShopName;

  const BillsReportScreen({
    super.key,
    required this.formatNumber,
    required this.shops,
    this.initialShopId,
    this.initialShopName,
  });

  @override
  State<BillsReportScreen> createState() => _BillsReportScreenState();
}

class _BillsReportScreenState extends State<BillsReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allBills = [];
  List<Map<String, dynamic>> _phoneBills = [];
  List<Map<String, dynamic>> _accessoriesBills = [];
  List<Map<String, dynamic>> _tvBills = [];

  // Brand wise data
  Map<String, List<Map<String, dynamic>>> _brandWiseBills = {};
  Map<String, Map<String, dynamic>> _brandStats = {};
  bool _showBrandWise = false;

  // Time period filters
  String _selectedTimePeriod = 'monthly';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isCustomPeriod = false;

  // Shop filter
  String? _selectedShopId;

  // Edit mode variables
  bool _isEditMode = false;
  Map<String, dynamic>? _editingBill;
  final _editFormKey = GlobalKey<FormState>();

  // Edit form controllers
  late TextEditingController _editCustomerNameController;
  late TextEditingController _editMobileController;
  late TextEditingController _editAddressController;
  late TextEditingController _editTotalAmountController;
  late TextEditingController _editTaxableAmountController;
  late TextEditingController _editGstAmountController;
  late TextEditingController _editProductNameController;
  late TextEditingController _editImeiController;
  late TextEditingController _editSerialController;
  String? _editSelectedPurchaseMode;
  String? _editSelectedFinanceType;
  bool _editSealChecked = false;
  bool _isUpdating = false;
  String? _editBillType; // 'phone', 'accessories', 'tv'

  // PDF assets
  Uint8List? _logoImage;
  Uint8List? _sealImage;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryGreen = const Color(0xFF0A4D2E);
  final Color secondaryGreen = const Color(0xFF1A7D4A);
  final Color warningColor = const Color(0xFFFFC107);
  final Color editPrimaryColor = const Color(0xFF2563EB); // Blue for edit mode
  final Color editSecondaryColor = const Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize edit controllers
    _editCustomerNameController = TextEditingController();
    _editMobileController = TextEditingController();
    _editAddressController = TextEditingController();
    _editTotalAmountController = TextEditingController();
    _editTaxableAmountController = TextEditingController();
    _editGstAmountController = TextEditingController();
    _editProductNameController = TextEditingController();
    _editImeiController = TextEditingController();
    _editSerialController = TextEditingController();

    if (widget.initialShopId != null) {
      _selectedShopId = widget.initialShopId;
    }

    _loadImages();
    _fetchAllBills();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _editCustomerNameController.dispose();
    _editMobileController.dispose();
    _editAddressController.dispose();
    _editTotalAmountController.dispose();
    _editTaxableAmountController.dispose();
    _editGstAmountController.dispose();
    _editProductNameController.dispose();
    _editImeiController.dispose();
    _editSerialController.dispose();
    super.dispose();
  }

  // ==================== IMEI COPY FUNCTION ====================
  void _copyImei(String imei) {
    if (imei.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: imei));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('IMEI copied to clipboard: $imei'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadImages() async {
    try {
      final logoByteData = await rootBundle.load('assets/mobileHouseLogo.png');
      _logoImage = logoByteData.buffer.asUint8List();

      final sealByteData = await rootBundle.load('assets/mobileHouseSeal.jpeg');
      _sealImage = sealByteData.buffer.asUint8List();
    } catch (e) {
      print('Error loading images: $e');
    }
  }

  Future<void> _fetchAllBills() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot billsSnapshot = await _firestore
          .collection('bills')
          .orderBy('billDate', descending: true)
          .get();

      _allBills.clear();
      _phoneBills.clear();
      _accessoriesBills.clear();
      _tvBills.clear();

      for (var doc in billsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        final billType = data['billType'] as String?;
        final type = data['type'] as String?;

        _allBills.add(data);

        if (billType == 'GST Accessories') {
          _accessoriesBills.add(data);
        } else if (type == 'tv') {
          _tvBills.add(data);
        } else {
          _phoneBills.add(data);
        }
      }

      _processBrandWiseData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading bills: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _processBrandWiseData() {
    _brandWiseBills.clear();
    _brandStats.clear();

    var filteredPhoneBills = _filterBillsByTimePeriod(_phoneBills);
    filteredPhoneBills = _filterBillsByShop(filteredPhoneBills);

    for (var bill in filteredPhoneBills) {
      String brand = 'Unknown';

      final originalPhoneData = bill['originalPhoneData'];
      if (originalPhoneData != null &&
          originalPhoneData is Map<String, dynamic>) {
        brand = originalPhoneData['productBrand'] ?? 'Unknown';
      } else {
        brand = bill['productBrand'] ?? 'Unknown';
      }

      if (brand.isEmpty || brand == 'null') brand = 'Unknown';

      if (!_brandWiseBills.containsKey(brand)) {
        _brandWiseBills[brand] = [];
      }
      _brandWiseBills[brand]!.add(bill);
    }

    for (var entry in _brandWiseBills.entries) {
      final brand = entry.key;
      final bills = entry.value;

      final totalAmount = _calculateTotalAmount(bills);
      final totalTaxable = _calculateTotalTaxableAmount(bills);
      final totalGst = _calculateTotalGstAmount(bills);
      final totalBills = bills.length;

      _brandStats[brand] = {
        'totalAmount': totalAmount,
        'totalTaxable': totalTaxable,
        'totalGst': totalGst,
        'totalBills': totalBills,
      };
    }
  }

  List<Map<String, dynamic>> _filterBillsByTimePeriod(
    List<Map<String, dynamic>> bills,
  ) {
    return bills.where((bill) {
      DateTime billDate;
      if (bill['billDate'] is Timestamp) {
        billDate = (bill['billDate'] as Timestamp).toDate();
      } else if (bill['createdAt'] is Timestamp) {
        billDate = (bill['createdAt'] as Timestamp).toDate();
      } else {
        billDate = DateTime.now();
      }

      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      if (_isCustomPeriod &&
          _customStartDate != null &&
          _customEndDate != null) {
        startDate = DateTime(
          _customStartDate!.year,
          _customStartDate!.month,
          _customStartDate!.day,
          0,
          0,
          0,
        );
        endDate = DateTime(
          _customEndDate!.year,
          _customEndDate!.month,
          _customEndDate!.day,
          23,
          59,
          59,
          999,
        );
      } else {
        switch (_selectedTimePeriod) {
          case 'today':
            startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
            endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
            break;
          case 'yesterday':
            final yesterday = now.subtract(Duration(days: 1));
            startDate = DateTime(
              yesterday.year,
              yesterday.month,
              yesterday.day,
              0,
              0,
              0,
            );
            endDate = DateTime(
              yesterday.year,
              yesterday.month,
              yesterday.day,
              23,
              59,
              59,
              999,
            );
            break;
          case 'monthly':
            startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
            endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
            break;
          case 'last_month':
            startDate = DateTime(now.year, now.month - 1, 1, 0, 0, 0);
            endDate = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
            break;
          case 'yearly':
            startDate = DateTime(now.year, 1, 1, 0, 0, 0);
            endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);
            break;
          case 'last_year':
            startDate = DateTime(now.year - 1, 1, 1, 0, 0, 0);
            endDate = DateTime(now.year - 1, 12, 31, 23, 59, 59, 999);
            break;
          default:
            startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
            endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        }
      }

      final normalizedDate = DateTime(
        billDate.year,
        billDate.month,
        billDate.day,
      );
      final normalizedStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

      bool isInRange =
          normalizedDate.isAfter(normalizedStart.subtract(Duration(days: 1))) &&
          normalizedDate.isBefore(normalizedEnd.add(Duration(days: 1)));

      return isInRange;
    }).toList();
  }

  List<Map<String, dynamic>> _filterBillsByShop(
    List<Map<String, dynamic>> bills,
  ) {
    if (_selectedShopId == null || _selectedShopId!.isEmpty) {
      return bills;
    }

    return bills.where((bill) {
      final billShopId = bill['shopId'] as String?;
      return billShopId == _selectedShopId;
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredPhoneBills() {
    var bills = _filterBillsByTimePeriod(_phoneBills);
    bills = _filterBillsByShop(bills);
    return bills;
  }

  List<Map<String, dynamic>> _getFilteredAccessoriesBills() {
    var bills = _filterBillsByTimePeriod(_accessoriesBills);
    bills = _filterBillsByShop(bills);
    return bills;
  }

  List<Map<String, dynamic>> _getFilteredTvBills() {
    var bills = _filterBillsByTimePeriod(_tvBills);
    bills = _filterBillsByShop(bills);
    return bills;
  }

  double _calculateTotalAmount(List<Map<String, dynamic>> bills) {
    return bills.fold(0.0, (sum, bill) {
      final totalAmount = bill['totalAmount'] as num?;
      return sum + (totalAmount?.toDouble() ?? 0.0);
    });
  }

  double _calculateTotalTaxableAmount(List<Map<String, dynamic>> bills) {
    return bills.fold(0.0, (sum, bill) {
      final taxableAmount = bill['taxableAmount'] as num?;
      return sum + (taxableAmount?.toDouble() ?? 0.0);
    });
  }

  double _calculateTotalGstAmount(List<Map<String, dynamic>> bills) {
    return bills.fold(0.0, (sum, bill) {
      final gstAmount = bill['gstAmount'] as num?;
      return sum + (gstAmount?.toDouble() ?? 0.0);
    });
  }

  // ==================== EDIT BILL FUNCTIONALITY FOR ALL TYPES ====================

  void _startEditBill(Map<String, dynamic> bill) {
    // Determine bill type
    final billType = bill['billType'] as String?;
    final type = bill['type'] as String?;

    if (billType == 'GST Accessories') {
      _editBillType = 'accessories';
    } else if (type == 'tv') {
      _editBillType = 'tv';
    } else {
      _editBillType = 'phone';
    }

    // Get product details
    String productName = '';
    String imei = '';
    String serialNumber = '';

    if (_editBillType == 'phone') {
      final originalPhoneData = bill['originalPhoneData'];
      if (originalPhoneData != null &&
          originalPhoneData is Map<String, dynamic>) {
        productName =
            originalPhoneData['productName'] ?? bill['productName'] ?? '';
      } else {
        productName = bill['productName'] ?? '';
      }
      imei = bill['imei'] ?? '';
      if (originalPhoneData != null &&
          originalPhoneData is Map<String, dynamic>) {
        if (imei.isEmpty) imei = originalPhoneData['imei'] ?? '';
      }
    } else if (_editBillType == 'tv') {
      final originalTvData = bill['originalTvData'];
      if (originalTvData != null && originalTvData is Map<String, dynamic>) {
        productName =
            originalTvData['modelName'] ??
            bill['modelName'] ??
            bill['productName'] ??
            '';
      } else {
        productName = bill['modelName'] ?? bill['productName'] ?? '';
      }
      serialNumber = bill['serialNumber'] ?? '';
      if (originalTvData != null && originalTvData is Map<String, dynamic>) {
        if (serialNumber.isEmpty)
          serialNumber = originalTvData['serialNumber'] ?? '';
      }
    } else {
      // Accessories
      productName = bill['productName'] ?? '';
      imei = bill['imei'] ?? '';
    }

    setState(() {
      _editingBill = bill;
      _isEditMode = true;

      // Populate controllers
      _editCustomerNameController.text = bill['customerName'] ?? '';
      _editMobileController.text = bill['customerMobile'] ?? '';
      _editAddressController.text = bill['customerAddress'] ?? '';
      _editTotalAmountController.text =
          (bill['totalAmount'] as num?)?.toString() ?? '0';
      _editTaxableAmountController.text =
          (bill['taxableAmount'] as num?)?.toString() ?? '0';
      _editGstAmountController.text =
          (bill['gstAmount'] as num?)?.toString() ?? '0';
      _editProductNameController.text = productName;
      _editImeiController.text = imei;
      _editSerialController.text = serialNumber;
      _editSelectedPurchaseMode = bill['purchaseMode'] ?? 'Ready Cash';
      _editSelectedFinanceType = bill['financeType'];
      _editSealChecked = bill['sealApplied'] == true;
    });
  }

  void _calculateEditGST() {
    if (_editTotalAmountController.text.isNotEmpty) {
      try {
        double totalAmount = double.parse(_editTotalAmountController.text);
        double gstPercent = 18.0;
        double taxableAmount = totalAmount / (1 + gstPercent / 100);
        double gstAmount = totalAmount - taxableAmount;

        setState(() {
          _editTaxableAmountController.text = taxableAmount.toStringAsFixed(2);
          _editGstAmountController.text = gstAmount.toStringAsFixed(2);
        });
      } catch (e) {
        setState(() {
          _editTaxableAmountController.text = '';
          _editGstAmountController.text = '';
        });
      }
    } else {
      setState(() {
        _editTaxableAmountController.text = '';
        _editGstAmountController.text = '';
      });
    }
  }

  Future<void> _updateBill() async {
    if (!_editFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      final updateData = {
        'customerName': _editCustomerNameController.text,
        'customerMobile': _editMobileController.text,
        'customerAddress': _editAddressController.text,
        'totalAmount': double.parse(_editTotalAmountController.text),
        'taxableAmount': double.parse(_editTaxableAmountController.text),
        'gstAmount': double.parse(_editGstAmountController.text),
        'purchaseMode': _editSelectedPurchaseMode,
        'financeType': _editSelectedFinanceType,
        'sealApplied': _editSealChecked,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user?.email,
      };

      // Add type-specific fields
      if (_editBillType == 'phone') {
        updateData['productName'] = _editProductNameController.text;
        updateData['imei'] = _editImeiController.text;
      } else if (_editBillType == 'tv') {
        updateData['modelName'] = _editProductNameController.text;
        updateData['serialNumber'] = _editSerialController.text;
        updateData['productName'] = _editProductNameController.text;
      } else {
        updateData['productName'] = _editProductNameController.text;
        if (_editImeiController.text.isNotEmpty) {
          updateData['imei'] = _editImeiController.text;
        }
      }

      await _firestore
          .collection('bills')
          .doc(_editingBill!['id'])
          .update(updateData);

      // Update phone stock if phone bill
      if (_editBillType == 'phone') {
        final imei = _editImeiController.text.trim();
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
                  'soldTo': _editCustomerNameController.text,
                  'soldAmount': double.parse(_editTotalAmountController.text),
                  'purchaseMode': _editSelectedPurchaseMode,
                  'financeType': _editSelectedFinanceType,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
          }
        }
      }

      // Update TV stock if TV bill
      if (_editBillType == 'tv') {
        final serialNumber = _editSerialController.text.trim();
        if (serialNumber.isNotEmpty) {
          final querySnapshot = await _firestore
              .collection('tvStock')
              .where('serialNumber', isEqualTo: serialNumber)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            await _firestore
                .collection('tvStock')
                .doc(querySnapshot.docs.first.id)
                .update({
                  'soldTo': _editCustomerNameController.text,
                  'soldAmount': double.parse(_editTotalAmountController.text),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
          }
        }
      }

      // Refresh bills list
      await _fetchAllBills();

      setState(() {
        _isEditMode = false;
        _editingBill = null;
        _isUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bill updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating bill: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
      _editingBill = null;
      _editBillType = null;
    });
  }

  // ==================== PDF GENERATION ====================

  Future<void> _printAndShareBill(Map<String, dynamic> bill) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final pdfBytes = await _generateBillPdf(bill);
      final filePath = await _savePdfToStorage(pdfBytes, bill);
      final pdfFile = File(filePath);

      setState(() {
        _isLoading = false;
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
      setState(() {
        _isLoading = false;
      });
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
                      if (sealApplied && _sealImage != null)
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

  Future<void> _printPdf(File pdfFile) async {
    try {
      await Share.shareXFiles([
        XFile(pdfFile.path, mimeType: 'application/pdf'),
      ], text: 'Print Mobile House Bill');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==================== UI METHODS ====================

  Future<void> _showCustomDateRangePicker() async {
    DateTime startDate =
        _customStartDate ?? DateTime.now().subtract(Duration(days: 30));
    DateTime endDate = _customEndDate ?? DateTime.now();

    final DateTime? pickedStartDate = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: endDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: secondaryGreen,
            colorScheme: ColorScheme.light(primary: secondaryGreen),
          ),
          child: child!,
        );
      },
    );

    if (pickedStartDate == null) return;

    final DateTime? pickedEndDate = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: pickedStartDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: secondaryGreen,
            colorScheme: ColorScheme.light(primary: secondaryGreen),
          ),
          child: child!,
        );
      },
    );

    if (pickedEndDate == null) return;

    setState(() {
      _customStartDate = pickedStartDate;
      _customEndDate = pickedEndDate;
      _isCustomPeriod = true;
      _selectedTimePeriod = 'custom';
      _processBrandWiseData();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedShopId = null;
      _customStartDate = null;
      _customEndDate = null;
      _isCustomPeriod = false;
      _selectedTimePeriod = 'monthly';
      _processBrandWiseData();
    });
  }

  String _getPeriodLabel() {
    if (_isCustomPeriod) {
      return 'Custom Range';
    }

    switch (_selectedTimePeriod) {
      case 'today':
        return 'Today';
      case 'yesterday':
        return 'Yesterday';
      case 'monthly':
        return 'This Month';
      case 'last_month':
        return 'Last Month';
      case 'yearly':
        return 'This Year';
      case 'last_year':
        return 'Last Year';
      default:
        return 'This Month';
    }
  }

  String _getPeriodDateRange() {
    final now = DateTime.now();

    if (_isCustomPeriod && _customStartDate != null && _customEndDate != null) {
      return '${DateFormat('dd MMM yyyy').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}';
    }

    switch (_selectedTimePeriod) {
      case 'today':
        return DateFormat('dd MMM yyyy').format(now);
      case 'yesterday':
        final yesterday = now.subtract(Duration(days: 1));
        return DateFormat('dd MMM yyyy').format(yesterday);
      case 'monthly':
        return DateFormat('MMMM yyyy').format(now);
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        return DateFormat('MMMM yyyy').format(lastMonth);
      case 'yearly':
        return 'Year ${now.year}';
      case 'last_year':
        return 'Year ${now.year - 1}';
      default:
        return DateFormat('MMMM yyyy').format(now);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredPhoneBills = _getFilteredPhoneBills();
    final filteredAccessoriesBills = _getFilteredAccessoriesBills();
    final filteredTvBills = _getFilteredTvBills();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Bill' : 'Bills Report',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: _isEditMode ? 16 : 18,
          ),
        ),
        backgroundColor: _isEditMode ? editPrimaryColor : primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        leading: _isEditMode
            ? IconButton(icon: Icon(Icons.arrow_back), onPressed: _cancelEdit)
            : null,
        bottom: _isEditMode
            ? null
            : TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_android, size: 18),
                        SizedBox(width: 6),
                        Text('Phone '),
                        Container(
                          margin: EdgeInsets.only(left: 6),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${filteredPhoneBills.length}',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag, size: 18),
                        SizedBox(width: 6),
                        Text(' Accessories'),
                        Container(
                          margin: EdgeInsets.only(left: 6),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${filteredAccessoriesBills.length}',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tv, size: 18),
                        SizedBox(width: 6),
                        Text('TV '),
                        Container(
                          margin: EdgeInsets.only(left: 6),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${filteredTvBills.length}',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
              ),
        actions: _isEditMode
            ? []
            : [
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _fetchAllBills,
                  tooltip: 'Refresh',
                ),
              ],
      ),
      body: _isEditMode
          ? _buildEditForm()
          : _buildMainContent(
              filteredPhoneBills,
              filteredAccessoriesBills,
              filteredTvBills,
            ),
    );
  }

  Widget _buildMainContent(
    List<Map<String, dynamic>> filteredPhoneBills,
    List<Map<String, dynamic>> filteredAccessoriesBills,
    List<Map<String, dynamic>> filteredTvBills,
  ) {
    return Column(
      children: [
        _buildTimePeriodSelector(),
        SizedBox(height: 8),
        _buildFilterBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPhoneBillsContent(filteredPhoneBills),
              _buildBillsList(
                filteredAccessoriesBills,
                'GST Accessories Bills',
                true,
              ),
              _buildBillsList(filteredTvBills, 'TV Bills', true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimePeriodSelector() {
    final List<Map<String, dynamic>> periodOptions = [
      {'value': 'today', 'label': 'Today', 'icon': Icons.today},
      {'value': 'yesterday', 'label': 'Yesterday', 'icon': Icons.history},
      {
        'value': 'monthly',
        'label': 'This Month',
        'icon': Icons.calendar_view_month,
      },
      {
        'value': 'last_month',
        'label': 'Last Month',
        'icon': Icons.calendar_month,
      },
      {'value': 'yearly', 'label': 'This Year', 'icon': Icons.calendar_today},
      {
        'value': 'last_year',
        'label': 'Last Year',
        'icon': Icons.calendar_view_week,
      },
      {'value': 'custom', 'label': 'Custom Range', 'icon': Icons.date_range},
    ];

    return Container(
      padding: EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Time Period',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryGreen,
            ),
          ),
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: periodOptions.map((option) {
                bool isSelected = _isCustomPeriod
                    ? option['value'] == 'custom'
                    : _selectedTimePeriod == option['value'];

                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      option['label'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (option['value'] == 'custom') {
                        _showCustomDateRangePicker();
                      } else {
                        setState(() {
                          _selectedTimePeriod = option['value'];
                          _isCustomPeriod = false;
                          _processBrandWiseData();
                        });
                      }
                    },
                    avatar: Icon(
                      option['icon'],
                      size: 16,
                      color: isSelected ? Colors.white : primaryGreen,
                    ),
                    backgroundColor: Colors.grey[100],
                    selectedColor: primaryGreen,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: StadiumBorder(),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_isCustomPeriod &&
              _customStartDate != null &&
              _customEndDate != null)
            Container(
              margin: EdgeInsets.only(top: 8),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: secondaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.date_range, size: 14, color: secondaryGreen),
                  SizedBox(width: 6),
                  Text(
                    '${DateFormat('dd MMM yyyy').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _selectedShopId,
              decoration: InputDecoration(
                labelText: 'Filter by Shop',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(
                    'All Shops',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                ...widget.shops.map((shop) {
                  return DropdownMenuItem(
                    value: shop['id'],
                    child: Text(
                      shop['name'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedShopId = value;
                  _processBrandWiseData();
                });
              },
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.clear, color: Colors.red),
            onPressed: _resetFilters,
            tooltip: 'Reset Filters',
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneBillsContent(List<Map<String, dynamic>> bills) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Bill List'),
                      icon: Icon(Icons.list, size: 16),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Brand Wise'),
                      icon: Icon(Icons.branding_watermark, size: 16),
                    ),
                  ],
                  selected: {_showBrandWise},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _showBrandWise = newSelection.first;
                      _processBrandWiseData();
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return primaryGreen;
                      }
                      return Colors.grey[200];
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return Colors.grey[700];
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _showBrandWise
              ? _buildBrandWiseReport()
              : _buildBillsList(bills, 'Phone Bills', true),
        ),
      ],
    );
  }

  Widget _buildBrandWiseReport() {
    final sortedBrands = _brandStats.entries.toList()
      ..sort((a, b) {
        final aAmount = (a.value['totalAmount'] as double?) ?? 0.0;
        final bAmount = (b.value['totalAmount'] as double?) ?? 0.0;
        return bAmount.compareTo(aAmount);
      });

    final totalAllAmount = _brandStats.values.fold(0.0, (sum, stat) {
      return sum + ((stat['totalAmount'] as double?) ?? 0.0);
    });
    final totalAllTaxable = _brandStats.values.fold(0.0, (sum, stat) {
      return sum + ((stat['totalTaxable'] as double?) ?? 0.0);
    });
    final totalAllGst = _brandStats.values.fold(0.0, (sum, stat) {
      return sum + ((stat['totalGst'] as double?) ?? 0.0);
    });
    final totalAllBills = _brandStats.values.fold(0, (sum, stat) {
      return sum + ((stat['totalBills'] as int?) ?? 0);
    });

    if (sortedBrands.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No phone bills found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Try changing your filters',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(12),
      children: [
        _buildOverallSummaryCard(
          totalAllAmount,
          totalAllTaxable,
          totalAllGst,
          totalAllBills,
        ),
        SizedBox(height: 12),
        ...sortedBrands.map((entry) {
          final brand = entry.key;
          final stats = entry.value;
          return _buildBrandCard(
            brand,
            stats['totalAmount'] as double? ?? 0.0,
            stats['totalTaxable'] as double? ?? 0.0,
            stats['totalGst'] as double? ?? 0.0,
            stats['totalBills'] as int? ?? 0,
            _brandWiseBills[brand] ?? [],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildOverallSummaryCard(
    double totalAmount,
    double totalTaxable,
    double totalGst,
    int count,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryGreen, secondaryGreen],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getPeriodLabel(),
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    _getPeriodDateRange(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Text(
                'Total Bills: $count',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(color: Colors.white24, height: 1),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Taxable Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '₹${widget.formatNumber(totalTaxable)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'GST Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '₹${widget.formatNumber(totalGst)}',
                      style: TextStyle(
                        color: warningColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Sales',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '₹${widget.formatNumber(totalAmount)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandCard(
    String brand,
    double totalAmount,
    double totalTaxable,
    double totalGst,
    int billCount,
    List<Map<String, dynamic>> bills,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          _showBrandDetailsDialog(brand, bills);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.branding_watermark,
                      size: 24,
                      color: primaryGreen,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brand,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                        Text(
                          '$billCount bills',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${widget.formatNumber(totalAmount)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: secondaryGreen,
                        ),
                      ),
                      Text(
                        'Total Sales',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12),
              Divider(height: 1),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '₹${widget.formatNumber(totalTaxable)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          'Taxable',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.grey[300]),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '₹${widget.formatNumber(totalGst)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: warningColor,
                          ),
                        ),
                        Text(
                          'GST',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.grey[300]),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          totalTaxable > 0
                              ? '${((totalGst / totalTaxable) * 100).toStringAsFixed(1)}%'
                              : '0%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryGreen,
                          ),
                        ),
                        Text(
                          'Avg GST Rate',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBrandDetailsDialog(String brand, List<Map<String, dynamic>> bills) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.branding_watermark, color: primaryGreen),
                        SizedBox(width: 8),
                        Text(
                          brand,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(),
                SizedBox(height: 8),
                Text(
                  'Bill Details (${bills.length} bills)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      return _buildBillItem(bill);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBillItem(Map<String, dynamic> bill) {
    final billDate = bill['billDate'] is Timestamp
        ? (bill['billDate'] as Timestamp).toDate()
        : (bill['createdAt'] is Timestamp
              ? (bill['createdAt'] as Timestamp).toDate()
              : DateTime.now());

    final totalAmount = (bill['totalAmount'] as num?)?.toDouble() ?? 0.0;

    String productName = '';
    final originalPhoneData = bill['originalPhoneData'];
    if (originalPhoneData != null &&
        originalPhoneData is Map<String, dynamic>) {
      productName =
          originalPhoneData['productName'] ?? bill['productName'] ?? 'N/A';
    } else {
      productName = bill['productName'] ?? 'N/A';
    }

    String imei = bill['imei'] ?? '';
    if (originalPhoneData != null &&
        originalPhoneData is Map<String, dynamic>) {
      if (imei.isEmpty) {
        imei = originalPhoneData['imei'] ?? '';
      }
    }

    bool isPhoneBill =
        bill['type'] != 'tv' && bill['billType'] != 'GST Accessories';

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          _showBillDetailsDialog(bill);
        },
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bill['billNumber'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                  ),
                  Text(
                    '₹${widget.formatNumber(totalAmount)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: secondaryGreen,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                productName,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person, size: 10, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Text(
                    bill['customerName'] ?? 'N/A',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  SizedBox(width: 12),
                  Icon(Icons.phone, size: 10, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Text(
                    bill['customerMobile'] ?? 'N/A',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.qr_code, size: 10, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'IMEI: ${imei.isNotEmpty ? imei : 'N/A'}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isPhoneBill && imei.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.copy, size: 14, color: Colors.blue),
                      onPressed: () => _copyImei(imei),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      splashRadius: 16,
                    ),
                  SizedBox(width: 12),
                  Icon(Icons.calendar_today, size: 10, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy').format(billDate),
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillsList(
    List<Map<String, dynamic>> bills,
    String title,
    bool showEditOption,
  ) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryGreen),
            SizedBox(height: 16),
            Text('Loading bills...'),
          ],
        ),
      );
    }

    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No bills found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Try changing your filters',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final totalAmount = _calculateTotalAmount(bills);
    final totalTaxable = _calculateTotalTaxableAmount(bills);
    final totalGst = _calculateTotalGstAmount(bills);

    return Column(
      children: [
        _buildSummaryCard(totalAmount, totalTaxable, totalGst, bills.length),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              return _buildBillCard(bill, showEditOption);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    double totalAmount,
    double totalTaxable,
    double totalGst,
    int count,
  ) {
    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryGreen, secondaryGreen],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getPeriodLabel(),
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    _getPeriodDateRange(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Text(
                'Total Bills: $count',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(color: Colors.white24, height: 1),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Taxable Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '₹${widget.formatNumber(totalTaxable)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'GST Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '₹${widget.formatNumber(totalGst)}',
                      style: TextStyle(
                        color: warningColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '₹${widget.formatNumber(totalAmount)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== UPDATED BILL CARD WITH IMEI COPY ====================
  Widget _buildBillCard(Map<String, dynamic> bill, bool showEditOption) {
    final billDate = bill['billDate'] is Timestamp
        ? (bill['billDate'] as Timestamp).toDate()
        : (bill['createdAt'] is Timestamp
              ? (bill['createdAt'] as Timestamp).toDate()
              : DateTime.now());

    final totalAmount = (bill['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final taxableAmount = (bill['taxableAmount'] as num?)?.toDouble() ?? 0.0;
    final gstAmount = (bill['gstAmount'] as num?)?.toDouble() ?? 0.0;
    final gstRate = (bill['gstRate'] as num?)?.toDouble() ?? 0.0;
    final sealApplied = bill['sealApplied'] == true;

    String productName = '';
    final product = bill['product'];
    final billType = bill['billType'] as String?;
    final type = bill['type'] as String?;
    final isTvBill = type == 'tv';
    final isAccessoriesBill = billType == 'GST Accessories';
    final isPhoneBill = !isTvBill && !isAccessoriesBill;

    if (product != null && product is Map<String, dynamic>) {
      productName = product['productName'] ?? bill['productName'] ?? 'N/A';
    } else {
      if (isTvBill) {
        productName = bill['modelName'] ?? bill['productName'] ?? 'N/A';
      } else {
        productName = bill['productName'] ?? 'N/A';
      }
    }

    final originalTvData = bill['originalTvData'];
    String serialNumber = bill['serialNumber'] ?? '';

    if (originalTvData != null && originalTvData is Map<String, dynamic>) {
      if (serialNumber.isEmpty) {
        serialNumber = originalTvData['serialNumber'] ?? '';
      }
      if (productName == 'N/A' || productName.isEmpty) {
        productName = originalTvData['modelName'] ?? bill['modelName'] ?? 'N/A';
      }
    }

    final originalPhoneData = bill['originalPhoneData'];
    String imei = bill['imei'] ?? '';

    if (originalPhoneData != null &&
        originalPhoneData is Map<String, dynamic>) {
      if (imei.isEmpty) {
        imei = originalPhoneData['imei'] ?? '';
      }
    }

    final identifier = isTvBill ? 'Serial' : 'IMEI';
    final identifierValue = isTvBill ? serialNumber : imei;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              _showBillDetailsDialog(bill);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isTvBill
                                    ? Icons.tv
                                    : isAccessoriesBill
                                    ? Icons.shopping_bag
                                    : Icons.phone_android,
                                size: 18,
                                color: primaryGreen,
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bill['billNumber'] ?? 'N/A',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: primaryGreen,
                                    ),
                                  ),
                                  Text(
                                    productName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${widget.formatNumber(totalAmount)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: secondaryGreen,
                            ),
                          ),
                          if (sealApplied)
                            Container(
                              margin: EdgeInsets.only(top: 4),
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: warningColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Seal Applied',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: warningColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Divider(height: 1),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(
                          Icons.person,
                          bill['customerName'] ?? 'N/A',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoChip(
                          Icons.phone,
                          bill['customerMobile'] ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(
                          Icons.store,
                          bill['shopName'] ?? bill['shop'] ?? 'N/A',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoChip(
                          Icons.calendar_today,
                          DateFormat('dd MMM yyyy, hh:mm a').format(billDate),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  // IMEI/Serial Number with Copy Button
                  if (identifierValue.isNotEmpty && !isAccessoriesBill) ...[
                    SizedBox(height: 6),
                    Row(
                      children: [
                        _buildInfoChip(
                          isTvBill ? Icons.confirmation_number : Icons.qr_code,
                          '$identifier: $identifierValue',
                          fontSize: 10,
                        ),
                        if (isPhoneBill && imei.isNotEmpty) ...[
                          SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _copyImei(imei),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.copy,
                                    size: 12,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'Copy',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (gstRate > 0) ...[
                    SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildInfoChip(
                          Icons.calculate,
                          'GST: ${gstRate.toStringAsFixed(0)}%',
                          fontSize: 10,
                        ),
                        _buildInfoChip(
                          Icons.currency_rupee,
                          'Taxable: ₹${widget.formatNumber(taxableAmount)}',
                          fontSize: 10,
                        ),
                        _buildInfoChip(
                          Icons.account_balance_wallet,
                          'GST: ₹${widget.formatNumber(gstAmount)}',
                          fontSize: 10,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showEditOption)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _printAndShareBill(bill),
                      icon: Icon(Icons.print, size: 18, color: Colors.blue),
                      label: Text(
                        'Print/Share',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  Container(height: 25, width: 1, color: Colors.grey[200]),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _startEditBill(bill),
                      icon: Icon(Icons.edit, size: 18, color: editPrimaryColor),
                      label: Text('Edit', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: editPrimaryColor,
                        padding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String text, {
    double fontSize = 10,
    Color? color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color ?? Colors.grey[600]),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              color: color ?? Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showBillDetailsDialog(Map<String, dynamic> bill) {
    final billDate = bill['billDate'] is Timestamp
        ? (bill['billDate'] as Timestamp).toDate()
        : (bill['createdAt'] is Timestamp
              ? (bill['createdAt'] as Timestamp).toDate()
              : DateTime.now());

    final totalAmount = (bill['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final taxableAmount = (bill['taxableAmount'] as num?)?.toDouble() ?? 0.0;
    final gstAmount = (bill['gstAmount'] as num?)?.toDouble() ?? 0.0;
    final gstRate = (bill['gstRate'] as num?)?.toDouble() ?? 0.0;

    final product = bill['product'];
    String productName = '';
    int quantity = 1;
    double productPrice = 0.0;
    double productDiscount = 0.0;

    final billType = bill['billType'] as String?;
    final type = bill['type'] as String?;
    final isTvBill = type == 'tv';
    final isAccessoriesBill = billType == 'GST Accessories';
    final isPhoneBill = !isTvBill && !isAccessoriesBill;

    if (product != null && product is Map<String, dynamic>) {
      productName = product['productName'] ?? bill['productName'] ?? 'N/A';
      quantity = (product['quantity'] as num?)?.toInt() ?? 1;
      productPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
      productDiscount = (product['discount'] as num?)?.toDouble() ?? 0.0;
    } else {
      if (isTvBill) {
        productName = bill['modelName'] ?? bill['productName'] ?? 'N/A';
      } else {
        productName = bill['productName'] ?? 'N/A';
      }
      quantity = (bill['quantity'] as num?)?.toInt() ?? 1;
      productPrice = (bill['price'] as num?)?.toDouble() ?? 0.0;
    }

    final originalTvData = bill['originalTvData'];
    String serialNumber = bill['serialNumber'] ?? '';

    if (originalTvData != null && originalTvData is Map<String, dynamic>) {
      if (serialNumber.isEmpty) {
        serialNumber = originalTvData['serialNumber'] ?? '';
      }
      if (productName == 'N/A' || productName.isEmpty) {
        productName = originalTvData['modelName'] ?? bill['modelName'] ?? 'N/A';
      }
    }

    final originalPhoneData = bill['originalPhoneData'];
    String imei = bill['imei'] ?? '';

    if (originalPhoneData != null &&
        originalPhoneData is Map<String, dynamic>) {
      if (imei.isEmpty) {
        imei = originalPhoneData['imei'] ?? '';
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(16),
            constraints: BoxConstraints(maxHeight: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isTvBill
                              ? Icons.tv
                              : isAccessoriesBill
                              ? Icons.shopping_bag
                              : Icons.phone_android,
                          color: primaryGreen,
                        ),
                        SizedBox(width: 8),
                        Text(
                          bill['billNumber'] ?? 'Bill Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          'Customer',
                          bill['customerName'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Mobile',
                          bill['customerMobile'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Address',
                          bill['customerAddress'] ?? 'N/A',
                        ),
                        SizedBox(height: 8),
                        _buildDetailRow(
                          'Shop',
                          bill['shopName'] ?? bill['shop'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Created By',
                          bill['createdByName'] ?? bill['createdBy'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Date',
                          DateFormat('dd MMM yyyy, hh:mm a').format(billDate),
                        ),
                        SizedBox(height: 8),
                        Divider(),
                        SizedBox(height: 8),
                        Text(
                          'Product Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 6),
                        _buildDetailRow('Product', productName),
                        _buildDetailRow('Quantity', quantity.toString()),
                        _buildDetailRow(
                          'Price',
                          '₹${widget.formatNumber(productPrice)}',
                        ),
                        if (productDiscount > 0)
                          _buildDetailRow(
                            'Discount',
                            '₹${widget.formatNumber(productDiscount)}',
                          ),
                        if (imei.isNotEmpty && !isTvBill && !isAccessoriesBill)
                          _buildDetailRowWithCopy('IMEI', imei, isPhoneBill),
                        if (serialNumber.isNotEmpty && isTvBill)
                          _buildDetailRow('Serial Number', serialNumber),
                        if (originalTvData != null && isTvBill) ...[
                          SizedBox(height: 8),
                          Divider(),
                          SizedBox(height: 8),
                          Text(
                            'TV Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 6),
                          _buildDetailRow(
                            'Brand',
                            originalTvData['modelBrand'] ??
                                originalTvData['brand'] ??
                                'N/A',
                          ),
                          _buildDetailRow(
                            'Model',
                            originalTvData['modelName'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'Original Price',
                            '₹${widget.formatNumber(originalTvData['modelPrice']?.toDouble() ?? originalTvData['price']?.toDouble() ?? 0.0)}',
                          ),
                        ],
                        if (originalPhoneData != null &&
                            !isTvBill &&
                            !isAccessoriesBill) ...[
                          SizedBox(height: 8),
                          Divider(),
                          SizedBox(height: 8),
                          Text(
                            'Phone Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 6),
                          _buildDetailRow(
                            'Brand',
                            originalPhoneData['productBrand'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'Model',
                            originalPhoneData['productName'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'Original Price',
                            '₹${widget.formatNumber(originalPhoneData['productPrice']?.toDouble() ?? 0.0)}',
                          ),
                        ],
                        SizedBox(height: 8),
                        Divider(),
                        SizedBox(height: 8),
                        Text(
                          'Payment Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 6),
                        _buildDetailRow(
                          'Purchase Mode',
                          bill['purchaseMode'] ?? 'N/A',
                        ),
                        if (gstRate > 0) ...[
                          _buildDetailRow(
                            'GST Rate',
                            '${gstRate.toStringAsFixed(0)}%',
                          ),
                          _buildDetailRow(
                            'Taxable Amount',
                            '₹${widget.formatNumber(taxableAmount)}',
                          ),
                          _buildDetailRow(
                            'GST Amount',
                            '₹${widget.formatNumber(gstAmount)}',
                          ),
                        ],
                        _buildDetailRow(
                          'Total Amount',
                          '₹${widget.formatNumber(totalAmount)}',
                          isBold: true,
                          color: secondaryGreen,
                        ),
                        if (bill['financeType']?.isNotEmpty == true)
                          _buildDetailRow('Finance Type', bill['financeType']),
                        if (bill['sealApplied'] == true)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: warningColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.verified,
                                    color: warningColor,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Seal Applied to this product',
                                    style: TextStyle(
                                      color: warningColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Detail row with copy button for IMEI
  Widget _buildDetailRowWithCopy(String label, String value, bool showCopy) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
                if (showCopy && value.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.copy, size: 16, color: Colors.blue),
                    onPressed: () => _copyImei(value),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    splashRadius: 16,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EDIT FORM ====================

  Widget _buildEditForm() {
    final List<String> purchaseModes = ['Ready Cash', 'Credit Card', 'EMI'];
    final List<String> financeCompaniesList = [
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

    // Get bill type icon
    IconData billIcon;
    String billTypeName;
    if (_editBillType == 'tv') {
      billIcon = Icons.tv;
      billTypeName = 'TV Bill';
    } else if (_editBillType == 'accessories') {
      billIcon = Icons.shopping_bag;
      billTypeName = 'Accessories Bill';
    } else {
      billIcon = Icons.phone_android;
      billTypeName = 'Phone Bill';
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(12),
      child: Form(
        key: _editFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bill info header - improved design
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [editPrimaryColor, editSecondaryColor],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: editPrimaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(billIcon, color: Colors.white, size: 22),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editing $billTypeName',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _editingBill?['billNumber'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(
                        _editingBill?['billDate'] is Timestamp
                            ? (_editingBill!['billDate'] as Timestamp).toDate()
                            : DateTime.now(),
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),

            // Product info card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shopping_cart,
                          size: 16,
                          color: editPrimaryColor,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Product Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: editPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _editProductNameController,
                      decoration: InputDecoration(
                        labelText: 'Product Name *',
                        labelStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(
                          Icons.production_quantity_limits,
                          size: 18,
                          color: editPrimaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 13),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                    if (_editBillType == 'phone' ||
                        _editBillType == 'accessories') ...[
                      SizedBox(height: 10),
                      TextFormField(
                        controller: _editImeiController,
                        decoration: InputDecoration(
                          labelText: 'IMEI Number',
                          labelStyle: TextStyle(fontSize: 12),
                          prefixIcon: Icon(
                            Icons.qr_code,
                            size: 18,
                            color: editPrimaryColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                    if (_editBillType == 'tv') ...[
                      SizedBox(height: 10),
                      TextFormField(
                        controller: _editSerialController,
                        decoration: InputDecoration(
                          labelText: 'Serial Number',
                          labelStyle: TextStyle(fontSize: 12),
                          prefixIcon: Icon(
                            Icons.confirmation_number,
                            size: 18,
                            color: editPrimaryColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),

            // Customer details card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: editPrimaryColor),
                        SizedBox(width: 6),
                        Text(
                          'Customer Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: editPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _editCustomerNameController,
                      decoration: InputDecoration(
                        labelText: 'Customer Name *',
                        labelStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 13),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _editMobileController,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number *',
                        labelStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.phone, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 13),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Required';
                        if (value?.length != 10) return 'Enter 10-digit number';
                        return null;
                      },
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _editAddressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        labelStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.location_on, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 13),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),

            // Amount details card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.currency_rupee,
                          size: 16,
                          color: editPrimaryColor,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Amount Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: editPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _editTotalAmountController,
                      decoration: InputDecoration(
                        labelText: 'Total Amount *',
                        labelStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.currency_rupee, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 13),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) => _calculateEditGST(),
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Required';
                        if (double.tryParse(value!) == null)
                          return 'Invalid amount';
                        return null;
                      },
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: editPrimaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: editPrimaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Taxable Amount (18% GST):',
                                style: TextStyle(fontSize: 11),
                              ),
                              Text(
                                '₹${_editTaxableAmountController.text}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'GST Amount:',
                                style: TextStyle(fontSize: 11),
                              ),
                              Text(
                                '₹${_editGstAmountController.text}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: warningColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),

            // Payment details card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment, size: 16, color: editPrimaryColor),
                        SizedBox(width: 6),
                        Text(
                          'Payment Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: editPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _editSelectedPurchaseMode,
                      decoration: InputDecoration(
                        labelText: 'Purchase Mode',
                        labelStyle: TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 13),
                      items: purchaseModes.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(mode, style: TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _editSelectedPurchaseMode = value;
                        });
                      },
                    ),
                    if (_editSelectedPurchaseMode == 'EMI') ...[
                      SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _editSelectedFinanceType,
                        decoration: InputDecoration(
                          labelText: 'Finance Company',
                          labelStyle: TextStyle(fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(fontSize: 13),
                        items: financeCompaniesList.map((company) {
                          return DropdownMenuItem(
                            value: company,
                            child: Text(
                              company,
                              style: TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _editSelectedFinanceType = value;
                          });
                        },
                      ),
                    ],
                    SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _editSealChecked,
                            onChanged: (value) {
                              setState(() {
                                _editSealChecked = value ?? false;
                              });
                            },
                            activeColor: editPrimaryColor,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Apply Seal on Bill',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cancelEdit,
                    icon: Icon(Icons.close, size: 18),
                    label: Text('Cancel', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: Colors.red.withOpacity(0.5)),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUpdating ? null : _updateBill,
                    icon: _isUpdating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.save, size: 18),
                    label: Text(
                      _isUpdating ? 'Updating...' : 'Update Bill',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: editPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
