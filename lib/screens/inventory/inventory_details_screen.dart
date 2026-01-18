import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class InventoryDetailsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> shops;
  final String Function(double) formatNumber;

  InventoryDetailsScreen({required this.shops, required this.formatNumber});

  @override
  _InventoryDetailsScreenState createState() => _InventoryDetailsScreenState();
}

class _InventoryDetailsScreenState extends State<InventoryDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedShopId;
  String _selectedStatus =
      'available'; // Changed to non-nullable with default value
  bool _isLoading = true;
  List<Map<String, dynamic>> _allInventory = [];
  List<Map<String, dynamic>> _filteredInventory = [];
  Map<String, dynamic> _inventoryStats = {};
  final TextEditingController _searchController = TextEditingController();
  final Color primaryGreen = Color(0xFF0A4D2E);
  final Color secondaryGreen = Color(0xFF1A7D4A);
  final Color lightGreen = Color(0xFFE8F5E9);

  @override
  void initState() {
    super.initState();
    _loadAllInventory();
  }

  Future<void> _loadAllInventory() async {
    setState(() => _isLoading = true);

    try {
      final phoneStockSnapshot = await _firestore
          .collection('phoneStock')
          .get();

      _allInventory.clear();

      for (var doc in phoneStockSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _allInventory.add({
          'id': doc.id,
          'type': 'phone_stock',
          'shopId': data['shopId'] ?? '',
          'shopName': data['shopName'] ?? 'Unknown Shop',
          'productName': data['productName'] ?? 'Unknown',
          'productBrand': data['productBrand'] ?? 'Unknown',
          'productPrice': (data['productPrice'] ?? 0).toDouble(),
          'imei': data['imei'] ?? 'N/A',
          'status': data['status'] ?? 'available',
          'uploadedAt': data['uploadedAt'] is Timestamp
              ? (data['uploadedAt'] as Timestamp).toDate()
              : DateTime.now(),
          'uploadedBy': data['uploadedBy'] ?? 'Unknown',
        });
      }

      final returnedSnapshot = await _firestore
          .collection('phoneReturns')
          .get();

      for (var doc in returnedSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _allInventory.add({
          'id': doc.id,
          'type': 'phone_return',
          'shopId': data['originalShopId'] ?? '',
          'shopName': data['originalShopName'] ?? 'Unknown Shop',
          'productName': data['productName'] ?? 'Unknown',
          'productBrand': data['productBrand'] ?? 'Unknown',
          'productPrice': (data['productPrice'] ?? 0).toDouble(),
          'imei': data['imei'] ?? 'N/A',
          'status': 'returned',
          'returnedAt': data['returnedAt'] is Timestamp
              ? (data['returnedAt'] as Timestamp).toDate()
              : DateTime.now(),
          'returnedBy': data['returnedBy'] ?? 'Unknown',
          'reason': data['reason'] ?? '',
        });
      }

      _applyFilters();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading inventory: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    // Calculate stats based on filtered inventory (respects shop selection)
    _inventoryStats = {
      'totalItems': _filteredInventory.length,
      'available': _filteredInventory
          .where((item) => item['status'] == 'available')
          .length,
      'sold': _filteredInventory
          .where((item) => item['status'] == 'sold')
          .length,
      'returned': _filteredInventory
          .where((item) => item['status'] == 'returned')
          .length,
      'totalValue': _filteredInventory.fold(
        0.0,
        (sum, item) => sum + (item['productPrice'] ?? 0),
      ),
      'availableValue': _filteredInventory
          .where((item) => item['status'] == 'available')
          .fold(0.0, (sum, item) => sum + (item['productPrice'] ?? 0)),
      'soldValue': _filteredInventory
          .where((item) => item['status'] == 'sold')
          .fold(0.0, (sum, item) => sum + (item['productPrice'] ?? 0)),
      'returnedValue': _filteredInventory
          .where((item) => item['status'] == 'returned')
          .fold(0.0, (sum, item) => sum + (item['productPrice'] ?? 0)),
    };
  }

  void _applyFilters() {
    setState(() {
      String searchQuery = _searchController.text.toLowerCase();

      _filteredInventory = _allInventory.where((item) {
        // Shop filter
        if (_selectedShopId != null && item['shopId'] != _selectedShopId) {
          return false;
        }

        // Status filter - Always filter by selected status
        if (item['status'] != _selectedStatus) {
          return false;
        }

        // Search filter
        if (searchQuery.isNotEmpty) {
          bool matchesSearch =
              item['productName'].toString().toLowerCase().contains(
                searchQuery,
              ) ||
              item['productBrand'].toString().toLowerCase().contains(
                searchQuery,
              ) ||
              item['imei'].toString().toLowerCase().contains(searchQuery) ||
              item['shopName'].toString().toLowerCase().contains(searchQuery);
          if (!matchesSearch) return false;
        }

        return true;
      }).toList();

      _filteredInventory.sort((a, b) {
        final dateA = a['uploadedAt'] ?? a['returnedAt'] ?? DateTime.now();
        final dateB = b['uploadedAt'] ?? b['returnedAt'] ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      // Recalculate stats based on filtered inventory
      _calculateStats();
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedShopId = null;
      _selectedStatus = 'available'; // Reset to default
      _searchController.clear();
    });
    _applyFilters();
  }

  String _getSelectedShopName() {
    if (_selectedShopId == null) {
      return 'All Shops';
    }

    final shop = widget.shops.firstWhere(
      (shop) => shop['id'] == _selectedShopId,
      orElse: () => {'name': 'Unknown Shop'},
    );

    return shop['name'] ?? 'Unknown Shop';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Inventory Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
        actions: [
          if (_selectedShopId != null ||
              _selectedStatus !=
                  'available' || // Changed from _selectedStatus != null
              _searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_all),
              onPressed: _clearAllFilters,
              tooltip: 'Clear all filters',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllInventory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: secondaryGreen))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildFilterSection(),

                  // Shop selection indicator
                  if (_selectedShopId != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Card(
                        color: primaryGreen.withOpacity(0.1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: primaryGreen.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Icon(Icons.store, size: 18, color: primaryGreen),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Viewing inventory for:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      _getSelectedShopName(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: primaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() => _selectedShopId = null);
                                  _applyFilters();
                                },
                                tooltip: 'Clear shop filter',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  _buildStatsCards(),

                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Inventory Items (${_filteredInventory.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryGreen,
                          ),
                        ),
                        Text(
                          _selectedShopId != null
                              ? _getSelectedShopName()
                              : 'All Shops',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  _buildInventoryList(),
                  SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: EdgeInsets.all(14),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_selectedShopId != null ||
                      _selectedStatus != 'available' ||
                      _searchController.text.isNotEmpty)
                    TextButton.icon(
                      onPressed: _clearAllFilters,
                      icon: Icon(Icons.clear, size: 14),
                      label: Text('Clear All', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 5),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by product, brand, IMEI, or shop...',
                    hintStyle: TextStyle(fontSize: 13),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(fontSize: 13),
                  onChanged: (value) => _applyFilters(),
                ),
              ),

              SizedBox(height: 10),

              // Shop Dropdown
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedShopId,
                    isExpanded: true,
                    hint: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Select Shop (All by default)',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'All Shops',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      ...widget.shops.map<DropdownMenuItem<String>>((shop) {
                        return DropdownMenuItem<String>(
                          value: shop['id'] as String?,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              shop['name'] as String,
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                    onChanged: (value) {
                      setState(() {
                        _selectedShopId = value;
                      });
                      _applyFilters();
                    },
                  ),
                ),
              ),

              SizedBox(height: 10),

              // Status Chips - REMOVED "All" option
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Only show available, sold, and returned chips
                    _buildStatusChip('Available', 'available'),
                    SizedBox(width: 6),
                    _buildStatusChip('Sold', 'sold'),
                    SizedBox(width: 6),
                    _buildStatusChip('Returned', 'returned'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    Color chipColor;

    switch (value) {
      case 'available':
        chipColor = Color(0xFF4CAF50);
        break;
      case 'sold':
        chipColor = Color(0xFF2196F3);
        break;
      case 'returned':
        chipColor = Color(0xFFFF9800);
        break;
      default:
        chipColor = primaryGreen;
    }

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : chipColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = value;
        });
        _applyFilters();
      },
      backgroundColor: chipColor.withOpacity(0.1),
      selectedColor: chipColor,
    );
  }

  Widget _buildStatsCards() {
    String statsTitle = _selectedShopId != null
        ? 'Shop Statistics'
        : 'Overall Statistics';

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                statsTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryGreen,
                ),
              ),
              SizedBox(width: 6),
              if (_selectedShopId != null)
                Chip(
                  label: Text(
                    _getSelectedShopName(),
                    style: TextStyle(fontSize: 9, color: Colors.white),
                  ),
                  backgroundColor: primaryGreen,
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                ),
            ],
          ),
        ),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _buildStatCard(
                'Total Items',
                '${_inventoryStats['totalItems']}',
                Icons.inventory,
                primaryGreen,
                'Value: ₹${widget.formatNumber(_inventoryStats['totalValue'] ?? 0)}',
              ),
              _buildStatCard(
                'Available',
                '${_inventoryStats['available']}',
                Icons.check_circle,
                Color(0xFF4CAF50),
                'Value: ₹${widget.formatNumber(_inventoryStats['availableValue'] ?? 0)}',
              ),
              _buildStatCard(
                'Sold',
                '${_inventoryStats['sold']}',
                Icons.shopping_cart,
                Color(0xFF2196F3),
                'Value: ₹${widget.formatNumber(_inventoryStats['soldValue'] ?? 0)}',
              ),
              _buildStatCard(
                'Returned',
                '${_inventoryStats['returned']}',
                Icons.assignment_return,
                Color(0xFFFF9800),
                'Value: ₹${widget.formatNumber(_inventoryStats['returnedValue'] ?? 0)}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryList() {
    if (_filteredInventory.isEmpty) {
      return Container(
        height: 250,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2, size: 56, color: Colors.grey[400]),
              SizedBox(height: 12),
              Text(
                'No inventory items found',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              SizedBox(height: 6),
              Text(
                _selectedShopId != null
                    ? 'No items found for this shop with current filters'
                    : 'Try changing your filters or search',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _filteredInventory.length,
      itemBuilder: (context, index) {
        final item = _filteredInventory[index];
        return _buildInventoryCard(item);
      },
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    String status = item['status'];
    DateTime date = item['uploadedAt'] ?? item['returnedAt'] ?? DateTime.now();

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'available':
        statusColor = Color(0xFF4CAF50);
        statusIcon = Icons.check_circle;
        statusText = 'Available';
        break;
      case 'sold':
        statusColor = Color(0xFF2196F3);
        statusIcon = Icons.shopping_cart;
        statusText = 'Sold';
        break;
      case 'returned':
        statusColor = Color(0xFFFF9800);
        statusIcon = Icons.assignment_return;
        statusText = 'Returned';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = status;
    }

    return GestureDetector(
      onTap: () {
        _showItemDetails(context, item);
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item['productName'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 11, color: statusColor),
                        SizedBox(width: 3),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 9,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.branding_watermark,
                    size: 13,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 5),
                  Text(
                    item['productBrand'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  Spacer(),
                  Icon(Icons.currency_rupee, size: 13, color: Colors.grey[600]),
                  SizedBox(width: 5),
                  Text(
                    '₹${widget.formatNumber(item['productPrice'])}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.store, size: 13, color: Colors.grey[600]),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item['shopName'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 5),
              Row(
                children: [
                  Icon(
                    Icons.confirmation_number,
                    size: 13,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'IMEI: ${item['imei']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontFamily: 'Monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Divider(height: 1, color: Colors.grey[300]),
              SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['type'] == 'phone_return' ? 'Returned' : 'Added',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy').format(date),
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item['type'] == 'phone_return'
                            ? 'Returned By'
                            : 'Uploaded By',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      Text(
                        item['returnedBy'] ?? item['uploadedBy'],
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
              if (item['type'] == 'phone_return' && item['reason'] != null)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Reason: ${item['reason']}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetails(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory Item Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 12),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailRow('Product Name', item['productName']),
                    _buildDetailRow('Brand', item['productBrand']),
                    _buildDetailRow(
                      'Price',
                      '₹${widget.formatNumber(item['productPrice'])}',
                    ),
                    _buildDetailRow('Shop', item['shopName']),
                    _buildDetailRow(
                      'Status',
                      item['status'].toString().toUpperCase(),
                    ),
                    _buildDetailRow('IMEI', item['imei']),
                    _buildDetailRow(
                      'Type',
                      item['type'] == 'phone_stock'
                          ? 'Phone Stock'
                          : 'Phone Return',
                    ),
                    _buildDetailRow(
                      'Date',
                      DateFormat('dd MMM yyyy').format(
                        item['uploadedAt'] ??
                            item['returnedAt'] ??
                            DateTime.now(),
                      ),
                    ),
                    _buildDetailRow(
                      item['type'] == 'phone_return'
                          ? 'Returned By'
                          : 'Uploaded By',
                      item['returnedBy'] ?? item['uploadedBy'],
                    ),
                    if (item['reason'] != null)
                      _buildDetailRow('Return Reason', item['reason']),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}
