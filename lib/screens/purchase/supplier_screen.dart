import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'purchase/add_product_screen.dart';
import 'purchase/add_supplier_screen.dart';
import 'purchase/add_purchase_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Purchase Hub',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const PurchaseDashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PurchaseDashboardScreen extends StatefulWidget {
  const PurchaseDashboardScreen({super.key});

  @override
  State<PurchaseDashboardScreen> createState() =>
      _PurchaseDashboardScreenState();
}

class _PurchaseDashboardScreenState extends State<PurchaseDashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = [
    const DashboardHomeScreen(),
    const SuppliersScreen(),
    const PurchasesScreen(),
    const ProductsScreen(),
    const AddPurchaseScreen(),
    const AddProductScreen(),
    const AddSupplierScreen(),
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {'title': 'Dashboard', 'icon': Icons.dashboard, 'index': 0},
    {'title': 'Suppliers', 'icon': Icons.business, 'index': 1},
    {'title': 'Purchases', 'icon': Icons.shopping_cart, 'index': 2},
    {'title': 'Products', 'icon': Icons.inventory, 'index': 3},
    {'title': 'Add Purchase', 'icon': Icons.shopping_cart_checkout, 'index': 4},
    {'title': 'Add Product', 'icon': Icons.add_shopping_cart, 'index': 5},
    {'title': 'Add Supplier', 'icon': Icons.add_business, 'index': 6},
  ];

  void _onMenuItemTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.green[800],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white, size: 22),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: const Text(
          'Purchase Hub',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.green[800],
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 32,
                ),
                decoration: BoxDecoration(color: Colors.green[900]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.store,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Purchase Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Management System',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _menuItems.length,
                  itemBuilder: (context, index) {
                    final item = _menuItems[index];
                    final isSelected = _selectedIndex == item['index'];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: ListTile(
                        leading: Icon(
                          item['icon'],
                          color: isSelected ? Colors.green[800] : Colors.white,
                          size: 22,
                        ),
                        title: Text(
                          item['title'],
                          style: TextStyle(
                            color: isSelected
                                ? Colors.green[800]
                                : Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        onTap: () => _onMenuItemTap(item['index']),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: const Text(
                  '© 2024 Purchase Hub',
                  style: TextStyle(color: Colors.white54, fontSize: 9),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }
}

enum ReportType { today, yesterday, weekly, monthly, lastMonth, yearly, custom }

// ===================== DASHBOARD SCREEN =====================
class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _totalSuppliers = 0;
  int _totalPurchases = 0;
  double _totalPurchaseValue = 0;
  List<Map<String, dynamic>> _purchases = [];
  bool _isLoading = true;

  ReportType _selectedReportType = ReportType.monthly;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  int _totalQuantity = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot supplierSnapshot = await _firestore
          .collection('suppliers')
          .get();
      _totalSuppliers = supplierSnapshot.docs.length;

      await _loadPurchasesByReportType();
    } catch (e) {
      print('Error loading dashboard: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPurchasesByReportType() async {
    Query query = _firestore.collection('purchases');

    DateTime now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, now.day);
    DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedReportType) {
      case ReportType.today:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case ReportType.yesterday:
        startDate = DateTime(now.year, now.month, now.day - 1);
        endDate = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
        break;
      case ReportType.weekly:
        startDate = DateTime(now.year, now.month, now.day - 7);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case ReportType.monthly:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case ReportType.lastMonth:
        DateTime lastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = DateTime(lastMonth.year, lastMonth.month, 1);
        endDate = DateTime(lastMonth.year, lastMonth.month + 1, 0, 23, 59, 59);
        break;
      case ReportType.yearly:
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case ReportType.custom:
        if (_customStartDate != null && _customEndDate != null) {
          startDate = DateTime(
            _customStartDate!.year,
            _customStartDate!.month,
            _customStartDate!.day,
          );
          endDate = DateTime(
            _customEndDate!.year,
            _customEndDate!.month,
            _customEndDate!.day,
            23,
            59,
            59,
          );
        } else {
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        }
        break;
    }

    QuerySnapshot purchaseSnapshot = await query
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('createdAt', descending: true)
        .get();

    _totalPurchases = purchaseSnapshot.docs.length;
    _totalPurchaseValue = 0;
    _totalQuantity = 0;
    _purchases = [];

    for (var doc in purchaseSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      double grandTotal = (data['grandTotal'] ?? 0).toDouble();
      List items = data['items'] ?? [];

      int quantity = 0;
      for (var item in items) {
        dynamic qty = item['quantity'];
        if (qty != null) {
          if (qty is int) {
            quantity += qty;
          } else if (qty is double) {
            quantity += qty.toInt();
          } else if (qty is String) {
            quantity += int.tryParse(qty) ?? 0;
          } else if (qty is num) {
            quantity += qty.toInt();
          }
        }
      }

      _totalPurchaseValue += grandTotal;
      _totalQuantity += quantity;

      _purchases.add({
        'id': doc.id,
        'supplierName': data['supplierName'] ?? 'Unknown',
        'date': data['date'] != null
            ? (data['date'] as Timestamp).toDate()
            : DateTime.now(),
        'total': grandTotal,
        'items': items.length,
        'quantity': quantity,
        'invoiceNo': data['invoiceNo'] ?? 'N/A',
      });
    }
  }

  Future<void> _selectCustomDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start:
            _customStartDate ??
            DateTime.now().subtract(const Duration(days: 30)),
        end: _customEndDate ?? DateTime.now(),
      ),
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedReportType = ReportType.custom;
      });
      await _loadDashboardData();
    }
  }

  String _getReportTitle() {
    switch (_selectedReportType) {
      case ReportType.today:
        return 'Today\'s Report';
      case ReportType.yesterday:
        return 'Yesterday\'s Report';
      case ReportType.weekly:
        return 'Weekly Report';
      case ReportType.monthly:
        return 'Monthly Report';
      case ReportType.lastMonth:
        return 'Last Month Report';
      case ReportType.yearly:
        return 'Yearly Report';
      case ReportType.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return '${DateFormat('dd/MM/yy').format(_customStartDate!)} - ${DateFormat('dd/MM/yy').format(_customEndDate!)}';
        }
        return 'Custom Report';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Report Selector
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.date_range,
                                  size: 16,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Report Period',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildReportChip(ReportType.today, 'Today'),
                                  _buildReportChip(
                                    ReportType.yesterday,
                                    'Yest',
                                  ),
                                  _buildReportChip(ReportType.weekly, 'Week'),
                                  _buildReportChip(ReportType.monthly, 'Month'),
                                  _buildReportChip(
                                    ReportType.lastMonth,
                                    'Last M',
                                  ),
                                  _buildReportChip(ReportType.yearly, 'Year'),
                                  ActionChip(
                                    label: const Text(
                                      'Custom',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    onPressed: _selectCustomDateRange,
                                    backgroundColor:
                                        _selectedReportType == ReportType.custom
                                        ? Colors.green
                                        : Colors.grey[200],
                                    labelStyle: TextStyle(
                                      fontSize: 11,
                                      color:
                                          _selectedReportType ==
                                              ReportType.custom
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    avatar: Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color:
                                          _selectedReportType ==
                                              ReportType.custom
                                          ? Colors.white
                                          : Colors.green,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 12,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _getReportTitle(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Stats Cards
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: MediaQuery.of(context).size.width > 600
                          ? 4
                          : 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.6,
                      children: [
                        _buildStatCard(
                          title: 'Purchases',
                          value: _totalPurchases.toString(),
                          icon: Icons.shopping_cart,
                          color: Colors.orange,
                        ),
                        _buildStatCard(
                          title: 'Total Value',
                          value: '₹${(_totalPurchaseValue).toStringAsFixed(0)}',
                          icon: Icons.currency_rupee,
                          color: Colors.purple,
                        ),
                        _buildStatCard(
                          title: 'Total Qty',
                          value: _totalQuantity.toString(),
                          icon: Icons.production_quantity_limits,
                          color: Colors.teal,
                        ),
                        _buildStatCard(
                          title: 'Suppliers',
                          value: _totalSuppliers.toString(),
                          icon: Icons.business,
                          color: Colors.indigo,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Purchases List
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                topRight: Radius.circular(10),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 16,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Recent Purchases',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                                const Spacer(),
                                if (_purchases.isNotEmpty)
                                  Text(
                                    '${_purchases.length}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_purchases.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(30),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.shopping_cart,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'No purchases found',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _purchases.length > 5
                                  ? 5
                                  : _purchases.length,
                              itemBuilder: (context, index) {
                                final purchase = _purchases[index];
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.green[50],
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.receipt,
                                          size: 14,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              purchase['supplierName'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              DateFormat(
                                                'dd/MM/yy',
                                              ).format(purchase['date']),
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                            Text(
                                              'Qty: ${purchase['quantity']} | Items: ${purchase['items']}',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${purchase['total'].toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReportChip(ReportType type, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 10)),
        selected: _selectedReportType == type,
        onSelected: (selected) async {
          if (selected) {
            setState(() => _selectedReportType = type);
            await _loadDashboardData();
          }
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.green,
        labelStyle: TextStyle(
          fontSize: 10,
          color: _selectedReportType == type ? Colors.white : Colors.black87,
          fontWeight: _selectedReportType == type
              ? FontWeight.bold
              : FontWeight.normal,
        ),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.8), color],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: Colors.white),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 9, color: Colors.white70),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== SUPPLIERS SCREEN =====================
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _suppliers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('suppliers')
          .orderBy('name')
          .get();

      _suppliers = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'phone': data['phone'] ?? 'N/A',
          'email': data['email'] ?? 'N/A',
          'address': data['address'] ?? 'N/A',
          'gstNumber': data['gstNumber'] ?? 'N/A',
          'status': data['status'] ?? 'active',
          'createdAt': data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
        };
      }).toList();
    } catch (e) {
      print('Error loading suppliers: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading suppliers: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredSuppliers {
    if (_searchQuery.isEmpty) return _suppliers;
    return _suppliers.where((supplier) {
      return supplier['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          supplier['phone'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          supplier['email'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
    }).toList();
  }

  void _showSupplierDetails(Map<String, dynamic> supplier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.business, color: Colors.green[700]),
            const SizedBox(width: 8),
            Text(supplier['name'], style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Phone', supplier['phone'], Icons.phone),
              _buildDetailRow('Email', supplier['email'], Icons.email),
              _buildDetailRow(
                'Address',
                supplier['address'],
                Icons.location_on,
              ),
              _buildDetailRow(
                'GST Number',
                supplier['gstNumber'],
                Icons.numbers,
              ),
              _buildDetailRow(
                'Status',
                supplier['status'] ?? 'active',
                Icons.circle,
                statusColor: supplier['status'] == 'active'
                    ? Colors.green
                    : Colors.red,
              ),
              _buildDetailRow(
                'Joined',
                DateFormat('dd MMM yyyy').format(supplier['createdAt']),
                Icons.calendar_today,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.green[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: statusColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search suppliers...',
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Supplier Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${_filteredSuppliers.length} suppliers found',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),

          const SizedBox(height: 8),

          // Suppliers List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSuppliers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No suppliers found',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          Text(
                            'Try adjusting your search',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadSuppliers,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filteredSuppliers.length,
                      itemBuilder: (context, index) {
                        final supplier = _filteredSuppliers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                supplier['name'][0].toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            title: Text(
                              supplier['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supplier['phone'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (supplier['email'] != 'N/A')
                                  Text(
                                    supplier['email'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: supplier['status'] == 'active'
                                    ? Colors.green[100]
                                    : Colors.red[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                supplier['status'] ?? 'active',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: supplier['status'] == 'active'
                                      ? Colors.green[800]
                                      : Colors.red[800],
                                ),
                              ),
                            ),
                            onTap: () => _showSupplierDetails(supplier),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ===================== PURCHASES SCREEN =====================
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _purchases = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('purchases')
          .orderBy('createdAt', descending: true)
          .get();

      _purchases = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List items = data['items'] ?? [];

        int quantity = 0;
        for (var item in items) {
          dynamic qty = item['quantity'];
          if (qty != null) {
            if (qty is int) {
              quantity += qty;
            } else if (qty is double) {
              quantity += qty.toInt();
            } else if (qty is String) {
              quantity += int.tryParse(qty) ?? 0;
            } else if (qty is num) {
              quantity += qty.toInt();
            }
          }
        }

        return {
          'id': doc.id,
          'supplierName': data['supplierName'] ?? 'Unknown',
          'supplierId': data['supplierId'] ?? '',
          'date': data['date'] != null
              ? (data['date'] as Timestamp).toDate()
              : DateTime.now(),
          'createdAt': data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
          'grandTotal': (data['grandTotal'] ?? 0).toDouble(),
          'gstAmount': (data['gstAmount'] ?? 0).toDouble(),
          'items': items,
          'itemCount': items.length,
          'quantity': quantity,
          'totalAmount': (data['totalAmount'] ?? 0).toDouble(),
        };
      }).toList();
    } catch (e) {
      print('Error loading purchases: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading purchases: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredPurchases {
    if (_searchQuery.isEmpty) return _purchases;
    return _purchases.where((purchase) {
      return purchase['supplierName'].toString().toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
    }).toList();
  }

  void _showPurchaseDetails(Map<String, dynamic> purchase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.receipt, color: Colors.green[700]),
            const SizedBox(width: 8),
            Text('Purchase Details', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow(
                  'Supplier',
                  purchase['supplierName'],
                  Icons.business,
                ),
                _buildDetailRow(
                  'Date',
                  DateFormat('dd MMM yyyy, hh:mm a').format(purchase['date']),
                  Icons.calendar_today,
                ),
                _buildDetailRow(
                  'Total Items',
                  purchase['itemCount'].toString(),
                  Icons.inventory,
                ),
                _buildDetailRow(
                  'Total Quantity',
                  purchase['quantity'].toString(),
                  Icons.production_quantity_limits,
                ),
                const Divider(height: 16),
                _buildDetailRow(
                  'Sub Total',
                  '₹${purchase['totalAmount'].toStringAsFixed(0)}',
                  Icons.currency_rupee,
                ),
                _buildDetailRow(
                  'GST Amount',
                  '₹${purchase['gstAmount'].toStringAsFixed(0)}',
                  Icons.receipt_long,
                ),
                const Divider(height: 16),
                _buildDetailRow(
                  'Grand Total',
                  '₹${purchase['grandTotal'].toStringAsFixed(0)}',
                  Icons.payments,
                  isTotal: true,
                ),

                const SizedBox(height: 12),
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...purchase['items'].map<Widget>((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['productName'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${(item['rate'] ?? 0).toStringAsFixed(0)} x ${item['quantity']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${(item['total'] ?? 0).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isTotal ? Colors.green[700] : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isTotal ? Colors.black87 : Colors.grey[600],
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.green[700] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by supplier name...',
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Purchase Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${_filteredPurchases.length} purchases found',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),

          const SizedBox(height: 8),

          // Purchases List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPurchases.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No purchases found',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadPurchases,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filteredPurchases.length,
                      itemBuilder: (context, index) {
                        final purchase = _filteredPurchases[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.receipt,
                                size: 20,
                                color: Colors.green[700],
                              ),
                            ),
                            title: Text(
                              purchase['supplierName'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat(
                                    'dd/MM/yy, hh:mm a',
                                  ).format(purchase['date']),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${purchase['itemCount']} items | ${purchase['quantity']} qty',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${purchase['grandTotal'].toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                                Text(
                                  '${purchase['itemCount']} items',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _showPurchaseDetails(purchase),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ===================== PRODUCTS SCREEN =====================
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snapshot = await _firestore.collection('products').get();

      _products = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'productName': data['productName'] ?? 'Unknown',
          'productType': data['productType'] ?? 'N/A',
          'brand': data['brand'] ?? 'N/A',
          'hsn': data['hsn'] ?? 'N/A',
          'gstPercentage': data['gstPercentage'] ?? 0,
          'purchaseRate': (data['purchaseRate'] ?? 0).toDouble(),
          'saleRate': (data['saleRate'] ?? 0).toDouble(),
          'createdAt': data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
        };
      }).toList();
    } catch (e) {
      print('Error loading products: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((product) {
      return product['productName'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          product['brand'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          product['productType'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
    }).toList();
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.inventory, color: Colors.green[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                product['productName'],
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Type', product['productType'], Icons.category),
              _buildDetailRow(
                'Brand',
                product['brand'],
                Icons.branding_watermark,
              ),
              _buildDetailRow('HSN Code', product['hsn'], Icons.numbers),
              _buildDetailRow(
                'GST',
                '${product['gstPercentage'].toStringAsFixed(0)}%',
                Icons.percent,
              ),
              const Divider(height: 16),
              _buildDetailRow(
                'Purchase Rate',
                '₹${product['purchaseRate'].toStringAsFixed(0)}',
                Icons.arrow_downward,
                isHighlighted: true,
              ),
              _buildDetailRow(
                'Sale Rate',
                '₹${product['saleRate'].toStringAsFixed(0)}',
                Icons.arrow_upward,
                isHighlighted: true,
              ),
              const Divider(height: 16),
              _buildDetailRow(
                'Profit',
                '₹${(product['saleRate'] - product['purchaseRate']).toStringAsFixed(0)} (${((product['saleRate'] - product['purchaseRate']) / product['purchaseRate'] * 100).toStringAsFixed(1)}%)',
                Icons.trending_up,
                isTotal: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    bool isHighlighted = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isTotal
                ? Colors.green[700]
                : isHighlighted
                ? Colors.green[600]
                : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isTotal ? Colors.black87 : Colors.grey[600],
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal
                  ? Colors.green[700]
                  : isHighlighted
                  ? Colors.green[800]
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Product Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${_filteredProducts.length} products found',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),

          const SizedBox(height: 8),

          // Products List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No products found',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadProducts,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.inventory_2,
                                size: 20,
                                color: Colors.green[700],
                              ),
                            ),
                            title: Text(
                              product['productName'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${product['brand']} | ${product['productType']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'HSN: ${product['hsn']} | GST: ${product['gstPercentage'].toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${product['saleRate'].toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                                Text(
                                  '₹${product['purchaseRate'].toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _showProductDetails(product),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
