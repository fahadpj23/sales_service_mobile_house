import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sales_stock/screens/login_screen.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'purchase/add_product_screen.dart';
import 'purchase/add_supplier_screen.dart';
import 'purchase/add_purchase_screen.dart';
import 'purchase/purchase_history_screen.dart';
import 'purchase/supplier_list_screen.dart';
import 'purchase/product_list_screen.dart';

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
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // Method to navigate to a specific screen
  void _navigateToScreen(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Close drawer if open
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
  }

  // Create screens with callbacks
  List<Widget> _buildScreens() {
    return [
      const DashboardHomeScreen(),
      AddPurchaseScreen(
        onNavigateToHistory: (index) {
          _navigateToScreen(index);
        },
      ),
      AddSupplierScreen(
        onNavigateToSupplierList: (index) {
          _navigateToScreen(index);
        },
      ),
      AddProductScreen(
        onNavigateToProductList: (index) {
          _navigateToScreen(index);
        },
      ),
      const PurchaseHistoryScreen(),
      const SupplierListScreen(),
      const ProductListScreen(),
    ];
  }

  final List<Map<String, dynamic>> _menuItems = [
    {'title': 'Dashboard', 'icon': Icons.dashboard, 'index': 0},
    {'title': 'Add Purchase', 'icon': Icons.shopping_cart_checkout, 'index': 1},
    {'title': 'Add Supplier', 'icon': Icons.add_business, 'index': 2},
    {'title': 'Add Product', 'icon': Icons.add_shopping_cart, 'index': 3},
    {'title': 'Purchase History', 'icon': Icons.history, 'index': 4},
    {'title': 'Suppliers', 'icon': Icons.business, 'index': 5},
    {'title': 'Products', 'icon': Icons.inventory, 'index': 6},
  ];

  void _onMenuItemTap(int index) {
    _navigateToScreen(index);
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Sign out from Firebase
        await _authService.signOut();

        // Clear user data from provider
        Provider.of<AuthProvider>(context, listen: false).clearUser();

        // Navigate to login screen and remove all previous routes
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } catch (e) {
        _showSnackBar('Error logging out: ${e.toString()}', Colors.red);
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build screens here to ensure callbacks are properly set
    final screens = _buildScreens();

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
          // Refresh Button
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: _isLoading ? Colors.grey : Colors.white,
            ),
            onPressed: _isLoading ? null : _refreshDashboard,
            tooltip: 'Refresh Data',
          ),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout),
            color: _isLoading ? Colors.grey : Colors.white,
            onPressed: _logout,
            tooltip: 'Logout',
          ),
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
              // Logout option in drawer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white70),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: _logout,
                  tileColor: Colors.red.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Logging out...',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : screens[_selectedIndex],
    );
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Navigate to dashboard to refresh
      _navigateToScreen(0);
      // Show success message
      _showSnackBar('Dashboard refreshed', Colors.green);
    } catch (e) {
      print('Error refreshing data: $e');
      _showSnackBar('Error refreshing data: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

enum ReportType { today, yesterday, weekly, monthly, lastMonth, yearly, custom }

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
    if (!mounted) return;
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
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              borderRadius:
                                                  BorderRadius.circular(6),
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
