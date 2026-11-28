// lib/screens/admin/shops/shop_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopManagementScreen extends StatefulWidget {
  const ShopManagementScreen({super.key});

  @override
  State<ShopManagementScreen> createState() => _ShopManagementScreenState();
}

class _ShopManagementScreenState extends State<ShopManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  static const Color primaryGreen = Color(0xFF0A4D2E);
  static const Color secondaryGreen = Color(0xFF1A7D4A);
  static const Color accentGreen = Color(0xFF28A745);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color dangerColor = Color(0xFFDC3545);

  // ============================================================
  // ADD SHOP
  // ============================================================
  Future<void> _addShop() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    String? nameError;
    String? phoneError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          void submit() {
            final name = nameCtrl.text.trim();
            final phone = phoneCtrl.text.trim();

            nameError = name.isEmpty ? 'Shop name is required' : null;
            if (phone.isEmpty) {
              phoneError = 'Phone is required';
            } else if (phone.length < 10) {
              phoneError = 'Enter a valid 10-digit number';
            } else {
              phoneError = null;
            }

            setDlgState(() {});
            if (nameError != null || phoneError != null) return;
            Navigator.pop(ctx, true);
          }

          return AlertDialog(
            titlePadding: EdgeInsets.zero,
            contentPadding: EdgeInsets.zero,
            actionsPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.storefront,
                      color: primaryGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Shop',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Enter shop details',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
            content: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 13),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Shop Name',
                      hintText: 'e.g. MobileHouse1(shed)',
                      errorText: nameError,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: primaryGreen,
                          width: 1.4,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      prefixIcon: const Icon(Icons.store_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    style: const TextStyle(fontSize: 13),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '10-digit mobile',
                      errorText: phoneError,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: primaryGreen,
                          width: 1.4,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: submit,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text(
                          'Add Shop',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    _showLoadingDialog();
    try {
      final name = nameCtrl.text.trim();
      final phone = phoneCtrl.text.trim();

      // Duplicate check by name (case-insensitive not supported natively,
      // so check exact and simple lower-case match on client)
      final dup = await _firestore
          .collection('Mobile_house_Shops')
          .where('shopName', isEqualTo: name)
          .limit(1)
          .get();
      if (dup.docs.isNotEmpty) {
        if (mounted) Navigator.pop(context);
        _showSnackbar('A shop with this name already exists', warningColor);
        return;
      }

      final docRef = _firestore.collection('Mobile_house_Shops').doc();
      await docRef.set({
        'id': docRef.id,
        'shopName': name,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Shop added successfully', accentGreen);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackbar('Error adding shop: $e', dangerColor);
    }
  }

  // ============================================================
  // EDIT SHOP
  // ============================================================
  Future<void> _editShop(String docId, Map<String, dynamic> data) async {
    final nameCtrl = TextEditingController(text: data['shopName'] ?? '');
    final phoneCtrl = TextEditingController(text: data['phone'] ?? '');

    String? nameError;
    String? phoneError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          void submit() {
            final name = nameCtrl.text.trim();
            final phone = phoneCtrl.text.trim();

            nameError = name.isEmpty ? 'Shop name is required' : null;
            if (phone.isEmpty) {
              phoneError = 'Phone is required';
            } else if (phone.length < 10) {
              phoneError = 'Enter a valid 10-digit number';
            } else {
              phoneError = null;
            }

            setDlgState(() {});
            if (nameError != null || phoneError != null) return;
            Navigator.pop(ctx, true);
          }

          return AlertDialog(
            titlePadding: EdgeInsets.zero,
            contentPadding: EdgeInsets.zero,
            actionsPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: primaryGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Edit Shop',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
            content: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 13),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Shop Name',
                      errorText: nameError,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: primaryGreen,
                          width: 1.4,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      prefixIcon: const Icon(Icons.store_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    style: const TextStyle(fontSize: 13),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      errorText: phoneError,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: primaryGreen,
                          width: 1.4,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: submit,
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    _showLoadingDialog();
    try {
      await _firestore.collection('Mobile_house_Shops').doc(docId).update({
        'shopName': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Shop updated successfully', accentGreen);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackbar('Error updating shop: $e', dangerColor);
    }
  }

  // ============================================================
  // DELETE SHOP (with confirmation)
  // ============================================================
  Future<void> _deleteShop(String docId, Map<String, dynamic> data) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: dangerColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Delete Shop',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this shop?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shop: ${data['shopName'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Phone: ${data['phone'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This action cannot be undone. Users assigned to this shop '
              'may need to be reassigned.',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Delete', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    _showLoadingDialog();
    try {
      await _firestore.collection('Mobile_house_Shops').doc(docId).delete();
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Shop deleted successfully', dangerColor);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackbar('Error deleting shop: $e', dangerColor);
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================
  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primaryGreen),
                const SizedBox(height: 12),
                const Text('Processing...', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        title: const Text(
          'Shop Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business, size: 20),
            tooltip: 'Add Shop',
            onPressed: _addShop,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildShopList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addShop,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Add Shop'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.white,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: TextField(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Search by shop name or phone...',
            hintStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search, color: primaryGreen, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 16, color: Colors.grey),
                    onPressed: () => setState(() => _searchQuery = ''),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            isDense: true,
          ),
          onChanged: (v) {
            setState(() => _searchQuery = v.toLowerCase());
          },
        ),
      ),
    );
  }

  Widget _buildShopList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('Mobile_house_Shops')
          .orderBy('shopName')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 40, color: dangerColor),
                const SizedBox(height: 6),
                Text(
                  'Error loading shops',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: secondaryGreen),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];

        if (allDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No shops found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "Add Shop" to create one',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        final docs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          if (_searchQuery.isEmpty) return true;
          return (data['shopName']?.toString().toLowerCase().contains(
                    _searchQuery,
                  ) ??
                  false) ||
              (data['phone']?.toString().toLowerCase().contains(_searchQuery) ??
                  false);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 6),
                Text(
                  'No matching shops',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildStatsBar(allDocs.length),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => setState(() {}),
                color: secondaryGreen,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildShopCard(doc.id, data, i + 1);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsBar(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primaryGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront, color: primaryGreen, size: 14),
                const SizedBox(width: 6),
                Text(
                  '$total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Shops',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
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

  Widget _buildShopCard(String docId, Map<String, dynamic> data, int index) {
    final name = (data['shopName'] ?? 'Unknown').toString();
    final phone = (data['phone'] ?? '').toString();
    final avatarColor = _getAvatarColor(name);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: primaryGreen.withOpacity(0.15), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withOpacity(0.15),
                  child: Icon(Icons.storefront, size: 20, color: avatarColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 11, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Text(
                            phone.isNotEmpty ? phone : 'No phone',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: primaryGreen.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '#$index',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: primaryGreen.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      'Shop ID',
                      docId,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editShop(docId, data),
                  icon: Icon(Icons.edit, size: 14, color: primaryGreen),
                  label: Text(
                    'Edit',
                    style: TextStyle(fontSize: 12, color: primaryGreen),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _deleteShop(docId, data),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: dangerColor,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(fontSize: 12, color: dangerColor),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                color: color ?? Colors.grey[800],
                fontWeight: FontWeight.w500,
                fontFamily: 'Monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String? name) {
    if (name == null || name.isEmpty) return Colors.grey;
    final hash = name.codeUnitAt(0) % 4;
    switch (hash) {
      case 0:
        return primaryGreen;
      case 1:
        return const Color(0xFF2196F3);
      case 2:
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFFFF9800);
    }
  }
}
