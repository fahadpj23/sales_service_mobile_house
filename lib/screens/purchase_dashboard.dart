import 'package:flutter/material.dart';
import 'package:sales_stock/services/firestore_service.dart';
import 'package:sales_stock/screens/purchase/supplier_form_screen.dart';
import 'package:sales_stock/screens/purchase/create_purchase_screen.dart';
import 'package:sales_stock/screens/purchase/purchase_history_screen.dart';
import 'package:sales_stock/screens/purchase/gst_reports_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sales_stock/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:sales_stock/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class PurchaseDashboard extends StatefulWidget {
  const PurchaseDashboard({super.key});

  @override
  State<PurchaseDashboard> createState() => _PurchaseDashboardState();
}

class _PurchaseDashboardState extends State<PurchaseDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _purchases = [];
  bool _isLoading = true;
  bool _isLoadingPurchases = true;
  int _currentDrawerIndex = 0;
  String _searchQuery = '';

  // Modern green color palette
  final Color _primaryColor = const Color(0xFF1B5E20); // Dark green
  final Color _primaryLight = const Color(0xFF4CAF50); // Medium green
  final Color _accentColor = const Color(0xFF81C784); // Light green
  final Color _backgroundColor = const Color(0xFFF8FDF8); // Very light green
  final Color _cardColor = Colors.white;
  final Color _successColor = const Color(0xFF2E7D32);
  final Color _warningColor = const Color(0xFFF57C00);
  final Color _infoColor = const Color(0xFF0288D1);
  final Color _textPrimary = const Color(0xFF1A1A1A);
  final Color _textSecondary = const Color(0xFF666666);
  final Color _dividerColor = const Color(0xFFE0F2E1);

  // Gradients
  final LinearGradient _primaryGradient = const LinearGradient(
    colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final LinearGradient _accentGradient = const LinearGradient(
    colors: [Color(0xFF81C784), Color(0xFFA5D6A7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    setState(() => _isLoadingPurchases = true);

    await Future.wait([_fetchSuppliers(), _fetchPurchases()]);

    setState(() {
      _isLoading = false;
      _isLoadingPurchases = false;
    });
  }

  Future<void> _fetchSuppliers() async {
    _suppliers = await _firestoreService.getSuppliers();
  }

  Future<void> _fetchPurchases() async {
    _purchases = await _firestoreService.getPurchases();
  }

  // Calculate monthly statistics
  double get _monthlyPurchaseAmount {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    double total = 0;
    for (var purchase in _purchases) {
      final purchaseDate = (purchase['purchaseDate'] as Timestamp).toDate();
      if (purchaseDate.isAfter(firstDayOfMonth) &&
          purchaseDate.isBefore(lastDayOfMonth)) {
        total += (purchase['totalAmount'] as num).toDouble();
      }
    }
    return total;
  }

  double get _monthlyGST {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    double total = 0;
    for (var purchase in _purchases) {
      final purchaseDate = (purchase['purchaseDate'] as Timestamp).toDate();
      if (purchaseDate.isAfter(firstDayOfMonth) &&
          purchaseDate.isBefore(lastDayOfMonth)) {
        total += (purchase['gstAmount'] as num).toDouble();
      }
    }
    return total;
  }

  int get _activeSuppliersCount {
    return _suppliers.where((s) => s['status'] != 'inactive').length;
  }

  List<Map<String, dynamic>> get _filteredSuppliers {
    if (_searchQuery.isEmpty) return _suppliers;
    return _suppliers.where((supplier) {
      final name = supplier['name']?.toString().toLowerCase() ?? '';
      final phone = supplier['phone']?.toString().toLowerCase() ?? '';
      final email = supplier['email']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          phone.contains(query) ||
          email.contains(query);
    }).toList();
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout', style: TextStyle(fontSize: 16)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      Provider.of<AuthProvider>(context, listen: false).clearUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _fetchData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            color: Colors.white,
            onPressed: () => _handleLogout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildCurrentScreen(),
    );
  }

  String _getAppBarTitle() {
    switch (_currentDrawerIndex) {
      case 0:
        return 'Purchase Dashboard';
      case 1:
        return 'Add Supplier';
      case 2:
        return 'Add Purchase';
      case 3:
        return 'Suppliers';
      case 4:
        return 'Purchase History';
      case 5:
        return 'GST Reports';
      default:
        return 'Purchase';
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_backgroundColor, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                gradient: _primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.shopping_cart,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Purchase',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Management System',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildDrawerItem(
              index: 0,
              icon: Icons.dashboard_rounded,
              title: 'Dashboard',
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 12,
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(
              index: 1,
              icon: Icons.add_business_rounded,
              title: 'Add Supplier',
              accent: true,
            ),
            _buildDrawerItem(
              index: 2,
              icon: Icons.add_shopping_cart_rounded,
              title: 'Add Purchase',
              accent: true,
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Management',
                style: TextStyle(
                  fontSize: 12,
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(
              index: 3,
              icon: Icons.business_rounded,
              title: 'Suppliers',
            ),
            _buildDrawerItem(
              index: 4,
              icon: Icons.shopping_cart_rounded,
              title: 'Purchase History',
            ),
            _buildDrawerItem(
              index: 5,
              icon: Icons.receipt_long_rounded,
              title: 'GST Reports',
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.grey, height: 1),
            ),
            ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: Colors.red.shade600,
                size: 20,
              ),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              onTap: () => _handleLogout(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              minLeadingWidth: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required int index,
    required IconData icon,
    required String title,
    bool accent = false,
  }) {
    final bool isSelected = _currentDrawerIndex == index;
    final Color bgColor = accent && isSelected
        ? _successColor.withOpacity(0.15)
        : isSelected
        ? _primaryColor.withOpacity(0.1)
        : Colors.transparent;
    final Color borderColor = accent && isSelected
        ? _successColor.withOpacity(0.3)
        : isSelected
        ? _primaryColor.withOpacity(0.3)
        : Colors.transparent;
    final Color iconColor = accent && isSelected
        ? _successColor
        : isSelected
        ? _primaryColor
        : _textSecondary;
    final Color textColor = accent && isSelected
        ? _successColor
        : isSelected
        ? _primaryColor
        : _textPrimary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent
                ? _successColor.withOpacity(0.1)
                : _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 5,
                height: 20,
                decoration: BoxDecoration(
                  color: accent ? _successColor : _primaryColor,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              )
            : null,
        onTap: () {
          setState(() => _currentDrawerIndex = index);
          Navigator.pop(context);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minLeadingWidth: 28,
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentDrawerIndex) {
      case 0:
        return _buildDashboardScreen();
      case 1:
        return SupplierFormScreen();
      case 2:
        return CreatePurchaseScreen();
      case 3:
        return _buildSuppliersScreen();
      case 4:
        return PurchaseHistoryScreen();
      case 5:
        return GSTReportsScreen();
      default:
        return _buildDashboardScreen();
    }
  }

  Widget _buildDashboardScreen() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: _primaryColor, strokeWidth: 2),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: _primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Purchase Manager',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${DateFormat('EEEE, MMMM d').format(DateTime.now())}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Stats Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _buildStatCard(
                title: 'Total Suppliers',
                value: _suppliers.length.toString(),
                icon: Icons.business_rounded,
                color: _primaryColor,
                iconBgColor: _primaryColor.withOpacity(0.1),
              ),
              _buildStatCard(
                title: 'Active Suppliers',
                value: _activeSuppliersCount.toString(),
                icon: Icons.verified_rounded,
                color: _successColor,
                iconBgColor: _successColor.withOpacity(0.1),
              ),
              _buildStatCard(
                title: 'Monthly Purchases',
                value:
                    '₹${NumberFormat('#,##0.00').format(_monthlyPurchaseAmount)}',
                icon: Icons.monetization_on_rounded,
                color: _warningColor,
                iconBgColor: _warningColor.withOpacity(0.1),
              ),
              _buildStatCard(
                title: 'GST This Month',
                value: '₹${NumberFormat('#,##0.00').format(_monthlyGST)}',
                icon: Icons.receipt_rounded,
                color: _infoColor,
                iconBgColor: _infoColor.withOpacity(0.1),
              ),
              _buildStatCard(
                title: 'Total Purchases',
                value: _purchases.length.toString(),
                icon: Icons.shopping_cart_rounded,
                color: Colors.blue.shade700,
                iconBgColor: Colors.blue.shade700.withOpacity(0.1),
              ),
              _buildStatCard(
                title: 'Today\'s Purchases',
                value: _getTodaysPurchasesCount().toString(),
                icon: Icons.today_rounded,
                color: Colors.purple.shade700,
                iconBgColor: Colors.purple.shade700.withOpacity(0.1),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Quick Access Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Access',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickAccessButton(
                      icon: Icons.add_business_rounded,
                      label: 'Add Supplier',
                      onTap: () => setState(() => _currentDrawerIndex = 1),
                    ),
                    _buildQuickAccessButton(
                      icon: Icons.add_shopping_cart_rounded,
                      label: 'Add Purchase',
                      onTap: () => setState(() => _currentDrawerIndex = 2),
                    ),
                    _buildQuickAccessButton(
                      icon: Icons.list_alt_rounded,
                      label: 'View All',
                      onTap: () => setState(() => _currentDrawerIndex = 4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getTodaysPurchasesCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int count = 0;
    for (var purchase in _purchases) {
      final purchaseDate = (purchase['purchaseDate'] as Timestamp).toDate();
      if (purchaseDate.isAfter(today)) {
        count++;
      }
    }
    return count;
  }

  Widget _buildQuickAccessButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: _primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSuppliersScreen() {
    return Column(
      children: [
        // Header with search
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Suppliers',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_suppliers.length} Total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search suppliers...',
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _primaryColor,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor, width: 1.5),
                  ),
                  filled: true,
                  fillColor: _backgroundColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ],
          ),
        ),

        // Suppliers List
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: _primaryColor))
              : _filteredSuppliers.isEmpty
              ? _buildEmptyState(
                  icon: Icons.business_rounded,
                  message: 'No suppliers found',
                  subMessage: _searchQuery.isEmpty
                      ? 'Add your first supplier to get started'
                      : 'No results for "$_searchQuery"',
                  actionText: 'Add Supplier',
                  onAction: () => setState(() => _currentDrawerIndex = 1),
                )
              : RefreshIndicator(
                  onRefresh: _fetchSuppliers,
                  color: _primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredSuppliers.length,
                    itemBuilder: (context, index) {
                      final supplier = _filteredSuppliers[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: _accentGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.business_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            supplier['name'] ?? 'Unnamed Supplier',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: supplier['phone'] != null
                              ? Text(
                                  supplier['phone']!,
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 14,
                                  ),
                                )
                              : null,
                          trailing: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.more_vert_rounded,
                              color: _primaryColor,
                              size: 20,
                            ),
                          ),
                          onTap: () => _showSupplierDetails(supplier),
                          onLongPress: () =>
                              _showSupplierMenu(context, supplier),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color iconBgColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: _dividerColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subMessage,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: _primaryColor.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subMessage,
            style: TextStyle(color: _textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                actionText,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSupplierMenu(BuildContext context, Map<String, dynamic> supplier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: _accentGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.business_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplier['name'] ?? 'Unnamed Supplier',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          if (supplier['phone'] != null)
                            Text(
                              supplier['phone']!,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildMenuTile(
                icon: Icons.visibility_rounded,
                title: 'View Details',
                color: _infoColor,
                onTap: () {
                  Navigator.pop(context);
                  _showSupplierDetails(supplier);
                },
              ),
              _buildMenuTile(
                icon: Icons.edit_rounded,
                title: 'Edit Supplier',
                color: _primaryColor,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SupplierFormScreen(supplier: supplier),
                    ),
                  ).then((_) => _fetchSuppliers());
                },
              ),
              _buildMenuTile(
                icon: Icons.add_shopping_cart_rounded,
                title: 'Create Purchase',
                color: _successColor,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CreatePurchaseScreen(supplier: supplier),
                    ),
                  );
                },
              ),
              const Divider(height: 0),
              _buildMenuTile(
                icon: Icons.delete_rounded,
                title: 'Delete Supplier',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _deleteSupplier(supplier['id']);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 20,
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }

  String _formatDate(Timestamp timestamp) {
    return DateFormat('dd MMM yyyy HH:mm').format(timestamp.toDate());
  }

  void _showSupplierDetails(Map<String, dynamic> supplier) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: _primaryGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Supplier Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Name', supplier['name']),
                    _buildDetailRow('Phone', supplier['phone']),
                    _buildDetailRow('Email', supplier['email']),
                    _buildDetailRow('GST', supplier['gstNumber']),
                    _buildDetailRow('Address', supplier['address']),
                    _buildDetailRow('Status', supplier['status'] ?? 'Active'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: _primaryColor, width: 1.5),
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SupplierFormScreen(supplier: supplier),
                            ),
                          ).then((_) => _fetchSuppliers());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
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
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? 'Not provided',
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSupplier(String? supplierId) async {
    if (supplierId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier', style: TextStyle(fontSize: 16)),
        content: const Text(
          'Are you sure you want to delete this supplier?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteSupplier(supplierId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Supplier deleted'),
            backgroundColor: _successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchSuppliers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
