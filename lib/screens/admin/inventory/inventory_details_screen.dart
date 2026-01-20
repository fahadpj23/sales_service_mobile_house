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
  String _selectedStatus = 'available';
  bool _isLoading = true;
  List<Map<String, dynamic>> _allInventory = [];
  List<Map<String, dynamic>> _filteredInventory = [];
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

  Map<String, dynamic> _getCurrentTabStats() {
    int count = _filteredInventory.length;
    double value = _filteredInventory.fold(
      0.0,
      (sum, item) => sum + (item['productPrice'] ?? 0),
    );

    String title;
    IconData icon;
    Color color;

    switch (_selectedStatus) {
      case 'available':
        title = 'Available';
        icon = Icons.check_circle;
        color = Color(0xFF4CAF50);
        break;
      case 'sold':
        title = 'Sold';
        icon = Icons.shopping_cart;
        color = Color(0xFF2196F3);
        break;
      case 'returned':
        title = 'Returned';
        icon = Icons.assignment_return;
        color = Color(0xFFFF9800);
        break;
      default:
        title = 'Items';
        icon = Icons.inventory;
        color = primaryGreen;
    }

    return {
      'title': title,
      'count': count,
      'value': value,
      'icon': icon,
      'color': color,
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
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedShopId = null;
      _selectedStatus = 'available';
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
          'Inventory',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        actions: [
          if (_selectedShopId != null ||
              _selectedStatus != 'available' ||
              _searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_all, size: 20),
              onPressed: _clearAllFilters,
              tooltip: 'Clear all filters',
            ),
          IconButton(
            icon: Icon(Icons.refresh, size: 20),
            onPressed: _loadAllInventory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: secondaryGreen))
          : Column(
              children: [
                _buildFilterSection(),

                // Shop selection indicator
                if (_selectedShopId != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Card(
                      color: primaryGreen.withOpacity(0.1),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(
                          color: primaryGreen.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Icon(Icons.store, size: 16, color: primaryGreen),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Viewing:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    _getSelectedShopName(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.clear, size: 16),
                              onPressed: () {
                                setState(() => _selectedShopId = null);
                                _applyFilters();
                              },
                              tooltip: 'Clear shop filter',
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(minWidth: 30),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                _buildCurrentTabStats(),

                SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Items (${_filteredInventory.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                      Text(
                        _selectedShopId != null
                            ? _getSelectedShopName()
                            : 'All Shops',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 6),
                Expanded(child: _buildInventoryList()),
              ],
            ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: EdgeInsets.all(10),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search product, brand, IMEI, shop...',
                    hintStyle: TextStyle(fontSize: 11),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.search,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: 12),
                  onChanged: (value) => _applyFilters(),
                ),
              ),

              SizedBox(height: 8),

              // Shop Dropdown
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Icon(
                        Icons.store,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedShopId,
                          isExpanded: true,
                          hint: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'All Shops',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'All Shops',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            ...widget.shops.map<DropdownMenuItem<String>>((
                              shop,
                            ) {
                              return DropdownMenuItem<String>(
                                value: shop['id'] as String?,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    shop['name'] as String,
                                    style: TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                          onChanged: (value) {
                            setState(() {
                              _selectedShopId = value;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                    ),
                    if (_selectedShopId != null)
                      IconButton(
                        icon: Icon(Icons.clear, size: 14),
                        onPressed: () {
                          setState(() => _selectedShopId = null);
                          _applyFilters();
                        },
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minWidth: 30),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 8),

              // Status Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Status:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusChip('Available', 'available'),
                        SizedBox(width: 4),
                        _buildStatusChip('Sold', 'sold'),
                        SizedBox(width: 4),
                        _buildStatusChip('Returned', 'returned'),
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

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : chipColor,
          fontSize: 10,
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
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      labelPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  Widget _buildCurrentTabStats() {
    final stats = _getCurrentTabStats();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Title with icon
              Row(
                children: [
                  Icon(stats['icon'], size: 16, color: stats['color']),
                  SizedBox(width: 6),
                  Text(
                    stats['title'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: stats['color'],
                    ),
                  ),
                ],
              ),

              // Vertical divider
              Container(width: 1, height: 20, color: Colors.grey[300]),

              // Count
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Count',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${stats['count']}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: stats['color'],
                    ),
                  ),
                ],
              ),

              // Vertical divider
              Container(width: 1, height: 20, color: Colors.grey[300]),

              // Value
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Value',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '₹${widget.formatNumber(stats['value'])}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
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

  Widget _buildInventoryList() {
    if (_filteredInventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 48, color: Colors.grey[400]),
            SizedBox(height: 10),
            Text(
              'No items found',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Text(
              _selectedShopId != null
                  ? 'No ${_selectedStatus} items found for this shop'
                  : 'Try changing your filters or search',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _showItemDetails(context, item),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(10),
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
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 10, color: statusColor),
                        SizedBox(width: 2),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 8,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.branding_watermark,
                    size: 12,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 4),
                  Text(
                    item['productBrand'],
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                  Spacer(),
                  Text(
                    '₹${widget.formatNumber(item['productPrice'])}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.store, size: 12, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item['shopName'],
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.confirmation_number,
                    size: 12,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'IMEI: ${item['imei']}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontFamily: 'Monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Divider(height: 1, color: Colors.grey[300]),
              SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['type'] == 'phone_return' ? 'Returned' : 'Added',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy').format(date),
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
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
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                      Text(
                        item['returnedBy'] ?? item['uploadedBy'],
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
              if (item['type'] == 'phone_return' && item['reason'] != null)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Reason: ${item['reason']}',
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          padding: EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Item Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 10),
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
              SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: TextStyle(fontSize: 13)),
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
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}
