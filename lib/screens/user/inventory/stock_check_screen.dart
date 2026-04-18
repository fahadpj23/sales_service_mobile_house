// lib/screens/inventory/stock_check_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

// Compact Stock Item Model
class StockItem {
  final String id;
  final String identifier;
  final String brand;
  final String model;
  final double price;
  final String shopId;
  final String shopName;
  final String status;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String uploadedById;
  final DateTime createdAt;
  final String type;

  StockItem({
    required this.id,
    required this.identifier,
    required this.brand,
    required this.model,
    required this.price,
    required this.shopId,
    required this.shopName,
    required this.status,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.uploadedById,
    required this.createdAt,
    required this.type,
  });

  factory StockItem.fromFirestore(
    String id,
    Map<String, dynamic> data,
    String type,
  ) {
    switch (type) {
      case 'phone':
        return StockItem(
          id: id,
          identifier: data['imei'] ?? '',
          brand: data['productBrand'] ?? '',
          model: data['productName'] ?? '',
          price: (data['productPrice'] ?? 0).toDouble(),
          shopId: data['shopId'] ?? '',
          shopName: data['shopName'] ?? '',
          status: data['status'] ?? 'available',
          uploadedAt:
              (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          uploadedBy: data['uploadedBy'] ?? '',
          uploadedById: data['uploadedById'] ?? '',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          type: type,
        );
      case 'base_model':
        return StockItem(
          id: id,
          identifier: data['imei'] ?? data['serialNumber'] ?? '',
          brand: data['brand'] ?? '',
          model: data['modelName'] ?? data['productName'] ?? '',
          price: (data['price'] ?? 0).toDouble(),
          shopId: data['shopId'] ?? '',
          shopName: data['shopName'] ?? '',
          status: data['status'] ?? 'available',
          uploadedAt:
              (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          uploadedBy: data['uploadedBy'] ?? '',
          uploadedById: data['uploadedById'] ?? '',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          type: type,
        );
      case 'tv':
        return StockItem(
          id: id,
          identifier: data['serialNumber'] ?? '',
          brand: data['modelBrand'] ?? '',
          model: data['modelName'] ?? '',
          price: (data['modelPrice'] ?? 0).toDouble(),
          shopId: data['shopId'] ?? '',
          shopName: data['shopName'] ?? '',
          status: data['status'] ?? 'available',
          uploadedAt:
              (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          uploadedBy: data['uploadedBy'] ?? '',
          uploadedById: data['uploadedById'] ?? '',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          type: type,
        );
      default:
        throw Exception('Invalid type');
    }
  }
}

// Compact Stock Service
class StockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _collections = {
    'phone': 'phoneStock',
    'base_model': 'baseModelStock',
    'tv': 'tvStock',
  };

  Future<List<StockItem>> getStock(String type) async {
    try {
      final snapshot = await _firestore
          .collection(_collections[type]!)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => StockItem.fromFirestore(doc.id, doc.data(), type))
          .toList();
    } catch (e) {
      print('Error fetching $type stock: $e');
      return [];
    }
  }

  Future<Map<String, int>> getStockCount(String type) async {
    final items = await getStock(type);
    return {
      'total': items.length,
      'available': items.where((i) => i.status == 'available').length,
      'sold': items.where((i) => i.status == 'sold').length,
    };
  }

  Future<Map<String, List<StockItem>>> getAllStock() async {
    final Map<String, List<StockItem>> result = {};
    for (final type in _collections.keys) {
      result[type] = await getStock(type);
    }
    return result;
  }
}

// Main Screen
class StockCheckScreen extends StatefulWidget {
  const StockCheckScreen({super.key});

