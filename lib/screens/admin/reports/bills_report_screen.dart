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
import 'bills_report_edit.dart';
import 'bills_reprint.dart';
import 'bills_report_pdf.dart';

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
  String? _editBillType;

  // PDF Generation
  bool _isGeneratingPDF = false;
  late BillsReportPDF _pdfHelper;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryGreen = const Color(0xFF0A4D2E);
  final Color secondaryGreen = const Color(0xFF1A7D4A);
  final Color warningColor = const Color(0xFFFFC107);
  final Color editPrimaryColor = const Color(0xFF2563EB);
  final Color editSecondaryColor = const Color(0xFF3B82F6);

  // Print and Edit helper instances
  late BillRePrint _printHelper;
  late BillsReportEdit _editHelper;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize controllers
    _editCustomerNameController = TextEditingController();
    _editMobileController = TextEditingController();
    _editAddressController = TextEditingController();
    _editTotalAmountController = TextEditingController();
    _editTaxableAmountController = TextEditingController();
    _editGstAmountController = TextEditingController();
    _editProductNameController = TextEditingController();
    _editImeiController = TextEditingController();
    _editSerialController = TextEditingController();

    // Initialize helpers
    _printHelper = BillRePrint();
    _editHelper = BillsReportEdit(
      firestore: _firestore,
      formatNumber: widget.formatNumber,
      primaryGreen: primaryGreen,
      editPrimaryColor: editPrimaryColor,
      editSecondaryColor: editSecondaryColor,
      warningColor: warningColor,
    );

    // Initialize PDF helper - No logo/seal
    _pdfHelper = BillsReportPDF(formatNumber: widget.formatNumber);

    if (widget.initialShopId != null) {
      _selectedShopId = widget.initialShopId;
    }

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

  // ==================== GENERATE SALES REPORT PDF ====================
  Future<void> _generateSalesReport() async {
    final filteredPhoneBills = _getFilteredPhoneBills();
    final filteredAccessoriesBills = _getFilteredAccessoriesBills();
    final filteredTvBills = _getFilteredTvBills();

    if (filteredPhoneBills.isEmpty &&
        filteredAccessoriesBills.isEmpty &&
        filteredTvBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No bills available to generate report'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String shopName = 'All Shops';
    if (_selectedShopId != null && _selectedShopId!.isNotEmpty) {
      final shop = widget.shops.firstWhere(
        (s) => s['id'] == _selectedShopId,
        orElse: () => {'name': 'Unknown Shop'},
      );
      shopName = shop['name'] ?? 'Unknown Shop';
    }

    await _pdfHelper.generateAndShareSalesReport(
      context: context,
      phoneBills: filteredPhoneBills,
      accessoriesBills: filteredAccessoriesBills,
      tvBills: filteredTvBills,
      periodLabel: _getPeriodLabel(),
      periodDateRange: _getPeriodDateRange(),
      shopName: shopName,
      isLoading: _isGeneratingPDF,
      setLoading: (value) {
        setState(() {
          _isGeneratingPDF = value;
        });
      },
    );
  }

  // ==================== EDIT BILL ====================
  void _startEditBill(Map<String, dynamic> bill) {
    // Determine bill type
    final billType = bill['billType'] as String?;
    final type = bill['type'] as String?;
    String newEditBillType;

    if (billType == 'GST Accessories') {
      newEditBillType = 'accessories';
    } else if (type == 'tv') {
      newEditBillType = 'tv';
    } else {
      newEditBillType = 'phone';
    }

    // Get product details
    String productName = '';
    String imei = '';
    String serialNumber = '';

    if (newEditBillType == 'phone') {
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
    } else if (newEditBillType == 'tv') {
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
      _editBillType = newEditBillType;
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
    _editHelper.calculateEditGST(
      totalAmountController: _editTotalAmountController,
      taxableAmountController: _editTaxableAmountController,
      gstAmountController: _editGstAmountController,
      setState: setState,
    );
  }

  Future<void> _updateBill() async {
    await _editHelper.updateBill(
      context: context,
      formKey: _editFormKey,
      billId: _editingBill?['id'],
      editBillType: _editBillType,
      customerNameController: _editCustomerNameController,
      mobileController: _editMobileController,
      addressController: _editAddressController,
      totalAmountController: _editTotalAmountController,
      taxableAmountController: _editTaxableAmountController,
      gstAmountController: _editGstAmountController,
      productNameController: _editProductNameController,
      imeiController: _editImeiController,
      serialController: _editSerialController,
      selectedPurchaseMode: _editSelectedPurchaseMode,
      selectedFinanceType: _editSelectedFinanceType,
      sealChecked: _editSealChecked,
      setState: setState,
      onUpdateSuccess: _fetchAllBills,
    );
  }

  // ==================== CANCEL EDIT METHOD ====================
  void _cancelEdit() {
    // Clear all controllers
    _editCustomerNameController.clear();
    _editMobileController.clear();
    _editAddressController.clear();
    _editTotalAmountController.clear();
    _editTaxableAmountController.clear();
    _editGstAmountController.clear();
    _editProductNameController.clear();
    _editImeiController.clear();
    _editSerialController.clear();

    // Reset all state variables
    setState(() {
      _isEditMode = false;
      _editingBill = null;
      _editBillType = null;
      _editSelectedPurchaseMode = null;
      _editSelectedFinanceType = null;
      _editSealChecked = false;
      _isUpdating = false;
    });
  }

  // ==================== PRINT BILL ====================
  Future<void> _printAndShareBill(Map<String, dynamic> bill) async {
    await _printHelper.printAndShareBill(
      context: context,
      bill: bill,
      setState: setState,
    );
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

  // ==================== BUILD METHODS ====================
  @override
  Widget build(BuildContext context) {
    final filteredPhoneBills = _getFilteredPhoneBills();
    final filteredAccessoriesBills = _getFilteredAccessoriesBills();
    final filteredTvBills = _getFilteredTvBills();

    return WillPopScope(
      onWillPop: () async {
        if (_isEditMode) {
          _cancelEdit();
          return false;
        }
        return true;
      },
      child: Scaffold(
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
          automaticallyImplyLeading: false,
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
                  if (widget.shops.isNotEmpty)
                    IconButton(
                      icon: _isGeneratingPDF
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      onPressed: _isGeneratingPDF ? null : _generateSalesReport,
                      tooltip: 'Generate Sales Report',
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
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

  // ==================== BUILD EDIT FORM ====================
  Widget _buildEditForm() {
    return BillsReportEdit.buildEditForm(
      editFormKey: _editFormKey,
      editingBill: _editingBill,
      editBillType: _editBillType,
      customerNameController: _editCustomerNameController,
      mobileController: _editMobileController,
      addressController: _editAddressController,
      totalAmountController: _editTotalAmountController,
      taxableAmountController: _editTaxableAmountController,
      gstAmountController: _editGstAmountController,
      productNameController: _editProductNameController,
      imeiController: _editImeiController,
      serialController: _editSerialController,
      selectedPurchaseMode: _editSelectedPurchaseMode,
      selectedFinanceType: _editSelectedFinanceType,
      sealChecked: _editSealChecked,
      isUpdating: _isUpdating,
      formatNumber: widget.formatNumber,
      primaryGreen: primaryGreen,
      editPrimaryColor: editPrimaryColor,
      editSecondaryColor: editSecondaryColor,
      warningColor: warningColor,
      onCancel: _cancelEdit,
      onUpdate: _updateBill,
      onCalculateGST: _calculateEditGST,
      onPurchaseModeChanged: (value) {
        setState(() {
          _editSelectedPurchaseMode = value;
        });
      },
      onFinanceTypeChanged: (value) {
        setState(() {
          _editSelectedFinanceType = value;
        });
      },
      onSealChanged: (value) {
        setState(() {
          _editSealChecked = value ?? false;
        });
      },
    );
  }
}
