// lib/screens/inventory/stock_check_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

// Base Stock Item Model
class StockItem {
  final String id;
  final String identifier; // IMEI or Serial Number
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
  final String type; // 'phone', 'base_model', 'tv'

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

  factory StockItem.fromPhoneFirestore(String id, Map<String, dynamic> data) {
    return StockItem(
      id: id,
      identifier: data['imei'] ?? '',
      brand: data['productBrand'] ?? '',
      model: data['productName'] ?? '',
      price: (data['productPrice'] ?? 0).toDouble(),
      shopId: data['shopId'] ?? '',
      shopName: data['shopName'] ?? '',
      status: data['status'] ?? 'available',
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      uploadedBy: data['uploadedBy'] ?? '',
      uploadedById: data['uploadedById'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      type: 'phone',
    );
  }

  factory StockItem.fromBaseModelFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: 'base_model',
    );
  }

  factory StockItem.fromTvFirestore(String id, Map<String, dynamic> data) {
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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: 'tv',
    );
  }
}

// Stock Service
class StockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<StockItem>> getAllPhoneStock() async {
    try {
      final snapshot = await _firestore
          .collection('phoneStock')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => StockItem.fromPhoneFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching phone stock: $e');
      return [];
    }
  }

  Future<List<StockItem>> getAllBaseModelStock() async {
    try {
      final snapshot = await _firestore
          .collection('baseModelStock')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => StockItem.fromBaseModelFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching base model stock: $e');
      return [];
    }
  }

  Future<List<StockItem>> getAllTvStock() async {
    try {
      final snapshot = await _firestore
          .collection('tvStock')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => StockItem.fromTvFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching TV stock: $e');
      return [];
    }
  }

  Future<Map<String, int>> getStockCount(String type) async {
    try {
      List<StockItem> allStock = [];

      switch (type) {
        case 'phone':
          allStock = await getAllPhoneStock();
          break;
        case 'base_model':
          allStock = await getAllBaseModelStock();
          break;
        case 'tv':
          allStock = await getAllTvStock();
          break;
        default:
          return {'total': 0, 'available': 0, 'sold': 0};
      }

      final available = allStock
          .where((item) => item.status == 'available')
          .length;
      final sold = allStock.where((item) => item.status == 'sold').length;

      return {'total': allStock.length, 'available': available, 'sold': sold};
    } catch (e) {
      return {'total': 0, 'available': 0, 'sold': 0};
    }
  }

  Future<List<StockItem>> getAllStockByType(String type) async {
    switch (type) {
      case 'phone':
        return getAllPhoneStock();
      case 'base_model':
        return getAllBaseModelStock();
      case 'tv':
        return getAllTvStock();
      default:
        return [];
    }
  }
}

// Main Stock Check Screen with Tabs
class StockCheckScreen extends StatefulWidget {
  const StockCheckScreen({super.key});

  @override
  State<StockCheckScreen> createState() => _StockCheckScreenState();
}