  @override
  State<StockCheckScreen> createState() => _StockCheckScreenState();
}

class _StockCheckScreenState extends State<StockCheckScreen>
    with SingleTickerProviderStateMixin {
  final StockService _service = StockService();
  late TabController _tabController;

  // Data storage
  final Map<String, List<StockItem>> _stock = {
    'phone': [],
    'base_model': [],
    'tv': [],
  };
  final Map<String, List<StockItem>> _filtered = {
    'phone': [],
    'base_model': [],
    'tv': [],
  };
  final Map<String, Map<String, int>> _stats = {
    'phone': {'total': 0, 'available': 0, 'sold': 0},
    'base_model': {'total': 0, 'available': 0, 'sold': 0},
    'tv': {'total': 0, 'available': 0, 'sold': 0},
  };

  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'available'; // Default to available
  bool _sortByPrice = false; // false = no sorting, true = low to high
  int _currentTab = 0;

  final TextEditingController _searchController = TextEditingController();
  final List<String> _tabTitles = ['Phones', 'Base Models', 'TVs'];
  final List<String> _tabTypes = ['phone', 'base_model', 'tv'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentTab = _tabController.index);
      _applyFilters();
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      // Load all stock types
      for (final type in _tabTypes) {
        _stock[type] = await _service.getStock(type);
        _filtered[type] = List.from(_stock[type]!);
        _stats[type] = await _service.getStockCount(type);
      }
    } catch (e) {
      _showMessage('Failed to load data: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
      _applyFilters();
    }
  }

