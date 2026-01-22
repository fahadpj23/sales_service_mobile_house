import 'package:flutter/material.dart';
import 'package:sales_stock/services/firestore_service.dart';
import 'package:sales_stock/screens/purchase/supplier_form_screen.dart';
import 'package:sales_stock/screens/purchase/create_purchase_screen.dart';
import 'package:sales_stock/screens/purchase/purchase_history_screen.dart';
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
  int _currentDrawerIndex = 0; // 0: Dashboard, 1: Suppliers, 2: Purchases

  // Define green color palette
  final Color _primaryGreen = const Color(0xFF2E7D32);
  final Color _lightGreen = const Color(0xFF4CAF50);
  final Color _accentGreen = const Color(0xFF81C784);
  final Color _darkGreen = const Color(0xFF1B5E20);
  final Color _backgroundColor = const Color(0xFFF5F9F5);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
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
      default:
        return 'Purchase Management';
    }
  }

  List<Widget> _buildAppBarActions() {
    switch (_currentDrawerIndex) {
      case 0:
      case 1:
        return [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _fetchSuppliers,
            tooltip: 'Refresh',
          ),
        ];
      case 2:
        return [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart, size: 20),
            onPressed: _navigateToCreatePurchase,
            tooltip: 'New Purchase',
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
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.add_business, size: 20),
        );
      case 2:
        return FloatingActionButton(
          onPressed: () => _navigateToCreatePurchase(),
          backgroundColor: _lightGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.add_shopping_cart, size: 20),
        );
      default:
        return null;
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(color: _primaryGreen),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart, size: 32, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    'Purchase Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Dashboard Option
                ListTile(
                  leading: Icon(
                    Icons.dashboard,
                    size: 20,
                    color: _currentDrawerIndex == 0
                        ? _lightGreen
                        : Colors.grey.shade700,
                  ),
                  title: Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _currentDrawerIndex == 0
                          ? _darkGreen
                          : Colors.grey.shade700,
                    ),
                  ),
                  tileColor: _currentDrawerIndex == 0
                      ? _lightGreen.withOpacity(0.1)
                      : null,
                  onTap: () {
                    setState(() => _currentDrawerIndex = 0);
                    Navigator.pop(context);
                  },
                ),
                // Suppliers Option
                ListTile(
                  leading: Icon(
                    Icons.business,
                    size: 20,
                    color: _currentDrawerIndex == 1
                        ? _lightGreen
                        : Colors.grey.shade700,
                  ),
                  title: Text(
                    'Suppliers',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _currentDrawerIndex == 1
                          ? _darkGreen
                          : Colors.grey.shade700,
                    ),
                  ),
                  tileColor: _currentDrawerIndex == 1
                      ? _lightGreen.withOpacity(0.1)
                      : null,
                  onTap: () {
                    setState(() => _currentDrawerIndex = 1);
                    Navigator.pop(context);
                  },
                ),
                // Purchases Option
                ListTile(
                  leading: Icon(
                    Icons.shopping_cart,
                    size: 20,
                    color: _currentDrawerIndex == 2
                        ? _lightGreen
                        : Colors.grey.shade700,
                  ),
                  title: Text(
                    'Purchases',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _currentDrawerIndex == 2
                          ? _darkGreen
                          : Colors.grey.shade700,
                    ),
                  ),
                  tileColor: _currentDrawerIndex == 2
                      ? _lightGreen.withOpacity(0.1)
                      : null,
                  onTap: () {
                    setState(() => _currentDrawerIndex = 2);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 20),
                // Quick Actions
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
                  child: Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.add_business,
                    size: 18,
                    color: _darkGreen,
                  ),
                  title: Text(
                    'Add Supplier',
                    style: TextStyle(fontSize: 13, color: _darkGreen),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToSupplierForm();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.add_shopping_cart,
                    size: 18,
                    color: _darkGreen,
                  ),
                  title: Text(
                    'New Purchase',
                    style: TextStyle(fontSize: 13, color: _darkGreen),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToCreatePurchase();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
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
            CircularProgressIndicator(color: _primaryGreen, strokeWidth: 2),
            const SizedBox(height: 12),
            Text(
              'Loading...',
              style: TextStyle(color: _primaryGreen, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _lightGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.analytics, size: 24, color: _primaryGreen),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Purchase Overview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _darkGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your suppliers and purchases',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildDashboardStatCard(
                title: 'Total Suppliers',
                value: _suppliers.length.toString(),
                icon: Icons.business,
                color: Colors.blue.shade700,
              ),
              _buildDashboardStatCard(
                title: 'Active Suppliers',
                value: _suppliers
                    .where((s) => s['status'] != 'inactive')
                    .length
                    .toString(),
                icon: Icons.check_circle,
                color: _lightGreen,
              ),
              _buildDashboardStatCard(
                title: 'This Month Purchases',
                value: '₹${_getMonthlyPurchaseAmount()}',
                icon: Icons.shopping_cart,
                color: Colors.orange.shade700,
              ),
              _buildDashboardStatCard(
                title: 'Pending Payments',
                value: '₹0',
                icon: Icons.payment,
                color: Colors.red.shade700,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _darkGreen,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildDashboardActionCard(
                title: 'Add Supplier',
                icon: Icons.add_business,
                color: _lightGreen,
                onTap: _navigateToSupplierForm,
              ),
              _buildDashboardActionCard(
                title: 'New Purchase',
                icon: Icons.add_shopping_cart,
                color: Colors.blue.shade700,
                onTap: _navigateToCreatePurchase,
              ),
              _buildDashboardActionCard(
                title: 'View Suppliers',
                icon: Icons.business,
                color: Colors.purple.shade700,
                onTap: () => setState(() => _currentDrawerIndex = 1),
              ),
              _buildDashboardActionCard(
                title: 'Purchase History',
                icon: Icons.history,
                color: Colors.teal.shade700,
                onTap: () => setState(() => _currentDrawerIndex = 2),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Recent Suppliers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Suppliers',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _darkGreen,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _currentDrawerIndex = 1),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    color: _lightGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
            CircularProgressIndicator(color: _primaryGreen, strokeWidth: 2),
            const SizedBox(height: 12),
            Text(
              'Loading...',
              style: TextStyle(color: _primaryGreen, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_suppliers.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search suppliers...',
                      border: InputBorder.none,
                      icon: Icon(Icons.search, size: 18, color: _primaryGreen),
                      hintStyle: TextStyle(fontSize: 13),
                    ),
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.filter_list, size: 18, color: _primaryGreen),
              ),
            ],
          ),
        ),

        // Suppliers List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchSuppliers,
            color: _primaryGreen,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _suppliers.length,
              itemBuilder: (context, index) {
                final supplier = _suppliers[index];
                return _buildSupplierCard(supplier);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardActionCard({
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
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierListItem(Map<String, dynamic> supplier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _lightGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.business, size: 18, color: _lightGreen),
        ),
        title: Text(
          supplier['name'] ?? 'Unnamed',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _darkGreen,
          ),
        ),
        subtitle: supplier['phone'] != null
            ? Text(
                supplier['phone']!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
            : null,
        trailing: Icon(Icons.chevron_right, size: 18, color: _primaryGreen),
        onTap: () => _showSupplierDetails(supplier),
      ),
    );
  }

  Widget _buildSupplierCard(Map<String, dynamic> supplier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
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
            color: _lightGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.business, size: 22, color: _lightGreen),
        ),
        title: Text(
          supplier['name'] ?? 'Unnamed Supplier',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _darkGreen,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (supplier['phone'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      supplier['phone']!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            if (supplier['email'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.email, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        supplier['email']!,
                        style: TextStyle(
                          fontSize: 13,
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
          icon: Icon(Icons.more_vert, size: 20, color: _primaryGreen),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 18, color: _primaryGreen),
                  const SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18, color: _primaryGreen),
                  const SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'purchase',
              child: Row(
                children: [
                  Icon(Icons.add_shopping_cart, size: 18, color: _lightGreen),
                  const SizedBox(width: 8),
                  Text('New Purchase'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Delete'),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _lightGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_outlined,
                size: 60,
                color: _primaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Suppliers Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first supplier to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.add_business, size: 18),
              label: Text('Add Supplier', style: TextStyle(fontSize: 14)),
              onPressed: _navigateToSupplierForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _lightGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthlyPurchaseAmount() {
    // Mock data - replace with actual calculation
    return '12,450';
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SupplierDetailsModal(supplier: supplier),
    );
  }

  Future<void> _deleteSupplier(String? supplierId) async {
    if (supplierId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Supplier', style: TextStyle(color: _darkGreen)),
        content: Text('Are you sure you want to delete this supplier?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _primaryGreen)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
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
              content: Text('Supplier deleted'),
              backgroundColor: _lightGreen,
            ),
          );
        }
        _fetchSuppliers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

// Supplier Details Modal
class SupplierDetailsModal extends StatelessWidget {
  final Map<String, dynamic> supplier;

  const SupplierDetailsModal({Key? key, required this.supplier})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF2E7D32);
    final Color lightGreen = const Color(0xFF4CAF50);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Supplier Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: primaryGreen,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Supplier Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: lightGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.business, size: 20, color: lightGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        supplier['name'] ?? 'Unnamed Supplier',
                        style: TextStyle(
                          fontSize: 16,
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
                  childAspectRatio: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _buildDetailItem('Phone', supplier['phone']),
                    _buildDetailItem('Email', supplier['email']),
                    _buildDetailItem('GST', supplier['gstNumber']),
                    _buildDetailItem('Status', supplier['status'] ?? 'Active'),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        supplier['address']!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.edit, size: 16),
                        label: Text('Edit', style: TextStyle(fontSize: 13)),
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
                          side: BorderSide(color: primaryGreen),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.add_shopping_cart, size: 16),
                        label: Text(
                          'New Purchase',
                          style: TextStyle(fontSize: 13),
                        ),
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
                          padding: const EdgeInsets.symmetric(vertical: 10),
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
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value ?? 'Not provided',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
        ),
      ],
    );
  }
}
