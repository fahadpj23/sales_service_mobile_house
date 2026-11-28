// lib/screens/admin/reports/bills_report_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
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
  List<Map<String, dynamic>> _applianceBills = [];

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

  // Purchase mode + finance type + search filters
  String? _selectedPurchaseMode;
  String? _selectedFinanceType;
  String _searchQuery = '';

  // Only two purchase modes
  static const String _modeEmi = 'EMI';
  static const String _modeReadyCash = 'Ready Cash';

  static const List<String> _purchaseModeOptions = [_modeEmi, _modeReadyCash];

  // Finance companies (shown only when purchase mode = EMI)
  static const List<String> _financeCompaniesList = [
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

  // Old bills may have been saved with the old short names.
  // This maps them to the new names so old bills still match the filter.
  static const Map<String, String> _legacyFinanceAliases = {
    'bajaj': 'bajaj finance',
    'tvs': 'tvs credit',
    'hdb': 'hdb financial',
  };

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

  late BillRePrint _printHelper;
  late BillsReportEdit _editHelper;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _editCustomerNameController = TextEditingController();
    _editMobileController = TextEditingController();
    _editAddressController = TextEditingController();
    _editTotalAmountController = TextEditingController();
    _editTaxableAmountController = TextEditingController();
    _editGstAmountController = TextEditingController();
    _editProductNameController = TextEditingController();
    _editImeiController = TextEditingController();
    _editSerialController = TextEditingController();

    _printHelper = BillRePrint();
    _editHelper = BillsReportEdit(
      firestore: _firestore,
      formatNumber: widget.formatNumber,
      primaryGreen: primaryGreen,
      editPrimaryColor: editPrimaryColor,
      editSecondaryColor: editSecondaryColor,
      warningColor: warningColor,
    );

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

  void _copyImei(String imei) {
    if (imei.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: imei));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('IMEI copied to clipboard: $imei'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
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
      _applianceBills.clear();

      for (var doc in billsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        final billType = data['billType'] as String?;
        final type = data['type'] as String?;

        _allBills.add(data);

        final billTypeLower = billType?.toLowerCase() ?? '';
        if (billTypeLower == 'appliances' || billTypeLower == 'appliance') {
          _applianceBills.add(data);
        } else if (billType == 'GST Accessories') {
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
    filteredPhoneBills = _filterBillsBySearchAndMode(filteredPhoneBills);

    // Use a normalized (lowercase) key so "Oppo", "oppo", "OPPO" group together,
    // while keeping a nicely-cased display name for the UI.
    final Map<String, String> displayNames = {};

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

      // Normalize for comparison (trim + lowercase)
      final normalizedKey = brand.trim().toLowerCase();

      // Keep the first-seen original casing as the display name
      // (or you can force Title Case if preferred)
      displayNames.putIfAbsent(normalizedKey, () => brand.trim());

      if (!_brandWiseBills.containsKey(normalizedKey)) {
        _brandWiseBills[normalizedKey] = [];
      }
      _brandWiseBills[normalizedKey]!.add(bill);
    }

    for (var entry in _brandWiseBills.entries) {
      final normalizedKey = entry.key;
      final bills = entry.value;

      final totalAmount = _calculateTotalAmount(bills);
      final totalTaxable = _calculateTotalTaxableAmount(bills);
      final totalGst = _calculateTotalGstAmount(bills);
      final totalBills = bills.length;

      _brandStats[displayNames[normalizedKey] ?? normalizedKey] = {
        'totalAmount': totalAmount,
        'totalTaxable': totalTaxable,
        'totalGst': totalGst,
        'totalBills': totalBills,
      };
    }
  }
  // ==================== purchase mode / finance helpers ====================

  /// Old bills may have purchaseMode saved as "Finance". Treat it as EMI.
  bool _isEmiMode(String mode) {
    final m = mode.trim().toLowerCase();
    return m == 'emi' || m == 'finance';
  }

  String _normalizeFinance(dynamic value) {
    final v = (value ?? '').toString().trim().toLowerCase();
    return _legacyFinanceAliases[v] ?? v;
  }

  // ==================== search + mode + finance filter ====================
  List<Map<String, dynamic>> _filterBillsBySearchAndMode(
    List<Map<String, dynamic>> bills,
  ) {
    return bills.where((bill) {
      // Purchase Mode (+ Finance Type when EMI)
      if (_selectedPurchaseMode != null && _selectedPurchaseMode!.isNotEmpty) {
        final mode = (bill['purchaseMode'] ?? '').toString();

        if (_selectedPurchaseMode == _modeEmi) {
          // Only EMI bills
          if (!_isEmiMode(mode)) return false;

          // If a finance company is chosen, filter by it.
          // If not chosen, all EMI bills are shown.
          if (_selectedFinanceType != null &&
              _selectedFinanceType!.isNotEmpty) {
            final billFinance = _normalizeFinance(bill['financeType']);
            final selectedFinance = _normalizeFinance(_selectedFinanceType);
            if (billFinance != selectedFinance) return false;
          }
        } else {
          // Ready Cash
          if (mode.trim().toLowerCase() !=
              _selectedPurchaseMode!.trim().toLowerCase()) {
            return false;
          }
        }
      }

      // Search
      if (_searchQuery.trim().isEmpty) return true;

      final q = _searchQuery.trim().toLowerCase();

      final customerName = (bill['customerName'] ?? '')
          .toString()
          .toLowerCase();
      final customerMobile = (bill['customerMobile'] ?? '')
          .toString()
          .toLowerCase();
      final productName = (bill['productName'] ?? '').toString().toLowerCase();
      final modelName = (bill['modelName'] ?? '').toString().toLowerCase();
      final applianceProductName = (bill['applianceProductName'] ?? '')
          .toString()
          .toLowerCase();
      final imei = (bill['imei'] ?? '').toString().toLowerCase();
      final serial = (bill['serialNumber'] ?? '').toString().toLowerCase();
      final billNumber = (bill['billNumber'] ?? '').toString().toLowerCase();

      // Nested product map
      String nestedProductName = '';
      final product = bill['product'];
      if (product is Map<String, dynamic>) {
        nestedProductName = (product['productName'] ?? '')
            .toString()
            .toLowerCase();
      }

      // Nested original data maps
      String originalPhoneName = '';
      String originalPhoneImei = '';
      final originalPhoneData = bill['originalPhoneData'];
      if (originalPhoneData is Map<String, dynamic>) {
        originalPhoneName = (originalPhoneData['productName'] ?? '')
            .toString()
            .toLowerCase();
        originalPhoneImei = (originalPhoneData['imei'] ?? '')
            .toString()
            .toLowerCase();
      }

      String originalTvModel = '';
      String originalTvSerial = '';
      final originalTvData = bill['originalTvData'];
      if (originalTvData is Map<String, dynamic>) {
        originalTvModel = (originalTvData['modelName'] ?? '')
            .toString()
            .toLowerCase();
        originalTvSerial = (originalTvData['serialNumber'] ?? '')
            .toString()
            .toLowerCase();
      }

      String originalApplianceName = '';
      String originalApplianceSerial = '';
      final originalApplianceData = bill['originalApplianceData'];
      if (originalApplianceData is Map<String, dynamic>) {
        originalApplianceName = (originalApplianceData['productName'] ?? '')
            .toString()
            .toLowerCase();
        originalApplianceSerial = (originalApplianceData['serialNumber'] ?? '')
            .toString()
            .toLowerCase();
      }

      final haystack = [
        customerName,
        customerMobile,
        productName,
        modelName,
        applianceProductName,
        imei,
        serial,
        billNumber,
        nestedProductName,
        originalPhoneName,
        originalPhoneImei,
        originalTvModel,
        originalTvSerial,
        originalApplianceName,
        originalApplianceSerial,
      ].join(' ');

      return haystack.contains(q);
    }).toList();
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
            final yesterday = now.subtract(const Duration(days: 1));
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
    bills = _filterBillsBySearchAndMode(bills);
    return bills;
  }

  List<Map<String, dynamic>> _getFilteredAccessoriesBills() {
    var bills = _filterBillsByTimePeriod(_accessoriesBills);
    bills = _filterBillsByShop(bills);
    bills = _filterBillsBySearchAndMode(bills);
    return bills;
  }

  List<Map<String, dynamic>> _getFilteredTvBills() {
    var bills = _filterBillsByTimePeriod(_tvBills);
    bills = _filterBillsByShop(bills);
    bills = _filterBillsBySearchAndMode(bills);
    return bills;
  }

  List<Map<String, dynamic>> _getFilteredApplianceBills() {
    var bills = _filterBillsByTimePeriod(_applianceBills);
    bills = _filterBillsByShop(bills);
    bills = _filterBillsBySearchAndMode(bills);
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

  Future<void> _generateSalesReport() async {
    final filteredPhoneBills = _getFilteredPhoneBills();
    final filteredAccessoriesBills = _getFilteredAccessoriesBills();
    final filteredTvBills = _getFilteredTvBills();
    final filteredApplianceBills = _getFilteredApplianceBills();

    if (filteredPhoneBills.isEmpty &&
        filteredAccessoriesBills.isEmpty &&
        filteredTvBills.isEmpty &&
        filteredApplianceBills.isEmpty) {
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
      applianceBills: filteredApplianceBills,
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

  // ==================== SEARCH DIALOG ====================
  Future<void> _openSearchDialog() async {
    final controller = TextEditingController(text: _searchQuery);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.search, color: primaryGreen, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Search Bills',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Name, phone, IMEI, serial, product…',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: Icon(Icons.search, size: 18, color: primaryGreen),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => controller.clear(),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Searches customer name, mobile, product, IMEI and serial.',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, controller.text),
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Search', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null) return;

    setState(() {
      _searchQuery = result;
      _processBrandWiseData();
    });
  }

  // ==================== FILTER SHEET ====================
  Future<void> _openFilterSheet() async {
    String? tempShopId = _selectedShopId;
    String? tempPurchaseMode = _selectedPurchaseMode;
    String? tempFinanceType = _selectedFinanceType;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.filter_alt, color: primaryGreen, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setS(() {
                                tempShopId = null;
                                tempPurchaseMode = null;
                                tempFinanceType = null;
                              });
                            },
                            child: const Text(
                              'Clear All',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Shop
                      _filterLabel('Shop'),
                      DropdownButtonFormField<String>(
                        value: tempShopId,
                        isExpanded: true,
                        decoration: _dropdownDecoration(),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'All Shops',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          ...widget.shops.map(
                            (s) => DropdownMenuItem<String>(
                              value: s['id'] as String?,
                              child: Text(
                                (s['name'] ?? 'Unknown').toString(),
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setS(() => tempShopId = v),
                      ),
                      const SizedBox(height: 12),

                      // Purchase Mode (EMI / Ready Cash)
                      _filterLabel('Purchase Mode'),
                      DropdownButtonFormField<String>(
                        value: tempPurchaseMode,
                        isExpanded: true,
                        decoration: _dropdownDecoration(),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Any', style: TextStyle(fontSize: 13)),
                          ),
                          ..._purchaseModeOptions.map(
                            (m) => DropdownMenuItem<String>(
                              value: m,
                              child: Text(
                                m,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setS(() {
                          tempPurchaseMode = v;
                          // Finance type only applies to EMI
                          if (v != _modeEmi) {
                            tempFinanceType = null;
                          }
                        }),
                      ),
                      const SizedBox(height: 12),

                      // Finance Type - only when EMI is selected
                      if (tempPurchaseMode == _modeEmi) ...[
                        _filterLabel('Finance Type'),
                        DropdownButtonFormField<String>(
                          value: tempFinanceType,
                          isExpanded: true,
                          decoration: _dropdownDecoration(),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                'All EMI (any finance)',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            ..._financeCompaniesList.map(
                              (f) => DropdownMenuItem<String>(
                                value: f,
                                child: Text(
                                  f,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setS(() => tempFinanceType = v),
                        ),
                        const SizedBox(height: 12),
                      ],

                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pop(ctx, true),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Apply'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (applied == true) {
      setState(() {
        _selectedShopId = tempShopId;
        _selectedPurchaseMode = tempPurchaseMode;
        // Finance type is only valid when mode is EMI
        _selectedFinanceType = tempPurchaseMode == _modeEmi
            ? tempFinanceType
            : null;
        _processBrandWiseData();
      });
    }
  }

  Widget _filterLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  // ==================== EDIT BILL ====================
  void _startEditBill(Map<String, dynamic> bill) {
    final billType = bill['billType'] as String?;
    final type = bill['type'] as String?;
    String newEditBillType;

    final billTypeLower = billType?.toLowerCase() ?? '';

    if (billTypeLower == 'appliances' ||
        billTypeLower == 'appliance' ||
        billTypeLower == 'Appliances') {
      newEditBillType = 'appliance';
    } else if (billType == 'GST Accessories') {
      newEditBillType = 'accessories';
    } else if (type == 'tv') {
      newEditBillType = 'tv';
    } else {
      newEditBillType = 'phone';
    }

    String productName = '';
    String imei = '';
    String serialNumber = '';

    if (newEditBillType == 'accessories') {
      final productMap = bill['product'] as Map<String, dynamic>?;
      productName =
          productMap?['productName']?.toString() ??
          bill['productName']?.toString() ??
          bill['applianceProductName']?.toString() ??
          '';
      serialNumber =
          bill['serialNumber']?.toString() ??
          productMap?['serialNumber']?.toString() ??
          '';
      imei = '';
    } else if (newEditBillType == 'appliance') {
      final productMap = bill['product'] as Map<String, dynamic>?;
      final originalApplianceData = bill['originalApplianceData'];
      productName =
          productMap?['productName']?.toString() ??
          bill['applianceProductName']?.toString() ??
          bill['productName']?.toString() ??
          '';
      serialNumber =
          bill['serialNumber']?.toString() ??
          productMap?['serialNumber']?.toString() ??
          '';
      if (originalApplianceData is Map<String, dynamic>) {
        if (productName.isEmpty) {
          productName = originalApplianceData['productName']?.toString() ?? '';
        }
        if (serialNumber.isEmpty) {
          serialNumber =
              originalApplianceData['serialNumber']?.toString() ?? '';
        }
      }
      imei = '';
    } else if (newEditBillType == 'phone') {
      final originalPhoneData = bill['originalPhoneData'];
      if (originalPhoneData is Map<String, dynamic>) {
        productName =
            originalPhoneData['productName'] ?? bill['productName'] ?? '';
      } else {
        productName = bill['productName'] ?? '';
      }
      imei = bill['imei'] ?? '';
      if (originalPhoneData is Map<String, dynamic>) {
        if (imei.isEmpty) imei = originalPhoneData['imei'] ?? '';
      }
    } else if (newEditBillType == 'tv') {
      final originalTvData = bill['originalTvData'];
      if (originalTvData is Map<String, dynamic>) {
        productName =
            originalTvData['modelName'] ??
            bill['modelName'] ??
            bill['productName'] ??
            '';
      } else {
        productName = bill['modelName'] ?? bill['productName'] ?? '';
      }
      serialNumber = bill['serialNumber'] ?? '';
      if (originalTvData is Map<String, dynamic>) {
        if (serialNumber.isEmpty) {
          serialNumber = originalTvData['serialNumber'] ?? '';
        }
      }
    }

    // Map old "Finance" purchase mode to the new "EMI"
    String editMode = (bill['purchaseMode'] ?? _modeReadyCash).toString();
    if (_isEmiMode(editMode)) {
      editMode = _modeEmi;
    } else {
      editMode = _modeReadyCash;
    }

    setState(() {
      _editingBill = bill;
      _editBillType = newEditBillType;
      _isEditMode = true;

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
      _editSelectedPurchaseMode = editMode;
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
    setState(() {
      _isUpdating = true;
    });

    try {
      await _editHelper.updateBill(
        context: context,
        formKey: _editFormKey,
        billId: _editingBill?['id'],
        editBillType: _editBillType,
        editingBill: _editingBill,
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
        onUpdateSuccess: () {
          _fetchAllBills();
          _cancelEdit();
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _cancelEdit() {
    _editCustomerNameController.clear();
    _editMobileController.clear();
    _editAddressController.clear();
    _editTotalAmountController.clear();
    _editTaxableAmountController.clear();
    _editGstAmountController.clear();
    _editProductNameController.clear();
    _editImeiController.clear();
    _editSerialController.clear();

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

  Future<void> _printAndShareBill(Map<String, dynamic> bill) async {
    await _printHelper.printAndShareBill(
      context: context,
      bill: bill,
      setState: setState,
    );
  }

  Future<void> _showCustomDateRangePicker() async {
    DateTime startDate =
        _customStartDate ?? DateTime.now().subtract(const Duration(days: 30));
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
            colorScheme: const ColorScheme.light(primary: Color(0xFF1A7D4A)),
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
            colorScheme: const ColorScheme.light(primary: Color(0xFF1A7D4A)),
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
      _selectedPurchaseMode = null;
      _selectedFinanceType = null;
      _searchQuery = '';
      _customStartDate = null;
      _customEndDate = null;
      _isCustomPeriod = false;
      _selectedTimePeriod = 'monthly';
      _processBrandWiseData();
    });
  }

  String _getPeriodLabel() {
    if (_isCustomPeriod) return 'Custom Range';

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
        final yesterday = now.subtract(const Duration(days: 1));
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

  int get _activeFilterCount {
    var n = 0;
    if (_selectedShopId != null && _selectedShopId!.isNotEmpty) n++;
    if (_selectedPurchaseMode != null && _selectedPurchaseMode!.isNotEmpty) {
      n++;
    }
    if (_selectedPurchaseMode == _modeEmi &&
        _selectedFinanceType != null &&
        _selectedFinanceType!.isNotEmpty) {
      n++;
    }
    if (_searchQuery.trim().isNotEmpty) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final filteredPhoneBills = _getFilteredPhoneBills();
    final filteredAccessoriesBills = _getFilteredAccessoriesBills();
    final filteredTvBills = _getFilteredTvBills();
    final filteredApplianceBills = _getFilteredApplianceBills();

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
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _cancelEdit,
                )
              : null,
          automaticallyImplyLeading: false,
          bottom: _isEditMode
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    color: primaryGreen,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabs: [
                        Tab(
                          child: _tabLabel(
                            Icons.phone_android,
                            'Phone',
                            filteredPhoneBills.length,
                          ),
                        ),
                        Tab(
                          child: _tabLabel(
                            Icons.shopping_bag,
                            'Accessories',
                            filteredAccessoriesBills.length,
                          ),
                        ),
                        Tab(
                          child: _tabLabel(
                            Icons.tv,
                            'TV',
                            filteredTvBills.length,
                          ),
                        ),
                        Tab(
                          child: _tabLabel(
                            Icons.kitchen,
                            'Appliances',
                            filteredApplianceBills.length,
                          ),
                        ),
                      ],
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      indicatorColor: Colors.white,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontSize: 12),
                      unselectedLabelStyle: const TextStyle(fontSize: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
          actions: _isEditMode
              ? []
              : [
                  // Search icon
                  IconButton(
                    tooltip: 'Search',
                    icon: Icon(
                      Icons.search,
                      color: _searchQuery.isNotEmpty
                          ? warningColor
                          : Colors.white,
                    ),
                    onPressed: _openSearchDialog,
                  ),
                  // Filter icon with active-count badge
                  Stack(
                    children: [
                      IconButton(
                        tooltip: 'Filters',
                        icon: Icon(
                          Icons.filter_alt,
                          color: _activeFilterCount > 0
                              ? warningColor
                              : Colors.white,
                        ),
                        onPressed: _openFilterSheet,
                      ),
                      if (_activeFilterCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: warningColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                            child: Text(
                              '$_activeFilterCount',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
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
                filteredApplianceBills,
              ),
      ),
    );
  }

  Widget _tabLabel(IconData icon, String label, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(label),
        Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: const TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  Widget _buildMainContent(
    List<Map<String, dynamic>> filteredPhoneBills,
    List<Map<String, dynamic>> filteredAccessoriesBills,
    List<Map<String, dynamic>> filteredTvBills,
    List<Map<String, dynamic>> filteredApplianceBills,
  ) {
    return Column(
      children: [
        _buildTimePeriodSelector(),
        const SizedBox(height: 8),
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
              _buildBillsList(filteredApplianceBills, 'Appliance Bills', true),
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
      padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: periodOptions.map((option) {
                bool isSelected = _isCustomPeriod
                    ? option['value'] == 'custom'
                    : _selectedTimePeriod == option['value'];

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      option['label'] as String,
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
                          _selectedTimePeriod = option['value'] as String;
                          _isCustomPeriod = false;
                          _processBrandWiseData();
                        });
                      }
                    },
                    avatar: Icon(
                      option['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : primaryGreen,
                    ),
                    backgroundColor: Colors.grey[100],
                    selectedColor: primaryGreen,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    shape: const StadiumBorder(),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_isCustomPeriod &&
              _customStartDate != null &&
              _customEndDate != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: secondaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.date_range, size: 14, color: secondaryGreen),
                  const SizedBox(width: 6),
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
    // Active filter chips row
    final chips = <Widget>[];

    if (_searchQuery.trim().isNotEmpty) {
      chips.add(
        _activeFilterChip(
          'Search: "$_searchQuery"',
          () => setState(() {
            _searchQuery = '';
            _processBrandWiseData();
          }),
        ),
      );
    }
    if (_selectedPurchaseMode != null) {
      chips.add(
        _activeFilterChip(
          'Mode: $_selectedPurchaseMode',
          () => setState(() {
            _selectedPurchaseMode = null;
            // Finance type only makes sense with EMI
            _selectedFinanceType = null;
            _processBrandWiseData();
          }),
        ),
      );
    }
    if (_selectedPurchaseMode == _modeEmi && _selectedFinanceType != null) {
      chips.add(
        _activeFilterChip(
          'Finance: $_selectedFinanceType',
          () => setState(() {
            _selectedFinanceType = null;
            _processBrandWiseData();
          }),
        ),
      );
    }
    if (_selectedShopId != null) {
      final name = widget.shops.firstWhere(
        (s) => s['id'] == _selectedShopId,
        orElse: () => {'name': 'Shop'},
      )['name'];
      chips.add(
        _activeFilterChip(
          'Shop: $name',
          () => setState(() {
            _selectedShopId = null;
            _processBrandWiseData();
          }),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _openFilterSheet,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.filter_alt, size: 16, color: primaryGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _activeFilterCount == 0
                                ? 'Filters (Shop, Mode, Finance)'
                                : '$_activeFilterCount filter(s) active',
                            style: TextStyle(
                              fontSize: 12,
                              color: _activeFilterCount == 0
                                  ? Colors.grey[600]
                                  : primaryGreen,
                              fontWeight: _activeFilterCount == 0
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.clear, color: Colors.red[400]),
                onPressed: _resetFilters,
                tooltip: 'Reset All Filters',
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
        ],
      ),
    );
  }

  Widget _activeFilterChip(String label, VoidCallback onDelete) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onDelete,
      backgroundColor: primaryGreen.withOpacity(0.08),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildPhoneBillsContent(List<Map<String, dynamic>> bills) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      return _emptyState('No phone bills found');
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildOverallSummaryCard(
          totalAllAmount,
          totalAllTaxable,
          totalAllGst,
          totalAllBills,
        ),
        const SizedBox(height: 12),
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

  Widget _emptyState(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            'Try changing your filters or search',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallSummaryCard(
    double totalAmount,
    double totalTaxable,
    double totalGst,
    int count,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            offset: const Offset(0, 2),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
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
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Taxable Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '₹${widget.formatNumber(totalTaxable)}',
                      style: const TextStyle(
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
                    const Text(
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
                    const Text(
                      'Total Sales',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '₹${widget.formatNumber(totalAmount)}',
                      style: const TextStyle(
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showBrandDetailsDialog(brand, bills),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
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
                  const SizedBox(width: 12),
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
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.branding_watermark, color: primaryGreen),
                        const SizedBox(width: 8),
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
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Bill Details (${bills.length} bills)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
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
    if (originalPhoneData is Map<String, dynamic>) {
      productName =
          originalPhoneData['productName'] ?? bill['productName'] ?? 'N/A';
    } else {
      productName = bill['productName'] ?? 'N/A';
    }

    String imei = bill['imei'] ?? '';
    if (originalPhoneData is Map<String, dynamic>) {
      if (imei.isEmpty) {
        imei = originalPhoneData['imei'] ?? '';
      }
    }

    final isPhoneBill =
        bill['type'] != 'tv' &&
        bill['billType'] != 'GST Accessories' &&
        bill['billType'] != 'Appliances' &&
        bill['billType'] != 'Appliance';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          _showBillDetailsDialog(bill);
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
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
              const SizedBox(height: 4),
              Text(
                productName,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person, size: 10, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    bill['customerName'] ?? 'N/A',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.phone, size: 10, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    bill['customerMobile'] ?? 'N/A',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.qr_code, size: 10, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'IMEI: ${imei.isNotEmpty ? imei : 'N/A'}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isPhoneBill && imei.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 14,
                        color: Colors.blue,
                      ),
                      onPressed: () => _copyImei(imei),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                    ),
                  const SizedBox(width: 12),
                  Icon(Icons.calendar_today, size: 10, color: Colors.grey[500]),
                  const SizedBox(width: 4),
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
            const SizedBox(height: 16),
            const Text('Loading bills...'),
          ],
        ),
      );
    }

    if (bills.isEmpty) {
      return _emptyState('No bills found');
    }

    final totalAmount = _calculateTotalAmount(bills);
    final totalTaxable = _calculateTotalTaxableAmount(bills);
    final totalGst = _calculateTotalGstAmount(bills);

    return Column(
      children: [
        _buildSummaryCard(totalAmount, totalTaxable, totalGst, bills.length),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
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
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
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
            offset: const Offset(0, 2),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
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
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Taxable Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '₹${widget.formatNumber(totalTaxable)}',
                      style: const TextStyle(
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
                    const Text(
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
                    const Text(
                      'Total',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '₹${widget.formatNumber(totalAmount)}',
                      style: const TextStyle(
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

    final product = bill['product'];
    final billType = bill['billType'] as String?;
    final type = bill['type'] as String?;
    final billTypeLower = billType?.toLowerCase() ?? '';
    final isTvBill = type == 'tv';
    final isAccessoriesBill = billType == 'GST Accessories';
    final isApplianceBill =
        billTypeLower == 'appliances' || billTypeLower == 'appliance';
    final isPhoneBill = !isTvBill && !isAccessoriesBill && !isApplianceBill;

    String productName = '';
    if (product is Map<String, dynamic>) {
      productName = product['productName']?.toString() ?? '';
    }
    if (productName.isEmpty) {
      if (isTvBill) {
        productName = bill['modelName']?.toString() ?? '';
      } else if (isApplianceBill) {
        productName = bill['applianceProductName']?.toString() ?? '';
      }
    }
    if (productName.isEmpty) {
      productName = bill['productName']?.toString() ?? 'N/A';
    }

    final originalTvData = bill['originalTvData'];
    String serialNumber = bill['serialNumber']?.toString() ?? '';

    if (originalTvData is Map<String, dynamic>) {
      if (serialNumber.isEmpty) {
        serialNumber = originalTvData['serialNumber'] ?? '';
      }
      if (productName == 'N/A' || productName.isEmpty) {
        productName = originalTvData['modelName'] ?? bill['modelName'] ?? 'N/A';
      }
    }

    final originalPhoneData = bill['originalPhoneData'];
    String imei = bill['imei']?.toString() ?? '';

    if (originalPhoneData is Map<String, dynamic>) {
      if (imei.isEmpty) {
        imei = originalPhoneData['imei'] ?? '';
      }
    }

    final originalApplianceData = bill['originalApplianceData'];
    String applianceSerialNumber = bill['serialNumber']?.toString() ?? '';
    if (originalApplianceData is Map<String, dynamic>) {
      if (applianceSerialNumber.isEmpty) {
        applianceSerialNumber = originalApplianceData['serialNumber'] ?? '';
      }
      if (productName == 'N/A' || productName.isEmpty) {
        productName =
            originalApplianceData['productName'] ??
            bill['productName'] ??
            'N/A';
      }
    }

    final identifier = isTvBill
        ? 'Serial'
        : isApplianceBill
        ? 'Serial'
        : 'IMEI';
    final identifierValue = isTvBill
        ? serialNumber
        : isApplianceBill
        ? applianceSerialNumber
        : imei;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: () => _showBillDetailsDialog(bill),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isTvBill
                                    ? Icons.tv
                                    : isAccessoriesBill
                                    ? Icons.shopping_bag
                                    : isApplianceBill
                                    ? Icons.kitchen
                                    : Icons.phone_android,
                                size: 18,
                                color: primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 10),
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
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
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
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 6),
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
                  if (bill['purchaseMode'] != null ||
                      bill['financeType'] != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if ((bill['purchaseMode'] ?? '').toString().isNotEmpty)
                          _buildInfoChip(
                            Icons.payments,
                            'Mode: ${_isEmiMode((bill['purchaseMode'] ?? '').toString()) ? _modeEmi : bill['purchaseMode']}',
                            fontSize: 10,
                          ),
                        if ((bill['financeType'] ?? '').toString().isNotEmpty)
                          _buildInfoChip(
                            Icons.account_balance,
                            'Finance: ${bill['financeType']}',
                            fontSize: 10,
                          ),
                      ],
                    ),
                  ],
                  if (identifierValue.isNotEmpty &&
                      (!isAccessoriesBill || isApplianceBill)) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildInfoChip(
                          isTvBill || isApplianceBill
                              ? Icons.confirmation_number
                              : Icons.qr_code,
                          '$identifier: $identifierValue',
                          fontSize: 10,
                        ),
                        if (isPhoneBill && imei.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _copyImei(imei),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
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
                              child: const Row(
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
                    const SizedBox(height: 6),
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
                      icon: const Icon(
                        Icons.print,
                        size: 18,
                        color: Colors.blue,
                      ),
                      label: const Text(
                        'Print/Share',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  Container(height: 25, width: 1, color: Colors.grey[200]),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _startEditBill(bill),
                      icon: Icon(Icons.edit, size: 18, color: editPrimaryColor),
                      label: const Text('Edit', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: editPrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color ?? Colors.grey[600]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                color: color ?? Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
    final billTypeLower = billType?.toLowerCase() ?? '';
    final isTvBill = type == 'tv';
    final isAccessoriesBill = billType == 'GST Accessories';
    final isApplianceBill =
        billTypeLower == 'appliances' ||
        billTypeLower == 'appliance' ||
        billTypeLower == 'Appliances';
    final isPhoneBill = !isTvBill && !isAccessoriesBill && !isApplianceBill;

    if (product is Map<String, dynamic>) {
      productName = product['productName']?.toString() ?? '';
      quantity = (product['quantity'] as num?)?.toInt() ?? 1;
      productPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
      productDiscount = (product['discount'] as num?)?.toDouble() ?? 0.0;
    }
    if (productName.isEmpty) {
      if (isTvBill) {
        productName = bill['modelName']?.toString() ?? '';
      } else if (isApplianceBill) {
        productName = bill['applianceProductName']?.toString() ?? '';
      }
    }
    if (productName.isEmpty) {
      productName = bill['productName']?.toString() ?? 'N/A';
    }
    if (quantity == 1 && bill['quantity'] != null) {
      quantity = (bill['quantity'] as num?)?.toInt() ?? 1;
    }
    if (productPrice == 0.0 && bill['price'] != null) {
      productPrice = (bill['price'] as num?)?.toDouble() ?? 0.0;
    }

    final originalTvData = bill['originalTvData'];
    String serialNumber = bill['serialNumber']?.toString() ?? '';

    if (originalTvData is Map<String, dynamic>) {
      if (serialNumber.isEmpty) {
        serialNumber = originalTvData['serialNumber'] ?? '';
      }
      if (productName == 'N/A' || productName.isEmpty) {
        productName = originalTvData['modelName'] ?? bill['modelName'] ?? 'N/A';
      }
    }

    final originalPhoneData = bill['originalPhoneData'];
    String imei = bill['imei']?.toString() ?? '';

    if (originalPhoneData is Map<String, dynamic>) {
      if (imei.isEmpty) {
        imei = originalPhoneData['imei'] ?? '';
      }
    }

    final originalApplianceData = bill['originalApplianceData'];
    String applianceSerialNumber = bill['serialNumber']?.toString() ?? '';
    if (originalApplianceData is Map<String, dynamic>) {
      if (applianceSerialNumber.isEmpty) {
        applianceSerialNumber = originalApplianceData['serialNumber'] ?? '';
      }
      if (productName == 'N/A' || productName.isEmpty) {
        productName =
            originalApplianceData['productName'] ??
            bill['productName'] ??
            'N/A';
      }
    }

    final rawMode = (bill['purchaseMode'] ?? '').toString();
    final displayMode = rawMode.isEmpty
        ? 'N/A'
        : (_isEmiMode(rawMode) ? _modeEmi : rawMode);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxHeight: 500),
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
                              : isApplianceBill
                              ? Icons.kitchen
                              : Icons.phone_android,
                          color: primaryGreen,
                        ),
                        const SizedBox(width: 8),
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
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
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
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Product Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
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
                        if (imei.isNotEmpty && isPhoneBill)
                          _buildDetailRowWithCopy('IMEI', imei, true),
                        if (serialNumber.isNotEmpty && isTvBill)
                          _buildDetailRow('Serial Number', serialNumber),
                        if (applianceSerialNumber.isNotEmpty && isApplianceBill)
                          _buildDetailRow(
                            'Serial Number',
                            applianceSerialNumber,
                          ),
                        if (originalTvData is Map<String, dynamic> &&
                            isTvBill) ...[
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'TV Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                        if (originalPhoneData is Map<String, dynamic> &&
                            isPhoneBill) ...[
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Phone Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                        if (originalApplianceData is Map<String, dynamic> &&
                            isApplianceBill) ...[
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Appliance Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            'Brand',
                            originalApplianceData['brand'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'Model',
                            originalApplianceData['modelName'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'Type',
                            originalApplianceData['applianceType'] ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'Original Price',
                            '₹${widget.formatNumber(originalApplianceData['price']?.toDouble() ?? 0.0)}',
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Payment Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildDetailRow('Purchase Mode', displayMode),
                        if ((bill['financeType'] ?? '').toString().isNotEmpty)
                          _buildDetailRow('Finance Type', bill['financeType']),
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
                        if (bill['sealApplied'] == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
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
                                  const SizedBox(width: 6),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
                if (showCopy && value.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: Colors.blue),
                    onPressed: () => _copyImei(value),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