class _StockCheckScreenState extends State<StockCheckScreen>
    with SingleTickerProviderStateMixin {
  final StockService _stockService = StockService();

  late TabController _tabController;

  // Separate lists for each type
  List<StockItem> _phoneStock = [];
  List<StockItem> _baseModelStock = [];
  List<StockItem> _tvStock = [];

  // Filtered lists
  List<StockItem> _filteredPhoneStock = [];
  List<StockItem> _filteredBaseModelStock = [];
  List<StockItem> _filteredTvStock = [];

  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all';
  int _currentTabIndex = 0;

  // Statistics
  Map<String, Map<String, int>> _stats = {
    'phone': {'total': 0, 'available': 0, 'sold': 0},
    'base_model': {'total': 0, 'available': 0, 'sold': 0},
    'tv': {'total': 0, 'available': 0, 'sold': 0},
  };

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final List<String> _tabTitles = ['Phones', 'Base Models', 'TVs'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadAllStockData();
  }

  void _handleTabChange() {
    if (_tabController.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController.index;
        _applyFilters();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAllStockData() async {
    setState(() => _isLoading = true);

    try {
      // Load all stock types in parallel
      final results = await Future.wait([
        _stockService.getAllPhoneStock(),
        _stockService.getAllBaseModelStock(),
        _stockService.getAllTvStock(),
      ]);

      _phoneStock = results[0];
      _baseModelStock = results[1];
      _tvStock = results[2];

      // Load statistics for each type
      await Future.wait([
        _loadStatsForType('phone'),
        _loadStatsForType('base_model'),
        _loadStatsForType('tv'),
      ]);

      _filteredPhoneStock = _phoneStock;
      _filteredBaseModelStock = _baseModelStock;
      _filteredTvStock = _tvStock;
    } catch (e) {
      _showErrorSnackbar('Failed to load stock data');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStatsForType(String type) async {
    final stats = await _stockService.getStockCount(type);
    setState(() {
      _stats[type] = stats;
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Get current stock list based on tab
  List<StockItem> _getCurrentStock() {
    switch (_currentTabIndex) {
      case 0:
        return _phoneStock;
      case 1:
        return _baseModelStock;
      case 2:
        return _tvStock;
      default:
        return [];
    }
  }

  // Get current filtered list based on tab
  List<StockItem> _getCurrentFilteredStock() {
    switch (_currentTabIndex) {
      case 0:
        return _filteredPhoneStock;
      case 1:
        return _filteredBaseModelStock;
      case 2:
        return _filteredTvStock;
      default:
        return [];
    }
  }

  // Update filtered list based on tab
  void _updateFilteredList(List<StockItem> filtered) {
    switch (_currentTabIndex) {
      case 0:
        _filteredPhoneStock = filtered;
        break;
      case 1:
        _filteredBaseModelStock = filtered;
        break;
      case 2:
        _filteredTvStock = filtered;
        break;
    }
  }

  // Smart Search Logic
  void _applyFilters() {
    List<StockItem> source = _getCurrentStock();
    List<StockItem> result = List.from(source);

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();

      result = result.where((item) {
        final modelText = item.model.toLowerCase();
        final brandText = item.brand.toLowerCase();
        final identifierText = item.identifier.toLowerCase();

        final combinedText = '$modelText $brandText $identifierText';
        final searchWords = query
            .split(' ')
            .where((w) => w.isNotEmpty)
            .toList();

        for (final word in searchWords) {
          final variations = <String>[word];

          // Handle slash variations like "4/128"
          if (word.contains('/')) {
            variations.add(word.replaceAll('/', ' '));
            variations.add(word.replaceAll('/', ''));
          }

          // Handle "g" variations like "5g"
          if (word.endsWith('g') && word.length > 1) {
            variations.add(word.substring(0, word.length - 1));
          }

          // Handle "gb" variations
          if (word.toLowerCase().endsWith('gb') && word.length > 2) {
            variations.add(word.toLowerCase().replaceAll('gb', ''));
          }

          // Handle "inch" for TVs
          if (word.endsWith('inch') && word.length > 4) {
            variations.add(word.substring(0, word.length - 4));
          }

          // For identifier search (IMEI/Serial)
          if (word.length >= 6) {
            final cleanIdentifier = identifierText.replaceAll(' ', '');
            final cleanWord = word.replaceAll(' ', '');

            if (cleanIdentifier.contains(cleanWord)) {
              variations.add(cleanWord);
            }
            if (identifierText.contains(word)) {
              variations.add(word);
            }
          }

          bool wordFound = false;
          for (final variation in variations) {
            if (combinedText.contains(variation)) {
              wordFound = true;
              break;
            }
          }

          if (!wordFound) return false;
        }

        return true;
      }).toList();
    }

    if (_statusFilter != 'all') {
      result = result.where((item) => item.status == _statusFilter).toList();
    }

    _updateFilteredList(result);
    setState(() {});
  }

  // Format identifier based on type
  String _formatIdentifierForDisplay(String identifier, String type) {
    if (identifier.isEmpty) return '';

    if (type == 'phone') {
      // Format IMEI
      if (identifier.length == 15) {
        return '${identifier.substring(0, 6)} ${identifier.substring(6, 12)} ${identifier.substring(12)}';
      } else if (identifier.length == 16) {
        return '${identifier.substring(0, 8)} ${identifier.substring(8)}';
      }
    } else if (type == 'tv') {
      // Format Serial Number for TV
      if (identifier.length >= 12) {
        return '${identifier.substring(0, 4)}-${identifier.substring(4, 8)}-${identifier.substring(8)}';
      } else if (identifier.length >= 8) {
        return '${identifier.substring(0, 4)}-${identifier.substring(4)}';
      }
    }
    // Base model or default
    return identifier;
  }

  // Validate identifier based on type
  bool _isValidIdentifier(String identifier, String type) {
    if (identifier.isEmpty) return false;

    switch (type) {
      case 'phone':
        return (identifier.length == 15 || identifier.length == 16) &&
            RegExp(r'^[0-9]+$').hasMatch(identifier);
      case 'tv':
        return identifier.length >= 8 &&
            identifier.length <= 20 &&
            RegExp(r'^[A-Za-z0-9]+$').hasMatch(identifier);
      case 'base_model':
        return identifier.length >= 8 &&
            identifier.length <= 20 &&
            RegExp(r'^[A-Za-z0-9]+$').hasMatch(identifier);
      default:
        return false;
    }
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
      _showErrorSnackbar('Camera permission required for scanning');
      return;
    }

    final currentType = _getTypeFromIndex(_currentTabIndex);

    showDialog(
      context: context,
      builder: (context) => OptimizedIdentifierScanner(
        title: 'Search ${currentType == 'phone' ? 'IMEI' : 'Serial'}',
        description:
            'Scan ${currentType == 'phone' ? 'IMEI' : 'serial number'} to search',
        type: currentType,
        onScanComplete: (identifier) {
          setState(() {
            _searchController.text = identifier;
            _searchQuery = identifier.toLowerCase();
            _applyFilters();
          });
        },
      ),
    );
  }

  String _getTypeFromIndex(int index) {
    switch (index) {
      case 0:
        return 'phone';
      case 1:
        return 'base_model';
      case 2:
        return 'tv';
      default:
        return 'phone';
    }
  }

  Widget _buildSearchField() {
    final currentType = _getTypeFromIndex(_currentTabIndex);
    final identifierLabel = currentType == 'phone' ? 'IMEI' : 'Serial Number';

    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: 'Search by $identifierLabel, model, brand...',
        prefixIcon: const Icon(Icons.search, color: Colors.teal, size: 20),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                  _applyFilters();
                  _searchFocusNode.unfocus();
                },
              ),
            Container(width: 1, height: 20, color: Colors.grey.shade300),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, size: 22),
              onPressed: _openScannerForSearch,
              tooltip: 'Scan to search',
              color: Colors.teal,
            ),
          ],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.teal),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      style: const TextStyle(fontSize: 14, color: Colors.black),
      onChanged: (value) {
        setState(() => _searchQuery = value);
        _applyFilters();
      },
      onSubmitted: (value) {
        _searchFocusNode.unfocus();
      },
    );
  }

  void _showItemDetails(StockItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildItemDetailsSheet(item),
    );
  }

  Widget _buildItemDetailsSheet(StockItem item) {
    final identifierLabel = item.type == 'phone' ? 'IMEI' : 'Serial Number';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with Status
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getStatusColor(item.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.type == 'phone'
                        ? Icons.phone_iphone
                        : item.type == 'tv'
                        ? Icons.tv
                        : Icons.devices,
                    color: _getStatusColor(item.status),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.model,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.brand,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(item.status),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _searchByIdentifier(item.identifier);
                    },
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Search Similar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _copyIdentifierToClipboard(
                        item.identifier,
                        identifierLabel,
                      );
                    },
                    icon: const Icon(Icons.content_copy, size: 16),
                    label: Text('Copy $identifierLabel'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Details Sections
            _buildDetailSection('Product Information', [
              _buildDetailRow(
                identifierLabel,
                _formatIdentifierForDisplay(item.identifier, item.type),
                canCopy: true,
                onCopy: () => _copyIdentifierToClipboard(
                  item.identifier,
                  identifierLabel,
                ),
              ),
              _buildDetailRow('Model', item.model),
              _buildDetailRow('Brand', item.brand),
              _buildDetailRow('Price', '₹${item.price.toStringAsFixed(0)}'),
            ]),

            _buildDetailSection('Status & Location', [
              _buildDetailRow(
                'Status',
                item.status.toUpperCase(),
                color: _getStatusColor(item.status),
              ),
              _buildDetailRow('Shop', item.shopName),
              _buildDetailRow('Shop ID', item.shopId),
            ]),

            _buildDetailSection('Timestamps', [
              _buildDetailRow(
                'Created',
                DateFormat('dd MMM yyyy, HH:mm').format(item.createdAt),
              ),
              _buildDetailRow(
                'Uploaded',
                DateFormat('dd MMM yyyy, HH:mm').format(item.uploadedAt),
              ),
            ]),

            _buildDetailSection('Uploaded By', [
              _buildDetailRow('Name', item.uploadedBy),
              _buildDetailRow('ID', item.uploadedById),
            ]),

            const SizedBox(height: 20),

            // Scan Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openScannerForSearch();
                },
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: Text(
                  'Scan Another ${item.type == 'phone' ? 'IMEI' : 'Serial'}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: color ?? Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (canCopy && onCopy != null)
                  IconButton(
                    icon: const Icon(Icons.content_copy, size: 16),
                    onPressed: onCopy,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copy to clipboard',
                    color: Colors.teal,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildStatusChip(String status) {
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: _getStatusColor(status),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  Widget _buildStatItem(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatsRow(String type) {
    final stats = _stats[type] ?? {'total': 0, 'available': 0, 'sold': 0};

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            'Total',
            stats['total'] ?? 0,
            Colors.teal,
            Icons.inventory,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            'Available',
            stats['available'] ?? 0,
            Colors.green,
            Icons.check_circle,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            'Sold',
            stats['sold'] ?? 0,
            Colors.red,
            Icons.shopping_cart,
          ),
        ),
      ],
    );
  }

  Widget _buildStockItem(StockItem item) {
    final identifierLabel = item.type == 'phone' ? 'IMEI' : 'Serial';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _showItemDetails(item),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status Indicator
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: _getStatusColor(item.status),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.model,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          item.type == 'phone'
                              ? Icons.confirmation_number
                              : Icons.qr_code,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$identifierLabel: ${_formatIdentifierForDisplay(item.identifier, item.type)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.brand} • ${item.shopName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Price and Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildStatusChip(item.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _searchByIdentifier(String identifier) {
    setState(() {
      _searchQuery = identifier;
      _searchController.text = identifier;
      _applyFilters();
    });
  }

  void _copyIdentifierToClipboard(String identifier, String label) {
    Clipboard.setData(ClipboardData(text: identifier));
    _showSuccessSnackbar('$label copied to clipboard');
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _statusFilter = 'all';
      _applyFilters();
    });
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final currentType = _getTypeFromIndex(_currentTabIndex);
    final currentStats =
        _stats[currentType] ?? {'total': 0, 'available': 0, 'sold': 0};
    final currentFilteredList = _getCurrentFilteredStock();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Check'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Phones'),
            Tab(text: 'Base Models'),
            Tab(text: 'TVs'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAllStockData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text(
                    'Loading inventory...',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Search Section
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Search Bar with Scan Button
                      _buildSearchField(),

                      const SizedBox(height: 12),

                      // Stats Row
                      _buildStatsRow(currentType),

                      const SizedBox(height: 12),

                      // Status Filter Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'all', Icons.all_inclusive),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              'Available',
                              'available',
                              Icons.check_circle,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              'Sold',
                              'sold',
                              Icons.shopping_cart,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Results Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${currentFilteredList.length} items',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      if (_searchQuery.isNotEmpty || _statusFilter != 'all')
                        TextButton(
                          onPressed: _clearSearch,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.teal,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.clear_all, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Clear filters',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Stock List
                Expanded(
                  child: currentFilteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_outlined,
                                size: 60,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No matching items found'
                                    : 'No ${_tabTitles[_currentTabIndex].toLowerCase()} available',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_searchQuery.isEmpty)
                                ElevatedButton.icon(
                                  onPressed: _loadAllStockData,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Refresh'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              if (_searchQuery.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: _openScannerForSearch,
                                  icon: const Icon(
                                    Icons.qr_code_scanner,
                                    size: 16,
                                  ),
                                  label: const Text('Scan to Search'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAllStockData,
                          color: Colors.teal,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: currentFilteredList.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _buildStockItem(currentFilteredList[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _statusFilter = selected ? value : 'all';
          _applyFilters();
        });
      },
      avatar: Icon(icon, size: 14),
      backgroundColor: Colors.grey.shade100,
      selectedColor: Colors.teal.withOpacity(0.2),
      checkmarkColor: Colors.teal,
      labelStyle: TextStyle(
        color: isSelected ? Colors.teal : Colors.grey.shade700,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.teal : Colors.grey.shade300,
          width: 1,
        ),
      ),
    );
  }
}

// Optimized Identifier Scanner Widget (Works for IMEI and Serial Numbers)
class OptimizedIdentifierScanner extends StatefulWidget {
  final Function(String) onScanComplete;
  final String title;
  final String description;
  final String type; // 'phone', 'base_model', 'tv'
  final bool autoCloseAfterScan;

  const OptimizedIdentifierScanner({
    super.key,
    required this.onScanComplete,
    required this.type,
    this.title = 'Scan Identifier',
    this.description = 'Align the barcode within the frame',
    this.autoCloseAfterScan = true,
  });

  @override
  State<OptimizedIdentifierScanner> createState() =>
      _OptimizedIdentifierScannerState();
}

class _OptimizedIdentifierScannerState extends State<OptimizedIdentifierScanner>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _scannerController;
  bool _isScanning = true;
  bool _isTorchOn = false;
  bool _isScannerReady = false;
  Timer? _scanDebounceTimer;
  String? _lastScannedData;
  AnimationController? _animationController;
  Animation<double>? _scanAnimation;

  @override
  void initState() {
    super.initState();
    _initScanner();
    _initAnimation();
  }

  void _initScanner() async {
    try {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
        detectionTimeoutMs: 1000,
      );

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() => _isScannerReady = true);
      }
    } catch (e) {
      print('Scanner init error: $e');
    }
  }

  void _initAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );
  }

  void _handleBarcodeScan(BarcodeCapture capture) {
    if (!_isScanning || !_isScannerReady) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final scannedData = barcodes.first.rawValue ?? '';

    if (_scanDebounceTimer != null && _scanDebounceTimer!.isActive) {
      return;
    }

    _scanDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isScanning = true);
      }
    });

    setState(() {
      _isScanning = false;
    });

    // Clean and validate based on type
    final cleanIdentifier = _cleanIdentifier(scannedData);

    if (_isValidIdentifier(cleanIdentifier)) {
      _processValidIdentifier(cleanIdentifier);
    } else {
      _showError(
        'Invalid ${widget.type == 'phone' ? 'IMEI' : 'serial number'}',
      );
    }
  }

  String _cleanIdentifier(String rawData) {
    if (widget.type == 'phone') {
      // For IMEI: remove all non-numeric characters
      return rawData.replaceAll(RegExp(r'[^0-9]'), '');
    } else {
      // For serial numbers: allow alphanumeric
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

  void _processValidIdentifier(String identifier) {
    String displayIdentifier = identifier;
    if (widget.type == 'phone' && identifier.length == 15) {
      displayIdentifier =
          '${identifier.substring(0, 6)} ${identifier.substring(6, 12)} ${identifier.substring(12)}';
    } else if (widget.type == 'phone' && identifier.length == 16) {
      displayIdentifier =
          '${identifier.substring(0, 8)} ${identifier.substring(8)}';
    } else if (widget.type == 'tv' && identifier.length >= 12) {
      displayIdentifier =
          '${identifier.substring(0, 4)}-${identifier.substring(4, 8)}-${identifier.substring(8)}';
    } else if (widget.type == 'tv' && identifier.length >= 8) {
      displayIdentifier =
          '${identifier.substring(0, 4)}-${identifier.substring(4)}';
    }

    setState(() {
      _lastScannedData = '✓ Scanned: $displayIdentifier';
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      widget.onScanComplete(identifier);

      if (widget.autoCloseAfterScan && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _showError(String message) {
    setState(() {
      _lastScannedData = '✗ $message';
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

  void _showManualEntryDialog() {
    final controller = TextEditingController();
    final identifierLabel = widget.type == 'phone' ? 'IMEI' : 'Serial Number';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter $identifierLabel Manually'),
          content: TextField(
            controller: controller,
            keyboardType: widget.type == 'phone'
                ? TextInputType.number
                : TextInputType.text,
            maxLength: widget.type == 'phone' ? 16 : 20,
            decoration: InputDecoration(
              hintText: widget.type == 'phone'
                  ? 'Enter 15-16 digit IMEI'
                  : 'Enter 8-20 character serial number',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final identifier = controller.text.trim();
                if (_isValidIdentifier(_cleanIdentifier(identifier))) {
                  widget.onScanComplete(identifier);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid $identifierLabel'),
                    ),
                  );
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _scanDebounceTimer?.cancel();
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identifierLabel = widget.type == 'phone' ? 'IMEI' : 'Serial Number';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              widget.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
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
                  if (_isScannerReady && _scannerController != null)
                    MobileScanner(
                      controller: _scannerController!,
                      onDetect: _handleBarcodeScan,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      color: Colors.black,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'Initializing Scanner...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Scanner Frame
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.width * 0.8,
                    child: CustomPaint(
                      painter: _ScannerOverlayPainter(
                        _scanAnimation?.value ?? 0,
                      ),
                    ),
                  ),

                  // Status Message
                  if (_lastScannedData != null)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _lastScannedData!.startsWith('✓')
                              ? Colors.green.withOpacity(0.9)
                              : Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _lastScannedData!.startsWith('✓')
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _lastScannedData!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
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

                  // Instructions
                  Positioned(
                    bottom: _lastScannedData != null ? 80 : 20,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Point camera at $identifierLabel barcode',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!_isScanning)
                          const Text(
                            'Processing...',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showManualEntryDialog();
                      },
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Manual Entry'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isScanning
                          ? null
                          : () {
                              setState(() {
                                _isScanning = true;
                                _lastScannedData = null;
                              });
                            },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Rescan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
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
          ],
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scanPosition;

  _ScannerOverlayPainter(this.scanPosition);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw corners
    final cornerLength = 20.0;

    // Top-left
    canvas.drawLine(Offset.zero, Offset(cornerLength, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, cornerLength), paint);

    // Top-right
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      paint,
    );

    // Scanning line
    final scanPaint = Paint()
      ..color = Colors.green.withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final scanY = size.height * scanPosition;
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), scanPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
