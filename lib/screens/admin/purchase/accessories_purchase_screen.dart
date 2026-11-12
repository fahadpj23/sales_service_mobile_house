// lib/screens/admin/purchase/accessories_purchase_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

class AccessoriesPurchaseScreen extends StatefulWidget {
  final Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  const AccessoriesPurchaseScreen({
    super.key,
    required this.formatNumber,
    required this.shops,
  });

  @override
  State<AccessoriesPurchaseScreen> createState() =>
      _AccessoriesPurchaseScreenState();
}

class _AccessoriesPurchaseScreenState extends State<AccessoriesPurchaseScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedShopId;
  bool _isSaving = false;
  bool _showForm = false; // toggles between history and form

  // Colors
  final Color primaryGreen = const Color(0xFF0A4D2E);
  final Color secondaryGreen = const Color(0xFF1A7D4A);
  final Color lightGreen = const Color(0xFFE8F5E9);

  @override
  void initState() {
    super.initState();
    // Default to first shop
    if (widget.shops.isNotEmpty) {
      _selectedShopId = widget.shops.first['id'] as String;
    }
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ==================== DATE PICKER ====================
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          primaryColor: secondaryGreen,
          colorScheme: ColorScheme.light(primary: secondaryGreen),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // ==================== SAVE PURCHASE ====================
  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedShopId == null || _selectedShopId!.isEmpty) {
      _showSnack('Please select a shop', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final shopMap = widget.shops.firstWhere(
        (s) => s['id'] == _selectedShopId,
        orElse: () => {'name': 'Unknown Shop'},
      );

      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final supplier = _supplierController.text.trim();

      await _firestore.collection('accessoriesPurchase').add({
        'shopId': _selectedShopId,
        'shopName': shopMap['name'] ?? 'Unknown Shop',
        'supplier': supplier,
        'amount': amount,
        'date': Timestamp.fromDate(_selectedDate),
        'dateString': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'notes': _notesController.text.trim(),
        'uploadedByEmail': user?.email ?? 'unknown',
        'uploadedByName': user?.name ?? user?.email ?? 'unknown',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSnack(
        'Purchase of ₹${amount.toStringAsFixed(2)} from "$supplier" saved',
      );

      // Reset form
      _supplierController.clear();
      _amountController.clear();
      _notesController.clear();
      setState(() {
        _selectedDate = DateTime.now();
        _isSaving = false;
        _showForm = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Error saving: $e', isError: true);
    }
  }

  // ==================== DELETE PURCHASE ====================
  Future<void> _deletePurchase(String docId, String supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase'),
        content: Text(
          'Delete purchase record from "$supplier"?\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('accessoriesPurchase').doc(docId).delete();
      _showSnack('Deleted');
    } catch (e) {
      _showSnack('Error deleting: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : secondaryGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        title: Text(
          _showForm ? 'Upload Accessories Purchase' : 'Accessories Purchase',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(_showForm ? Icons.arrow_back : Icons.menu),
          onPressed: () {
            if (_showForm) {
              setState(() => _showForm = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (!_showForm)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Purchase',
              onPressed: () => setState(() => _showForm = true),
            ),
        ],
      ),
      body: _showForm ? _buildForm() : _buildHistory(),
    );
  }

  // ==================== FORM ====================
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryGreen, secondaryGreen],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_shopping_cart, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Accessories Purchase',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Record supplier-wise purchase details',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Supplier
            _buildLabel('Supplier'),
            TextFormField(
              controller: _supplierController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                hint: 'Enter supplier name',
                icon: Icons.business,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter supplier name';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Shop selector
            _buildLabel('Shop'),
            DropdownButtonFormField<String>(
              value: _selectedShopId,
              decoration: _inputDecoration(
                hint: 'Select shop',
                icon: Icons.store,
              ),
              items: widget.shops
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s['id'] as String,
                      child: Text(
                        s['name'] as String,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedShopId = v),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please select a shop' : null,
            ),
            const SizedBox(height: 14),

            // Date
            _buildLabel('Date'),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.edit, size: 16, color: secondaryGreen),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Amount
            _buildLabel('Amount (₹)'),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _inputDecoration(
                hint: 'Enter purchase amount',
                icon: Icons.currency_rupee,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter amount';
                }
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) {
                  return 'Enter a valid amount > 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Notes (optional)
            _buildLabel('Notes (optional)'),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration(
                hint: 'Any additional details...',
                icon: Icons.notes,
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _savePurchase,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Purchase',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showForm = false),
                icon: const Icon(Icons.list, size: 18),
                label: const Text(
                  'View Purchase History',
                  style: TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: secondaryGreen,
                  side: BorderSide(color: secondaryGreen),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: secondaryGreen, width: 2),
      ),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  // ==================== HISTORY ====================
  Widget _buildHistory() {
    return Column(
      children: [
        // Top "Add Purchase" button
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _showForm = true),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text(
                'Add Accessories Purchase',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 3,
              ),
            ),
          ),
        ),

        // Purchase list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('accessoriesPurchase')
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1A7D4A)),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Error loading purchases: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 60,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No purchases yet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Add Accessories Purchase" to record one',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Group by month for nicer presentation
              final Map<String, List<QueryDocumentSnapshot>> grouped = {};
              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                DateTime dt;
                if (data['date'] is Timestamp) {
                  dt = (data['date'] as Timestamp).toDate();
                } else {
                  dt = DateTime.now();
                }
                final key = DateFormat('MMMM yyyy').format(dt);
                grouped.putIfAbsent(key, () => []).add(doc);
              }

              final totalAmount = docs.fold<double>(0.0, (sum, doc) {
                final d = doc.data() as Map<String, dynamic>;
                return sum + ((d['amount'] ?? 0) as num).toDouble();
              });

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // Total summary card
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryGreen, secondaryGreen],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.shopping_bag,
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
                                'Total Purchases',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${widget.formatNumber(totalAmount)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${docs.length} records',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Month groups
                  ...grouped.entries.map((entry) {
                    final monthLabel = entry.key;
                    final monthDocs = entry.value;
                    double monthTotal = 0;
                    for (final d in monthDocs) {
                      final dd = d.data() as Map<String, dynamic>;
                      monthTotal += ((dd['amount'] ?? 0) as num).toDouble();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: secondaryGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  monthLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: secondaryGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹${widget.formatNumber(monthTotal)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${monthDocs.length} items',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...monthDocs.map((doc) => _buildPurchaseCard(doc)),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final supplier = (data['supplier'] ?? 'Unknown Supplier').toString();
    final amount = ((data['amount'] ?? 0) as num).toDouble();
    final shopName = (data['shopName'] ?? '').toString();
    final notes = (data['notes'] ?? '').toString().trim();
    final uploadedByName = (data['uploadedByName'] ?? '').toString();

    DateTime dt;
    if (data['date'] is Timestamp) {
      dt = (data['date'] as Timestamp).toDate();
    } else {
      dt = DateTime.now();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: secondaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.business, color: secondaryGreen, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 10,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            DateFormat('dd MMM yyyy').format(dt),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (shopName.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.store,
                              size: 10,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                shopName,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${widget.formatNumber(amount)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: secondaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  notes,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (uploadedByName.isNotEmpty) ...[
                  Icon(Icons.person, size: 10, color: Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      uploadedByName,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  tooltip: 'Delete purchase',
                  onPressed: () => _deletePurchase(doc.id, supplier),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