  // Smart search with partial matching and sorting
  void _applyFilters() {
    final String currentType = _tabTypes[_currentTab];
    final List<StockItem> source = _stock[currentType] ?? [];
    final String query = _searchQuery.trim().toLowerCase();

    List<StockItem> results = source.where((item) {
      // If no search query, include all items
      if (query.isEmpty) return true;

      // Searchable fields
      final String identifier = item.identifier.toLowerCase();
      final String model = item.model.toLowerCase();
      final String brand = item.brand.toLowerCase();

      // Remove spaces for better matching (for formatted identifiers)
      final String cleanIdentifier = identifier.replaceAll(' ', '');
      final String cleanQuery = query.replaceAll(' ', '');

      // Check for partial matches in ANY field
      final bool matchesIdentifier =
          identifier.contains(query) || cleanIdentifier.contains(cleanQuery);
      final bool matchesModel = model.contains(query);
      final bool matchesBrand = brand.contains(query);

      return matchesIdentifier || matchesModel || matchesBrand;
    }).toList();

    // Apply status filter (only available or sold)
    results = results.where((item) => item.status == _statusFilter).toList();

    // Apply price sorting (low to high) - FIXED
    if (_sortByPrice) {
      print('Sorting by price low to high'); // Debug
      results.sort((a, b) {
        return a.price.compareTo(b.price);
      });
    }

    setState(() {
      _filtered[currentType] = results;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }
    return status.isGranted;
  }

  void _openScanner() async {
    if (!await _checkCameraPermission()) {
      _showMessage('Camera permission required', isError: true);
      return;
    }

    final String currentType = _tabTypes[_currentTab];

    showDialog(
      context: context,
      builder: (context) => ScannerDialog(
        type: currentType,
        onScan: (identifier) {
          setState(() {
            _searchController.text = identifier;
            _searchQuery = identifier;
          });
          _applyFilters();
        },
      ),
    );
  }

  String _formatIdentifier(String identifier, String type) {
    if (identifier.isEmpty) return identifier;

    if (type == 'phone') {
      if (identifier.length == 15) {
        return '${identifier.substring(0, 6)} ${identifier.substring(6, 12)} ${identifier.substring(12)}';
      }
      if (identifier.length == 16) {
        return '${identifier.substring(0, 8)} ${identifier.substring(8)}';
      }
    } else if (type == 'tv' || type == 'base_model') {
      if (identifier.length >= 12) {
        return '${identifier.substring(0, 4)}-${identifier.substring(4, 8)}-${identifier.substring(8)}';
      }
      if (identifier.length >= 8) {
        return '${identifier.substring(0, 4)}-${identifier.substring(4)}';
      }
    }
    return identifier;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'sold':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _statusFilter = 'available';
      _sortByPrice = false;
    });
    _applyFilters();
  }

  void _toggleSortByPrice() {
    setState(() {
      _sortByPrice = !_sortByPrice;
      print('Sort by price enabled: $_sortByPrice'); // Debug
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final String currentType = _tabTypes[_currentTab];
    final List<StockItem> currentItems = _filtered[currentType] ?? [];
    final Map<String, int> currentStats =
        _stats[currentType] ?? {'total': 0, 'available': 0, 'sold': 0};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Check', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: 'Phones'),
            Tab(text: 'Base Models'),
            Tab(text: 'TVs'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _isLoading ? null : _loadAllData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Column(
              children: [
                // Search Bar
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Search field with scanner
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search IMEI/serial (partial ok), model...',
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 18,
                            color: Colors.teal,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchQuery.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                    _applyFilters();
                                  },
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.qr_code_scanner,
                                  size: 20,
                                ),
                                onPressed: _openScanner,
                                color: Colors.teal,
                              ),
                            ],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                          _applyFilters();
                        },
                      ),

                      const SizedBox(height: 8),

                      // Stats Row
                      Row(
                        children: [
                          _buildStatItem(
                            'Total',
                            currentStats['total']!,
                            Colors.teal,
                            Icons.inventory,
                          ),
                          _buildStatItem(
                            'Available',
                            currentStats['available']!,
                            Colors.green,
                            Icons.check_circle,
                          ),
                          _buildStatItem(
                            'Sold',
                            currentStats['sold']!,
                            Colors.red,
                            Icons.shopping_cart,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Filter Chips Row (Status + Sort)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Status filters (only Available and Sold)
                            _buildStatusChip('Available', 'available'),
                            const SizedBox(width: 6),
                            _buildStatusChip('Sold', 'sold'),
                            const SizedBox(width: 12),

                            // Sort by price button (toggles on/off)
                            ActionChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.attach_money,
                                    size: 14,
                                    color: _sortByPrice
                                        ? Colors.teal
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Sort by Price',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _sortByPrice
                                          ? Colors.teal
                                          : Colors.grey,
                                      fontWeight: _sortByPrice
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  if (_sortByPrice)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.arrow_upward,
                                        size: 12,
                                        color: Colors.teal,
                                      ),
                                    ),
                                ],
                              ),
                              onPressed: _toggleSortByPrice,
                              backgroundColor: _sortByPrice
                                  ? Colors.teal.withOpacity(0.1)
                                  : Colors.grey.shade100,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: _sortByPrice
                                      ? Colors.teal
                                      : Colors.grey.shade300,
                                  width: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Results count
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${currentItems.length} items found',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      if (_searchQuery.isNotEmpty ||
                          _statusFilter != 'available' ||
                          _sortByPrice)
                        TextButton(
                          onPressed: _clearFilters,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 24),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),

                // Stock List
                Expanded(
                  child: currentItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_outlined,
                                size: 48,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No matching items found'
                                    : 'No ${_statusFilter} ${_tabTitles[_currentTab].toLowerCase()} available',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                              if (_searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _clearFilters,
                                  icon: const Icon(Icons.clear_all, size: 14),
                                  label: const Text(
                                    'Clear Search',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAllData,
                          color: Colors.teal,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(10),
                            itemCount: currentItems.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              return _buildStockItem(currentItems[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 2),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isSelected ? Colors.teal : Colors.grey.shade700,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _statusFilter = value; // Directly set to the selected value
        });
        _applyFilters();
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: Colors.teal.withOpacity(0.1),
      checkmarkColor: Colors.teal,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.teal : Colors.grey.shade300,
          width: 0.5,
        ),
      ),
    );
  }

  Widget _buildStockItem(StockItem item) {
    final label = item.type == 'phone' ? 'IMEI' : 'Serial';

    return Card(
      elevation: 0.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        onTap: () => _showItemDetails(item),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: _getStatusColor(item.status),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 8),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.model,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$label: ${_formatIdentifier(item.identifier, item.type)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.brand} • ${item.shopName}',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Price and status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(item.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      item.status,
                      style: TextStyle(
                        fontSize: 8,
                        color: _getStatusColor(item.status),
                      ),
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

  void _showItemDetails(StockItem item) {
    final label = item.type == 'phone' ? 'IMEI' : 'Serial';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 30,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(item.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          item.type == 'phone'
                              ? Icons.phone_iphone
                              : item.type == 'tv'
                              ? Icons.tv
                              : Icons.devices,
                          color: _getStatusColor(item.status),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.model,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              item.brand,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),

                  // Details
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        _buildDetailRow(
                          '$label:',
                          _formatIdentifier(item.identifier, item.type),
                          canCopy: true,
                          onCopy: () {
                            Clipboard.setData(
                              ClipboardData(text: item.identifier),
                            );
                            _showMessage('$label copied');
                            Navigator.pop(context);
                          },
                        ),
                        _buildDetailRow('Model:', item.model),
                        _buildDetailRow('Brand:', item.brand),
                        _buildDetailRow(
                          'Price:',
                          '₹${item.price.toStringAsFixed(0)}',
                        ),
                        _buildDetailRow(
                          'Status:',
                          item.status,
                          color: _getStatusColor(item.status),
                        ),
                        _buildDetailRow('Shop:', item.shopName),
                        _buildDetailRow('Shop ID:', item.shopId),
                        _buildDetailRow(
                          'Uploaded:',
                          DateFormat(
                            'dd MMM yyyy, HH:mm',
                          ).format(item.uploadedAt),
                        ),
                        _buildDetailRow('Uploaded By:', item.uploadedBy),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _searchController.text = item.identifier;
                              _searchQuery = item.identifier;
                            });
                            _applyFilters();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text(
                            'Search',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? color,
    bool canCopy = false,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
                if (canCopy && onCopy != null)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 14),
                    onPressed: onCopy,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Scanner Dialog
