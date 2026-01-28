import 'package:flutter/material.dart';
import 'package:sales_stock/services/firestore_service.dart';
import 'package:sales_stock/screens/purchase/supplier_form_screen.dart';
import 'package:sales_stock/screens/purchase/create_purchase_screen.dart';
import 'package:sales_stock/screens/purchase/purchase_history_screen.dart';
import 'package:sales_stock/screens/purchase/gst_reports_screen.dart'; // Add this import
import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseDashboard extends StatefulWidget {
  const PurchaseDashboard({super.key});

  @override
  State<PurchaseDashboard> createState() => _PurchaseDashboardState();
}

class _PurchaseDashboardState extends State<PurchaseDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  int _currentDrawerIndex = 0;
  String _searchQuery = '';

  // Define compact green color palette
  final Color _primaryGreen = const Color(0xFF2E7D32);
  final Color _lightGreen = const Color(0xFF4CAF50);
  final Color _accentGreen = const Color(0xFF81C784);
  final Color _darkGreen = const Color(0xFF1B5E20);
  final Color _backgroundColor = const Color(0xFFF8FBF8);

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  Future<void> _fetchSuppliers() async {
    setState(() => _isLoading = true);
    _suppliers = await _firestoreService.getSuppliers();
    setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: _buildAppBarActions(),
      ),
      drawer: _buildDrawer(),
      body: _buildCurrentScreen(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  String _getAppBarTitle() {
    switch (_currentDrawerIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Suppliers';
      case 2:
        return 'Purchases';
      case 3:
        return 'GST Reports';
      default:
        return 'Purchase';
    }
  }

  List<Widget> _buildAppBarActions() {
    switch (_currentDrawerIndex) {
      case 0:
      case 1:
        return [
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _fetchSuppliers,
            tooltip: 'Refresh',
            padding: EdgeInsets.zero,
          ),
        ];
      case 2:
        return [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            onPressed: _navigateToCreatePurchase,
            tooltip: 'New Purchase',
            padding: EdgeInsets.zero,
          ),
        ];
      case 3:
        return [
          IconButton(
            icon: const Icon(Icons.download, size: 18),
            onPressed: () {
              // Export functionality for GST reports
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Exporting GST Report...',
                    style: TextStyle(fontSize: 12),
                  ),
                  backgroundColor: _lightGreen,
                ),
              );
            },
            tooltip: 'Export Report',
            padding: EdgeInsets.zero,
          ),
        ];
      default:
        return [];
    }
  }

  Widget? _buildFloatingActionButton() {
    switch (_currentDrawerIndex) {
      case 1:
        return FloatingActionButton(
          onPressed: () => _navigateToSupplierForm(),
          backgroundColor: _lightGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
          mini: true,
          child: const Icon(Icons.add, size: 18),
        );
      case 2:
        return FloatingActionButton(
          onPressed: () => _navigateToCreatePurchase(),
          backgroundColor: _lightGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
          mini: true,
          child: const Icon(Icons.add_shopping_cart, size: 18),
        );
      default:
        return null;
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.7,
      child: Column(
        children: [
          // Compact Header
          Container(
            height: 100,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _primaryGreen),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart, size: 28, color: Colors.white),
                const SizedBox(height: 6),
                Text(
                  'Purchase',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  index: 0,
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                ),
                _buildDrawerItem(
                  index: 1,
                  icon: Icons.business,
                  label: 'Suppliers',
                ),
                _buildDrawerItem(
                  index: 2,
                  icon: Icons.shopping_cart,
                  label: 'Purchases',
                ),
                _buildDrawerItem(
                  index: 3,
                  icon: Icons.description,
                  label: 'GST Reports',
                ),
                const Divider(height: 20, thickness: 0.5),

                // Quick Actions
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
                  child: Text(
                    'QUICK ACTIONS',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.add_business,
                    size: 16,
                    color: _darkGreen,
                  ),
                  title: Text(
                    'Add Supplier',
                    style: TextStyle(fontSize: 12, color: _darkGreen),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToSupplierForm();
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.add_shopping_cart,
                    size: 16,
                    color: _darkGreen,
                  ),
                  title: Text(
                    'New Purchase',
                    style: TextStyle(fontSize: 12, color: _darkGreen),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToCreatePurchase();
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: _darkGreen,
                  ),
                  title: Text(
                    'GST Reports',
                    style: TextStyle(fontSize: 12, color: _darkGreen),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentDrawerIndex = 3);
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(
        icon,
        size: 18,
        color: _currentDrawerIndex == index
            ? _lightGreen
            : Colors.grey.shade700,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: _currentDrawerIndex == index
              ? FontWeight.w600
              : FontWeight.w500,
          color: _currentDrawerIndex == index
              ? _darkGreen
              : Colors.grey.shade700,
        ),
      ),
      tileColor: _currentDrawerIndex == index
          ? _lightGreen.withOpacity(0.08)
          : null,
      onTap: () {
        setState(() => _currentDrawerIndex = index);
        Navigator.pop(context);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentDrawerIndex) {
      case 0:
        return _buildDashboardScreen();
      case 1:
        return _buildSuppliersScreen();
      case 2:
        return PurchaseHistoryScreen();
      case 3:
        return GSTReportsScreen(); // New GST Reports Screen
      default:
        return _buildDashboardScreen();
    }
  }

  Widget _buildDashboardScreen() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: _primaryGreen,
                strokeWidth: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(color: _primaryGreen, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            padding: EdgeInsets.zero,
            children: [
              _buildStatCard(
                title: 'Total Suppliers',
                value: _suppliers.length.toString(),
                icon: Icons.business,
                color: Colors.blue.shade700,
              ),
              _buildStatCard(
                title: 'Active',
                value: _suppliers
                    .where((s) => s['status'] != 'inactive')
                    .length
                    .toString(),
                icon: Icons.check_circle,
                color: _lightGreen,
              ),
              _buildStatCard(
                title: 'This Month',
                value: '₹${_getMonthlyPurchaseAmount()}',
                icon: Icons.shopping_cart,
                color: Colors.orange.shade700,
              ),
              _buildStatCard(
                title: 'GST This Month',
                value: '₹${_getMonthlyGST()}',
                icon: Icons.receipt,
                color: Colors.purple.shade700,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _darkGreen,
              ),
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            padding: EdgeInsets.zero,
            children: [
              _buildActionCard(
                title: 'Add Supplier',
                icon: Icons.add_business,
                color: _lightGreen,
                onTap: _navigateToSupplierForm,
              ),
              _buildActionCard(
                title: 'New Purchase',
                icon: Icons.add_shopping_cart,
                color: Colors.blue.shade700,
                onTap: _navigateToCreatePurchase,
              ),
              _buildActionCard(
                title: 'Suppliers',
                icon: Icons.business,
                color: Colors.purple.shade700,
                onTap: () => setState(() => _currentDrawerIndex = 1),
              ),
              _buildActionCard(
                title: 'GST Reports',
                icon: Icons.description,
                color: Colors.teal.shade700,
                onTap: () => setState(() => _currentDrawerIndex = 3),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Recent Suppliers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Recent Suppliers',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _darkGreen,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _currentDrawerIndex = 1),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                ),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 11,
                    color: _lightGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._suppliers
              .take(3)
              .map((supplier) => _buildSupplierListItem(supplier)),
        ],
      ),
    );
  }

  Widget _buildSuppliersScreen() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: _primaryGreen,
                strokeWidth: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(color: _primaryGreen, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Compact Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300, width: 0.5),
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search suppliers...',
                      border: InputBorder.none,
                      icon: Icon(Icons.search, size: 16, color: _primaryGreen),
                      hintStyle: TextStyle(fontSize: 12),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: _accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: IconButton(
                  icon: Icon(Icons.filter_list, size: 16, color: _primaryGreen),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),

        if (_filteredSuppliers.isEmpty && !_isLoading)
          Expanded(child: _buildEmptyState())
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchSuppliers,
              color: _primaryGreen,
              displacement: 40,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _filteredSuppliers.length,
                itemBuilder: (context, index) {
                  final supplier = _filteredSuppliers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _buildSupplierCard(supplier),
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 14, color: color),
                ),
                const Spacer(),
                if (title == 'This Month' || title == 'GST This Month')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      title == 'This Month' ? 'Purchase' : 'GST',
                      style: TextStyle(fontSize: 8, color: color),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: color.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierListItem(Map<String, dynamic> supplier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _lightGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.business, size: 14, color: _lightGreen),
        ),
        title: Text(
          supplier['name'] ?? 'Unnamed',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _darkGreen,
          ),
        ),
        subtitle: supplier['phone'] != null
            ? Text(
                supplier['phone']!,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              )
            : null,
        trailing: Icon(Icons.chevron_right, size: 14, color: _primaryGreen),
        onTap: () => _showSupplierDetails(supplier),
      ),
    );
  }

  Widget _buildSupplierCard(Map<String, dynamic> supplier) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _lightGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.business, size: 16, color: _lightGreen),
        ),
        title: Text(
          supplier['name'] ?? 'Unnamed Supplier',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _darkGreen,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (supplier['phone'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      supplier['phone']!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            if (supplier['email'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Row(
                  children: [
                    Icon(Icons.email, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        supplier['email']!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 16, color: _primaryGreen),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 14, color: _primaryGreen),
                  const SizedBox(width: 6),
                  Text('View', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 14, color: _primaryGreen),
                  const SizedBox(width: 6),
                  Text('Edit', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'purchase',
              child: Row(
                children: [
                  Icon(Icons.add_shopping_cart, size: 14, color: _lightGreen),
                  const SizedBox(width: 6),
                  Text('Purchase', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Text('Delete', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'view') {
              _showSupplierDetails(supplier);
            } else if (value == 'edit') {
              _navigateToSupplierForm(supplier: supplier);
            } else if (value == 'purchase') {
              _navigateToCreatePurchase(supplier: supplier);
            } else if (value == 'delete') {
              _deleteSupplier(supplier['id']);
            }
          },
        ),
        onTap: () => _showSupplierDetails(supplier),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _lightGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_outlined,
                size: 40,
                color: _primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Suppliers Found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _darkGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your first supplier to get started',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.add, size: 14),
              label: Text('Add Supplier', style: TextStyle(fontSize: 12)),
              onPressed: _navigateToSupplierForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _lightGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthlyPurchaseAmount() {
    // This should be replaced with actual data from your database
    return '12,450';
  }

  String _getMonthlyGST() {
    // This should be replaced with actual data from your database
    return '2,241';
  }

  void _navigateToSupplierForm({Map<String, dynamic>? supplier}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierFormScreen(supplier: supplier),
      ),
    );
    _fetchSuppliers();
  }

  void _navigateToCreatePurchase({Map<String, dynamic>? supplier}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePurchaseScreen(supplier: supplier),
      ),
    );
  }

  void _showSupplierDetails(Map<String, dynamic> supplier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SupplierDetailsModal(supplier: supplier),
    );
  }

  Future<void> _deleteSupplier(String? supplierId) async {
    if (supplierId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Supplier',
          style: TextStyle(
            fontSize: 14,
            color: _darkGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this supplier?',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: 12, color: _primaryGreen),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text('Delete', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteSupplier(supplierId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Supplier deleted', style: TextStyle(fontSize: 12)),
              backgroundColor: _lightGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        _fetchSuppliers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e', style: TextStyle(fontSize: 12)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class SupplierDetailsModal extends StatelessWidget {
  final Map<String, dynamic> supplier;

  const SupplierDetailsModal({Key? key, required this.supplier})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF2E7D32);
    final Color lightGreen = const Color(0xFF4CAF50);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Supplier Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            const Divider(height: 0, thickness: 0.5),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic Info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: lightGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.business,
                          size: 16,
                          color: lightGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          supplier['name'] ?? 'Unnamed Supplier',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Details Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 3.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      _buildDetailItem('Phone', supplier['phone']),
                      _buildDetailItem('Email', supplier['email']),
                      _buildDetailItem('GST', supplier['gstNumber']),
                      _buildDetailItem(
                        'Status',
                        supplier['status'] ?? 'Active',
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Address
                  if (supplier['address'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Address',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          supplier['address']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SupplierFormScreen(supplier: supplier),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryGreen,
                            side: BorderSide(color: primaryGreen, width: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit, size: 14),
                              const SizedBox(width: 4),
                              Text('Edit', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CreatePurchaseScreen(supplier: supplier),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lightGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_shopping_cart, size: 14),
                              const SizedBox(width: 4),
                              Text('Purchase', style: TextStyle(fontSize: 12)),
                            ],
                          ),
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
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value ?? 'Not provided',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
