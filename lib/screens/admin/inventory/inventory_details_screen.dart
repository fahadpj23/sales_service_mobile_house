import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flutter/services.dart'; // Add this import

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
  final FocusNode _searchFocusNode = FocusNode();
  final Color primaryGreen = Color(0xFF0A4D2E);
  final Color secondaryGreen = Color(0xFF1A7D4A);
  final Color lightGreen = Color(0xFFE8F5E9);

  // Statistics
  int _totalAvailable = 0;
  int _totalSold = 0;
  int _totalReturned = 0;
  double _totalAvailableValue = 0.0;
  double _totalSoldValue = 0.0;
  double _totalReturnedValue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAllInventory();
    _searchController.addListener(() {
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAllInventory() async {
    setState(() => _isLoading = true);

    try {
      final phoneStockSnapshot = await _firestore
          .collection('phoneStock')
          .get();

      _allInventory.clear();
      _totalAvailable = 0;
      _totalSold = 0;
      _totalReturned = 0;
      _totalAvailableValue = 0.0;
      _totalSoldValue = 0.0;
      _totalReturnedValue = 0.0;

      for (var doc in phoneStockSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final price = (data['productPrice'] ?? 0).toDouble();
        final status = data['status'] ?? 'available';

        _allInventory.add({
          'id': doc.id,
          'type': 'phone_stock',
          'shopId': data['shopId'] ?? '',
          'shopName': data['shopName'] ?? 'Unknown Shop',
          'productName': data['productName'] ?? 'Unknown',
          'productBrand': data['productBrand'] ?? 'Unknown',
          'productPrice': price,
          'imei': data['imei'] ?? 'N/A',
          'status': status,
          'uploadedAt': data['uploadedAt'] is Timestamp
              ? (data['uploadedAt'] as Timestamp).toDate()
              : DateTime.now(),
          'uploadedBy': data['uploadedBy'] ?? 'Unknown',
          'uploadedById': data['uploadedById'] ?? '',
        });

        // Update statistics
        if (status == 'available') {
          _totalAvailable++;
          _totalAvailableValue += price;
        } else if (status == 'sold') {
          _totalSold++;
          _totalSoldValue += price;
        }
      }

      final returnedSnapshot = await _firestore
          .collection('phoneReturns')
          .get();

      for (var doc in returnedSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final price = (data['productPrice'] ?? 0).toDouble();

        _allInventory.add({
          'id': doc.id,
          'type': 'phone_return',
          'shopId': data['originalShopId'] ?? '',
          'shopName': data['originalShopName'] ?? 'Unknown Shop',
          'productName': data['productName'] ?? 'Unknown',
          'productBrand': data['productBrand'] ?? 'Unknown',
          'productPrice': price,
          'imei': data['imei'] ?? 'N/A',
          'status': 'returned',
          'returnedAt': data['returnedAt'] is Timestamp
              ? (data['returnedAt'] as Timestamp).toDate()
              : DateTime.now(),
          'returnedBy': data['returnedBy'] ?? 'Unknown',
          'reason': data['reason'] ?? '',
        });

        // Update statistics for returned items
        _totalReturned++;
        _totalReturnedValue += price;
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

  // ENHANCED: Smart Search Logic that handles partial matches, specs, and IMEI
  void _applyFilters() {
    setState(() {
      String searchQuery = _searchController.text.trim().toLowerCase();

      _filteredInventory = _allInventory.where((item) {
        // Shop filter
        if (_selectedShopId != null && item['shopId'] != _selectedShopId) {
          return false;
        }

        // Status filter - Always filter by selected status
        if (item['status'] != _selectedStatus) {
          return false;
        }

        // Search filter - Smart search logic
        if (searchQuery.isNotEmpty) {
          final productText = item['productName'].toString().toLowerCase();
          final brandText = item['productBrand'].toString().toLowerCase();
          final imeiText = item['imei'].toString().toLowerCase();
          final shopText = item['shopName'].toString().toLowerCase();
          final combinedText = '$productText $brandText';

          // Split search query into words
          final searchWords = searchQuery
              .split(' ')
              .where((w) => w.isNotEmpty)
              .toList();

          // Check if ALL search words are found (case-insensitive)
          for (final word in searchWords) {
            // First check if it's an exact IMEI match
            if (imeiText.contains(word)) {
              continue; // Word found in IMEI
            }

            // Check if it's an exact shop name match
            if (shopText.contains(word)) {
              continue; // Word found in shop name
            }

            // Create variations for the word for smart matching
            final variations = <String>[word];

            // Handle slash variations like "4/128"
            if (word.contains('/')) {
              variations.add(word.replaceAll('/', ' '));
              variations.add(word.replaceAll('/', ''));
              variations.add(word.replaceAll('/', 'gb/'));
              variations.add(word.replaceAll('/', '/gb'));
            }

            // Handle "g" variations like "5g"
            if (word.endsWith('g') && word.length > 1) {
              variations.add(word.substring(0, word.length - 1));
            }

            // Handle "gb" variations like "4gb"
            if (word.toLowerCase().endsWith('gb') && word.length > 2) {
              variations.add(word.toLowerCase().replaceAll('gb', ''));
            }

            // Check if any variation is found in product or brand
            bool wordFound = false;
            for (final variation in variations) {
              if (combinedText.contains(variation)) {
                wordFound = true;
                break;
              }
            }

            if (!wordFound) {
              return false;
            }
          }
        }

        return true;
      }).toList();

      // Sort by date (newest first)
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

  // Scanner Methods
  Future<bool> _checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      if (status.isDenied) {
        final result = await Permission.camera.request();
        return result.isGranted;
      }
      return status.isGranted;
    } catch (e) {
      print('Permission error: $e');
      return false;
    }
  }

  Future<void> _openScannerForSearch() async {
    if (!await _checkCameraPermission()) {
      _showSnackbar('Camera permission required for scanning', Colors.red);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _ImeiScannerDialog(
        onScanComplete: (imei) {
          setState(() {
            _searchController.text = imei;
            _applyFilters();
          });
        },
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _formatImeiForDisplay(String imei) {
    if (imei.isEmpty) return '';
    if (imei.length == 15) {
      return '${imei.substring(0, 6)} ${imei.substring(6, 12)} ${imei.substring(12)}';
    } else if (imei.length == 16) {
      return '${imei.substring(0, 8)} ${imei.substring(8)}';
    }
    return imei;
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText:
              'Search by IMEI, model, specs (e.g., "f17 4/128", "samsung 5g")',
          hintStyle: TextStyle(fontSize: 11),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey[600]),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.clear, size: 14),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                    _searchFocusNode.unfocus();
                  },
                ),
              Container(width: 1, height: 20, color: Colors.grey.shade300),
              IconButton(
                icon: Icon(Icons.qr_code_scanner, size: 18),
                onPressed: _openScannerForSearch,
                tooltip: 'Scan IMEI to search',
                color: primaryGreen,
              ),
            ],
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
          alignLabelWithHint: true,
        ),
        style: TextStyle(fontSize: 12),
        onChanged: (value) => _applyFilters(),
        onSubmitted: (value) {
          _searchFocusNode.unfocus();
        },
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    int count,
    double value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: color),
                  SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '₹${widget.formatNumber(value)}',
                style: TextStyle(fontSize: 10, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
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
                // Search and Filter Section
                Container(
                  padding: EdgeInsets.all(10),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Enhanced Search Bar with Scanner
                          _buildSearchField(),

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
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          'All Shops',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      items: [
                                        DropdownMenuItem<String>(
                                          value: null,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            child: Text(
                                              'All Shops',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                        ...widget.shops.map<
                                          DropdownMenuItem<String>
                                        >((shop) {
                                          return DropdownMenuItem<String>(
                                            value: shop['id'] as String?,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10,
                                              ),
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
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
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
                ),

                // Overall Statistics
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    children: [
                      _buildStatItem(
                        'Available',
                        _totalAvailable,
                        _totalAvailableValue,
                        Color(0xFF4CAF50),
                        Icons.check_circle,
                      ),
                      SizedBox(width: 6),
                      _buildStatItem(
                        'Sold',
                        _totalSold,
                        _totalSoldValue,
                        Color(0xFF2196F3),
                        Icons.shopping_cart,
                      ),
                      SizedBox(width: 6),
                      _buildStatItem(
                        'Returned',
                        _totalReturned,
                        _totalReturnedValue,
                        Color(0xFFFF9800),
                        Icons.assignment_return,
                      ),
                    ],
                  ),
                ),

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

                // Current Tab Stats
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
            if (_searchController.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: ElevatedButton.icon(
                  onPressed: _openScannerForSearch,
                  icon: Icon(Icons.qr_code_scanner, size: 16),
                  label: Text('Scan IMEI to Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
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
                      'IMEI: ${_formatImeiForDisplay(item['imei'])}',
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
                    _buildDetailRow(
                      'IMEI',
                      _formatImeiForDisplay(item['imei']),
                      canCopy: true,
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: item['imei']));
                        _showSnackbar('IMEI copied to clipboard', Colors.green);
                      },
                    ),
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

  Widget _buildDetailRow(
    String label,
    String value, {
    bool canCopy = false,
    VoidCallback? onCopy,
  }) {
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 11, color: Colors.grey[800]),
                  ),
                ),
                if (canCopy && onCopy != null)
                  IconButton(
                    icon: Icon(Icons.content_copy, size: 14),
                    onPressed: onCopy,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    tooltip: 'Copy to clipboard',
                    color: primaryGreen,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Simplified IMEI Scanner Dialog for Inventory Screen
class _ImeiScannerDialog extends StatefulWidget {
  final Function(String) onScanComplete;

  const _ImeiScannerDialog({required this.onScanComplete});

  @override
  State<_ImeiScannerDialog> createState() => _ImeiScannerDialogState();
}

class _ImeiScannerDialogState extends State<_ImeiScannerDialog> {
  MobileScannerController? _scannerController;
  bool _isScanning = true;
  bool _isTorchOn = false;
  Timer? _scanDebounceTimer;
  String? _lastScannedData;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  void _initScanner() async {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scanDebounceTimer?.cancel();
    _scannerController?.dispose();
    super.dispose();
  }

  void _handleBarcodeScan(BarcodeCapture capture) {
    if (!_isScanning) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final scannedData = barcodes.first.rawValue ?? '';

    // Prevent multiple scans
    if (_scanDebounceTimer != null && _scanDebounceTimer!.isActive) {
      return;
    }

    _scanDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isScanning = true);
      }
    });

    setState(() => _isScanning = false);

    // Clean IMEI
    final cleanImei = scannedData.replaceAll(RegExp(r'[^0-9]'), '');

    // Validate IMEI (15-16 digits)
    if (cleanImei.length >= 15 && cleanImei.length <= 16) {
      setState(() {
        _lastScannedData = 'Scanned IMEI: ${_formatImei(cleanImei)}';
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onScanComplete(cleanImei);
        Navigator.of(context).pop();
      });
    } else {
      setState(() {
        _lastScannedData = 'Invalid IMEI: ${cleanImei.length} digits';
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _lastScannedData = null;
            _isScanning = true;
          });
        }
      });
    }
  }

  String _formatImei(String imei) {
    if (imei.length == 15) {
      return '${imei.substring(0, 6)} ${imei.substring(6, 12)} ${imei.substring(12)}';
    } else if (imei.length == 16) {
      return '${imei.substring(0, 8)} ${imei.substring(8)}';
    }
    return imei;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 25,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF0A4D2E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan IMEI',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Align barcode within frame',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scanner Area
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_scannerController != null)
                    MobileScanner(
                      controller: _scannerController!,
                      onDetect: _handleBarcodeScan,
                      fit: BoxFit.cover,
                    )
                  else
                    Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0A4D2E),
                      ),
                    ),

                  // Scanner Frame
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: MediaQuery.of(context).size.width * 0.7,
                  ),

                  // Status Message
                  if (_lastScannedData != null)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _lastScannedData!.startsWith('Scanned')
                              ? Colors.green.withOpacity(0.9)
                              : Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _lastScannedData!.startsWith('Scanned')
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: Colors.white,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _lastScannedData!,
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Torch Toggle
                  Positioned(
                    top: 20,
                    right: 20,
                    child: FloatingActionButton.small(
                      onPressed: () {
                        if (_scannerController != null) {
                          _scannerController!.toggleTorch();
                          setState(() => _isTorchOn = !_isTorchOn);
                        }
                      },
                      backgroundColor: Colors.black.withOpacity(0.5),
                      child: Icon(
                        _isTorchOn ? Icons.flash_off : Icons.flash_on,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !_isScanning
                          ? () {
                              setState(() {
                                _isScanning = true;
                                _lastScannedData = null;
                              });
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0A4D2E),
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Scan Again'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
