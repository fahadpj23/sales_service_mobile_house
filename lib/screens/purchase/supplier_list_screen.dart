import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _suppliers = [];
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, active, inactive

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
    var filtered = _suppliers;

    // Apply status filter
    if (_filterStatus != 'all') {
      filtered = filtered.where((supplier) {
        return supplier['status'] == _filterStatus;
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((supplier) {
        return supplier['name'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            supplier['phone'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            supplier['email'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            supplier['gstNumber'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
      }).toList();
    }

    return filtered;
  }

  void _showSupplierDetails(Map<String, dynamic> supplier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.business, color: Colors.green[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                supplier['name'],
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
          if (supplier['status'] == 'active')
            ElevatedButton.icon(
              onPressed: () =>
                  _toggleSupplierStatus(supplier['id'], 'inactive'),
              icon: const Icon(Icons.block, size: 16),
              label: const Text('Deactivate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _toggleSupplierStatus(supplier['id'], 'active'),
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text('Activate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
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

  Future<void> _toggleSupplierStatus(
    String supplierId,
    String newStatus,
  ) async {
    try {
      await _firestore.collection('suppliers').doc(supplierId).update({
        'status': newStatus,
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Supplier ${newStatus == 'active' ? 'activated' : 'deactivated'} successfully',
          ),
          backgroundColor: newStatus == 'active' ? Colors.green : Colors.orange,
        ),
      );
      await _loadSuppliers();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
    }
  }

  Future<void> _deleteSupplier(String supplierId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: const Text(
          'Are you sure you want to delete this supplier? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestore
                    .collection('suppliers')
                    .doc(supplierId)
                    .delete();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Supplier deleted successfully'),
                  ),
                );
                await _loadSuppliers();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting supplier: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
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

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Inactive', 'inactive'),
                const Spacer(),
                Text(
                  '${_filteredSuppliers.length} suppliers',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
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
                          _searchQuery.isNotEmpty
                              ? 'No suppliers match your search'
                              : 'No suppliers found',
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
                        if (_suppliers.isEmpty)
                          TextButton.icon(
                            onPressed: () {
                              // Navigate to Add Supplier
                              // You can use Navigator.push or drawer navigation
                              // For now, we'll just close the dialog
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Supplier'),
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
                                color: supplier['status'] == 'active'
                                    ? Colors.green[50]
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                supplier['name'][0].toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: supplier['status'] == 'active'
                                      ? Colors.green[700]
                                      : Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            title: Text(
                              supplier['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: supplier['status'] == 'active'
                                    ? Colors.black87
                                    : Colors.grey[600],
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supplier['phone'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: supplier['status'] == 'active'
                                        ? Colors.grey[600]
                                        : Colors.grey[400],
                                  ),
                                ),
                                if (supplier['email'] != 'N/A')
                                  Text(
                                    supplier['email'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: supplier['status'] == 'active'
                                          ? Colors.grey[500]
                                          : Colors.grey[400],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
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
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.grey[400],
                                  ),
                                  onPressed: () =>
                                      _deleteSupplier(supplier['id']),
                                ),
                              ],
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

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = selected ? value : 'all';
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.green,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