class ScannerDialog extends StatefulWidget {
  final String type;
  final Function(String) onScan;

  const ScannerDialog({super.key, required this.type, required this.onScan});

  @override
  State<ScannerDialog> createState() => _ScannerDialogState();
}

class _ScannerDialogState extends State<ScannerDialog> {
  MobileScannerController? _controller;
  bool _isReady = false;
  String? _lastScanMessage;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  void _initScanner() async {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  String _cleanIdentifier(String rawData) {
    if (widget.type == 'phone') {
      // For IMEI: remove all non-numeric characters
      return rawData.replaceAll(RegExp(r'[^0-9]'), '');
    } else {
      // For serial numbers: allow alphanumeric, convert to uppercase
      return rawData.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    }
  }

  bool _isValidIdentifier(String identifier) {
    if (identifier.isEmpty) return false;

    switch (widget.type) {
      case 'phone':
        return (identifier.length == 15 || identifier.length == 16) &&
            RegExp(r'^[0-9]+$').hasMatch(identifier);
      case 'tv':
      case 'base_model':
        return identifier.length >= 8 &&
            identifier.length <= 20 &&
            RegExp(r'^[A-Za-z0-9]+$').hasMatch(identifier);
      default:
        return false;
    }
  }

  void _handleScan(BarcodeCapture capture) {
    if (_lastScanMessage != null) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue ?? '';
    final cleanValue = _cleanIdentifier(rawValue);

    if (_isValidIdentifier(cleanValue)) {
      setState(() {
        _lastScanMessage =
            '✓ Valid ${widget.type == 'phone' ? 'IMEI' : 'serial'}';
      });

      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 800), () {
        widget.onScan(cleanValue);
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      setState(() {
        _lastScanMessage =
            '✗ Invalid ${widget.type == 'phone' ? 'IMEI' : 'serial'}';
      });

      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _lastScanMessage = null);
      });
    }
  }

  void _showManualEntry() {
    final controller = TextEditingController();
    final label = widget.type == 'phone' ? 'IMEI' : 'Serial Number';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter $label', style: const TextStyle(fontSize: 14)),
          content: TextField(
            controller: controller,
            keyboardType: widget.type == 'phone'
                ? TextInputType.number
                : TextInputType.text,
            maxLength: widget.type == 'phone' ? 16 : 20,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: const TextStyle(fontSize: 12),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                final clean = _cleanIdentifier(value);
                if (_isValidIdentifier(clean)) {
                  widget.onScan(clean);
                  Navigator.pop(context);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enter a valid $label',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('OK', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.type == 'phone' ? 'IMEI' : 'Serial Number';

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Scan $label',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Scanner
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isReady && _controller != null)
                    MobileScanner(
                      controller: _controller!,
                      onDetect: _handleScan,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),

                  // Scanner overlay
                  Container(
                    width: MediaQuery.of(context).size.width * 0.65,
                    height: MediaQuery.of(context).size.width * 0.65,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),

                  // Scan message
                  if (_lastScanMessage != null)
                    Positioned(
                      bottom: 15,
                      left: 15,
                      right: 15,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _lastScanMessage!.startsWith('✓')
                              ? Colors.green
                              : Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _lastScanMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _showManualEntry,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Manual',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _lastScanMessage = null;
                        });
                        _timer?.cancel();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Rescan',
                        style: TextStyle(fontSize: 12),
                      ),
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
