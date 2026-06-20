import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class InventoryDetailsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> shops;
  final String Function(double) formatNumber;

  const InventoryDetailsScreen({
    Key? key,
    required this.shops,
    required this.formatNumber,
  }) : super(key: key);

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
  final Color primaryGreen = const Color(0xFF0A4D2E);
  final Color secondaryGreen = const Color(0xFF1A7D4A);
  final Color lightGreen = const Color(0xFFE8F5E9);

  // Statistics
  int _totalAvailable = 0;
  int _totalSold = 0;
  int _totalReturned = 0;
  double _totalAvailableValue = 0.0;
  double _totalSoldValue = 0.0;
  double _totalReturnedValue = 0.0;

  // User info (you can get this from auth)
  String _currentUserId = "admin@gmail.com";
  String _currentUserName = "Admin";

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
      // Fetch phone stock items (available and sold)
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

        // Get updatedAt timestamp - use updatedAt field first
        DateTime updatedDate;
        if (data['updatedAt'] is Timestamp) {
          updatedDate = (data['updatedAt'] as Timestamp).toDate();
        } else if (data['uploadedAt'] is Timestamp) {
          updatedDate = (data['uploadedAt'] as Timestamp).toDate();
        } else if (status == 'sold' && data['soldAt'] is Timestamp) {
          updatedDate = (data['soldAt'] as Timestamp).toDate();
        } else {
          updatedDate = DateTime.now();
        }

        // Get transfer details if available
        Map<String, dynamic> transferDetails = {};
        if (data['transferredAt'] != null || data['previousShopId'] != null) {
          transferDetails = {
            'previousShopId': data['previousShopId'] ?? '',
            'previousShopName': data['previousShopName'] ?? '',
            'transferredAt': data['transferredAt'] is Timestamp
                ? (data['transferredAt'] as Timestamp).toDate()
                : null,
            'transferredBy': data['transferredBy'] ?? '',
            'transferredById': data['transferredById'] ?? '',
          };
        }

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
          'updatedAt': updatedDate,
          'uploadedAt': data['uploadedAt'] is Timestamp
              ? (data['uploadedAt'] as Timestamp).toDate()
              : DateTime.now(),
          'uploadedBy': data['uploadedBy'] ?? 'Unknown',
          'uploadedById': data['uploadedById'] ?? '',
          // Additional fields for sold items
          'soldAt': data['soldAt'] is Timestamp
              ? (data['soldAt'] as Timestamp).toDate()
              : null,
          'soldTo': data['soldTo'] ?? '',
          'soldBillNo': data['soldBillNo'] ?? '',
          'soldAmount': (data['soldAmount'] as num?)?.toDouble() ?? price,
          'purchaseMode': data['purchaseMode'] ?? '',
          'financeType': data['financeType'] ?? '',
          'soldBy': data['soldBy'] ?? '',
          'soldShop': data['soldShop'] ?? '',
          'createdAt': data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : data['uploadedAt'] is Timestamp
              ? (data['uploadedAt'] as Timestamp).toDate()
              : DateTime.now(),
          // Transfer details
          'previousShopId': transferDetails['previousShopId'] ?? '',
          'previousShopName': transferDetails['previousShopName'] ?? '',
          'transferredAt': transferDetails['transferredAt'],
          'transferredBy': transferDetails['transferredBy'] ?? '',
          'transferredById': transferDetails['transferredById'] ?? '',
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

      // Fetch returned items
      final returnedSnapshot = await _firestore
          .collection('phoneReturns')
          .get();

      for (var doc in returnedSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final price = (data['productPrice'] ?? 0).toDouble();

        // Get updatedAt timestamp - use updatedAt or returnedAt
        DateTime updatedDate;
        if (data['updatedAt'] is Timestamp) {
          updatedDate = (data['updatedAt'] as Timestamp).toDate();
        } else if (data['returnedAt'] is Timestamp) {
          updatedDate = (data['returnedAt'] as Timestamp).toDate();
        } else {
          updatedDate = DateTime.now();
        }

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
          'updatedAt': updatedDate,
          'returnedAt': data['returnedAt'] is Timestamp
              ? (data['returnedAt'] as Timestamp).toDate()
              : DateTime.now(),
          'returnedBy': data['returnedBy'] ?? 'Unknown',
          'reason': data['reason'] ?? '',
          'createdAt': data['returnedAt'] is Timestamp
              ? (data['returnedAt'] as Timestamp).toDate()
              : DateTime.now(),
          // Return items don't have transfer details
          'previousShopId': '',
          'previousShopName': '',
          'transferredAt': null,
          'transferredBy': '',
          'transferredById': '',
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
        color = const Color(0xFF4CAF50);
        break;
      case 'sold':
        title = 'Sold';
        icon = Icons.shopping_cart;
        color = const Color(0xFF2196F3);
        break;
      case 'returned':
        title = 'Returned';
        icon = Icons.assignment_return;
        color = const Color(0xFFFF9800);
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

  // Smart Search Logic that handles partial matches, specs, and IMEI
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

      // CRITICAL: Sort by updatedAt (newest first) for all items
      _filteredInventory.sort((a, b) {
        final dateA = a['updatedAt'] as DateTime;
        final dateB = b['updatedAt'] as DateTime;
        return dateB.compareTo(dateA); // Descending order (newest first)
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
        duration: const Duration(seconds: 3),
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

  // Shop Transfer Function
  Future<void> _transferToAnotherShop(Map<String, dynamic> item) async {
    // Check if item is available
    if (item['status'] != 'available') {
      _showSnackbar('Only available items can be transferred', Colors.orange);
      return;
    }

    // Select target shop
    final String? targetShopId = await _showShopSelectionDialog();
    if (targetShopId == null) return;

    final targetShop = widget.shops.firstWhere(
      (shop) => shop['id'] == targetShopId,
      orElse: () => {'name': 'Unknown', 'id': targetShopId},
    );

    // Confirm transfer
    final confirmed = await _showConfirmationDialog(
      title: 'Transfer Mobile',
      message:
          'Are you sure you want to transfer "${item['productName']}"\n'
          'IMEI: ${_formatImeiForDisplay(item['imei'])}\n\n'
          'From: ${item['shopName']}\n'
          'To: ${targetShop['name']}\n\n'
          'This action cannot be undone.',
      confirmText: 'Transfer',
      confirmColor: Colors.blue,
    );

    if (!confirmed) return;

    _showLoadingDialog();

    try {
      final docRef = _firestore.collection('phoneStock').doc(item['id']);
      final docSnapshot = await docRef.get();
      final data = docSnapshot.data() as Map<String, dynamic>;

      // Create transfer record in transfers collection
      await _firestore.collection('phoneTransfers').add({
        'productName': item['productName'],
        'productBrand': item['productBrand'],
        'productPrice': item['productPrice'],
        'imei': item['imei'],
        'fromShopId': item['shopId'],
        'fromShopName': item['shopName'],
        'toShopId': targetShopId,
        'toShopName': targetShop['name'],
        'transferredAt': FieldValue.serverTimestamp(),
        'transferredBy': _currentUserName,
        'transferredById': _currentUserId,
        'status': 'transferred',
      });

      // Update the original document
      await docRef.update({
        'shopId': targetShopId,
        'shopName': targetShop['name'],
        'status': 'available',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _currentUserName,
        'updatedById': _currentUserId,
        'previousShopId': item['shopId'],
        'previousShopName': item['shopName'],
        'transferredAt': FieldValue.serverTimestamp(),
        'transferredBy': _currentUserName,
        'transferredById': _currentUserId,
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showSnackbar(
          'Mobile transferred successfully to ${targetShop['name']}',
          Colors.green,
        );
        await _loadAllInventory();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Error transferring mobile: $e', Colors.red);
      }
    }
  }

  // Return Phone Function
  Future<void> _returnPhone(Map<String, dynamic> item) async {
    if (item['status'] != 'available') {
      _showSnackbar('Only available items can be returned', Colors.orange);
      return;
    }

    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Returning: ${item['productName']}\n'
              'IMEI: ${_formatImeiForDisplay(item['imei'])}\n'
              'Shop: ${item['shopName']}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Return Reason *',
                hintText: 'e.g., Defective, Damaged, Wrong product',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                _showSnackbar('Please provide a return reason', Colors.orange);
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Return', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final reason = reasonController.text.trim();
    _showLoadingDialog();

    try {
      final docRef = _firestore.collection('phoneStock').doc(item['id']);
      final docSnapshot = await docRef.get();
      final data = docSnapshot.data() as Map<String, dynamic>;

      // Add to returns collection
      await _firestore.collection('phoneReturns').add({
        'originalShopId': item['shopId'],
        'originalShopName': item['shopName'],
        'productName': item['productName'],
        'productBrand': item['productBrand'],
        'productPrice': item['productPrice'],
        'imei': item['imei'],
        'reason': reason,
        'returnedAt': FieldValue.serverTimestamp(),
        'returnedBy': _currentUserName,
        'returnedById': _currentUserId,
        'status': 'returned',
      });

      // Delete from phoneStock
      await docRef.delete();

      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Phone returned successfully', Colors.green);
        await _loadAllInventory();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Error returning phone: $e', Colors.red);
      }
    }
  }

  // Delete Phone from Inventory (Admin only)
  Future<void> _deletePhonePermanently(Map<String, dynamic> item) async {
    final confirmed = await _showConfirmationDialog(
      title: 'Delete Phone Permanently',
      message:
          '⚠️ WARNING: This action is irreversible!\n\n'
          'Are you sure you want to permanently delete:\n'
          'Product: ${item['productName']}\n'
          'IMEI: ${_formatImeiForDisplay(item['imei'])}\n'
          'Shop: ${item['shopName']}\n'
          'Status: ${item['status']}\n\n'
          'This will completely remove the item from inventory.',
      confirmText: 'Delete Permanently',
      confirmColor: Colors.red,
    );

    if (!confirmed) return;

    _showLoadingDialog();

    try {
      if (item['type'] == 'phone_stock') {
        await _firestore.collection('phoneStock').doc(item['id']).delete();
      } else if (item['type'] == 'phone_return') {
        await _firestore.collection('phoneReturns').doc(item['id']).delete();
      }

      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Phone deleted permanently', Colors.green);
        await _loadAllInventory();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Error deleting phone: $e', Colors.red);
      }
    }
  }

  // Helper Dialogs
  Future<String?> _showShopSelectionDialog() async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Target Shop'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.shops.length,
            itemBuilder: (context, index) {
              final shop = widget.shops[index];
              if (_selectedShopId == shop['id']) return const SizedBox.shrink();
              return ListTile(
                leading: Icon(Icons.store, color: primaryGreen),
                title: Text(
                  shop['name'] ?? 'Unknown',
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  'ID: ${shop['id']}',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => Navigator.pop(context, shop['id']),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    Color confirmColor = Colors.red,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title, style: TextStyle(color: confirmColor)),
            content: Text(message, style: const TextStyle(fontSize: 12)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
                child: Text(
                  confirmText,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
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

  // Show item action menu (Transfer, Return, Delete)
  void _showItemActionMenu(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Simple drag handle
            Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            const Text(
              'Item Actions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Action buttons with fixed alignment
            if (item['status'] == 'available' && item['type'] == 'phone_stock')
              _buildActionTile(
                icon: Icons.swap_horiz,
                label: 'Transfer to Another Shop',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _transferToAnotherShop(item);
                },
              ),

            if (item['status'] == 'available' && item['type'] == 'phone_stock')
              _buildActionTile(
                icon: Icons.assignment_return,
                label: 'Return Phone',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _returnPhone(item);
                },
              ),

            _buildActionTile(
              icon: Icons.delete_forever,
              label: 'Delete Permanently',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _deletePhonePermanently(item);
              },
            ),

            const SizedBox(height: 8),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build action tile with proper alignment
  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: onTap,
      dense: false,
    );
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
          hintStyle: const TextStyle(fontSize: 11),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey[600]),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 14),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                    _searchFocusNode.unfocus();
                  },
                ),
              Container(width: 1, height: 20, color: Colors.grey.shade300),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                onPressed: _openScannerForSearch,
                tooltip: 'Scan IMEI to search',
                color: primaryGreen,
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          isDense: true,
          alignLabelWithHint: true,
        ),
        style: const TextStyle(fontSize: 12),
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
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
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
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${widget.formatNumber(value)}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
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
        title: const Text(
          'Inventory Management',
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
              icon: const Icon(Icons.clear_all, size: 20),
              onPressed: _clearAllFilters,
              tooltip: 'Clear all filters',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
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
                  padding: const EdgeInsets.all(10),
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

                          const SizedBox(height: 8),

                          // Shop Dropdown
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Icon(
                                    Icons.store,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      value: _selectedShopId,
                                      isExpanded: true,
                                      hint: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          'All Shops',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      items: [
                                        const DropdownMenuItem<String?>(
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
                                          DropdownMenuItem<String?>
                                        >((shop) {
                                          return DropdownMenuItem<String?>(
                                            value: shop['id'] as String?,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                              child: Text(
                                                shop['name'] as String,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                      style: const TextStyle(
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
                                    icon: const Icon(Icons.clear, size: 14),
                                    onPressed: () {
                                      setState(() => _selectedShopId = null);
                                      _applyFilters();
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 30,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

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
                                    const SizedBox(width: 4),
                                    _buildStatusChip('Sold', 'sold'),
                                    const SizedBox(width: 4),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      _buildStatItem(
                        'Available',
                        _totalAvailable,
                        _totalAvailableValue,
                        const Color(0xFF4CAF50),
                        Icons.check_circle,
                      ),
                      const SizedBox(width: 6),
                      _buildStatItem(
                        'Sold',
                        _totalSold,
                        _totalSoldValue,
                        const Color(0xFF2196F3),
                        Icons.shopping_cart,
                      ),
                      const SizedBox(width: 6),
                      _buildStatItem(
                        'Returned',
                        _totalReturned,
                        _totalReturnedValue,
                        const Color(0xFFFF9800),
                        Icons.assignment_return,
                      ),
                    ],
                  ),
                ),

                // Shop selection indicator
                if (_selectedShopId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
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
                            const SizedBox(width: 8),
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
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                setState(() => _selectedShopId = null);
                                _applyFilters();
                              },
                              tooltip: 'Clear shop filter',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 30),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Current Tab Stats
                _buildCurrentTabStats(),

                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                const SizedBox(height: 6),
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
        chipColor = const Color(0xFF4CAF50);
        break;
      case 'sold':
        chipColor = const Color(0xFF2196F3);
        break;
      case 'returned':
        chipColor = const Color(0xFFFF9800);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      labelPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  Widget _buildCurrentTabStats() {
    final stats = _getCurrentTabStats();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Title with icon
              Row(
                children: [
                  Icon(stats['icon'], size: 16, color: stats['color']),
                  const SizedBox(width: 6),
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
                  const Text(
                    'Count',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
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
                  const Text(
                    'Value',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
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
            const SizedBox(height: 10),
            Text(
              'No items found',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedShopId != null
                  ? 'No ${_selectedStatus} items found for this shop'
                  : 'Try changing your filters or search',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            if (_searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ElevatedButton.icon(
                  onPressed: _openScannerForSearch,
                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                  label: const Text('Scan IMEI to Search'),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _filteredInventory.length,
      itemBuilder: (context, index) {
        final item = _filteredInventory[index];
        return _buildInventoryCard(item);
      },
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    String status = item['status'];
    DateTime updatedDate = item['updatedAt'] as DateTime;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'available':
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.check_circle;
        statusText = 'Available';
        break;
      case 'sold':
        statusColor = const Color(0xFF2196F3);
        statusIcon = Icons.shopping_cart;
        statusText = 'Sold';
        break;
      case 'returned':
        statusColor = const Color(0xFFFF9800);
        statusIcon = Icons.assignment_return;
        statusText = 'Returned';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _showItemDetails(context, item),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 10, color: statusColor),
                            const SizedBox(width: 2),
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
                      // Action Menu Button
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        onPressed: () => _showItemActionMenu(item),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.branding_watermark,
                    size: 12,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item['productBrand'],
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  Text(
                    status == 'sold' && item['soldAmount'] != null
                        ? '₹${widget.formatNumber(item['soldAmount'])}'
                        : '₹${widget.formatNumber(item['productPrice'])}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.store, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item['shopName'],
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.confirmation_number,
                    size: 12,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
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
              const SizedBox(height: 4),
              Divider(height: 1, color: Colors.grey[300]),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Updated',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(updatedDate),
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        status == 'sold'
                            ? 'Sold To'
                            : (item['type'] == 'phone_return'
                                  ? 'Returned By'
                                  : 'Added By'),
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                      Text(
                        status == 'sold'
                            ? item['soldTo'] ?? ''
                            : (item['returnedBy'] ?? item['uploadedBy']),
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
              // Show transfer indicator if available
              if (item['previousShopName'] != null &&
                  item['previousShopName'] != '')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, size: 10, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'Transferred from: ${item['previousShopName']}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.blue[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              if (item['type'] == 'phone_return' && item['reason'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Reason: ${item['reason']}',
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  ),
                ),
              if (status == 'sold' && item['soldBillNo'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Bill No: ${item['soldBillNo']}',
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
    DateTime updatedDate = item['updatedAt'] as DateTime;
    DateTime uploadedDate = item['uploadedAt'] as DateTime;
    String status = item['status'];
    DateTime createdAt = item['createdAt'] as DateTime;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 450,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Product Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: 60,
                height: 3,
                color: primaryGreen,
                margin: const EdgeInsets.only(bottom: 12),
              ),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getStatusColor(status).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getStatusIcon(status),
                              color: _getStatusColor(status),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Status: ${status.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(status),
                              ),
                            ),
                            const Spacer(),
                            if (status == 'sold')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Completed',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Product Info Section
                      _buildDetailSection('Product Information', [
                        _buildDetailRow(
                          'Product Name',
                          item['productName'] ?? 'N/A',
                          icon: Icons.phone_android,
                        ),
                        _buildDetailRow(
                          'Brand',
                          item['productBrand'] ?? 'N/A',
                          icon: Icons.branding_watermark,
                        ),
                        _buildDetailRow(
                          'Price',
                          '₹${widget.formatNumber(item['productPrice'] ?? 0)}',
                          icon: Icons.currency_rupee,
                        ),
                        if (status == 'sold' && item['soldAmount'] != null)
                          _buildDetailRow(
                            'Sold Amount',
                            '₹${widget.formatNumber(item['soldAmount'])}',
                            icon: Icons.monetization_on,
                          ),
                        _buildDetailRow(
                          'IMEI Number',
                          _formatImeiForDisplay(item['imei'] ?? 'N/A'),
                          icon: Icons.confirmation_number,
                          canCopy: true,
                          onCopy: () {
                            Clipboard.setData(
                              ClipboardData(text: item['imei']),
                            );
                            _showSnackbar(
                              'IMEI copied to clipboard',
                              Colors.green,
                            );
                          },
                        ),
                      ]),

                      // Shop & Location Section
                      _buildDetailSection('Shop & Location', [
                        _buildDetailRow(
                          'Current Shop',
                          item['shopName'] ?? 'N/A',
                          icon: Icons.store,
                        ),
                        _buildDetailRow(
                          'Shop ID',
                          item['shopId'] ?? 'N/A',
                          icon: Icons.storefront,
                        ),
                        if (status == 'sold' && item['soldShop'] != null)
                          _buildDetailRow(
                            'Sold From',
                            item['soldShop'] ?? 'N/A',
                            icon: Icons.store_mall_directory,
                          ),
                      ]),

                      // Transfer Information (if transferred)
                      if (item['transferredAt'] != null ||
                          (item['previousShopName'] != null &&
                              item['previousShopName'] != ''))
                        _buildDetailSection('Transfer Information', [
                          if (item['previousShopName'] != null &&
                              item['previousShopName'] != '')
                            _buildDetailRow(
                              'Previous Shop',
                              item['previousShopName'] ?? 'N/A',
                              icon: Icons.storefront,
                            ),
                          if (item['previousShopId'] != null &&
                              item['previousShopId'] != '')
                            _buildDetailRow(
                              'Previous Shop ID',
                              item['previousShopId'] ?? 'N/A',
                              icon: Icons.store,
                            ),
                          if (item['transferredAt'] != null)
                            _buildDetailRow(
                              'Transferred At',
                              DateFormat(
                                'dd MMM yyyy, hh:mm a',
                              ).format(item['transferredAt']),
                              icon: Icons.calendar_today,
                            ),
                          if (item['transferredBy'] != null &&
                              item['transferredBy'] != '')
                            _buildDetailRow(
                              'Transferred By',
                              item['transferredBy'] ?? 'N/A',
                              icon: Icons.person_outline,
                            ),
                          if (item['transferredById'] != null &&
                              item['transferredById'] != '')
                            _buildDetailRow(
                              'Transferred By ID',
                              item['transferredById'] ?? 'N/A',
                              icon: Icons.badge,
                            ),
                        ]),

                      // Sale Information (if sold)
                      if (status == 'sold')
                        _buildDetailSection('Sale Information', [
                          _buildDetailRow(
                            'Customer',
                            item['soldTo'] ?? 'N/A',
                            icon: Icons.person,
                          ),
                          _buildDetailRow(
                            'Bill Number',
                            item['soldBillNo'] ?? 'N/A',
                            icon: Icons.receipt,
                          ),
                          _buildDetailRow(
                            'Purchase Mode',
                            item['purchaseMode'] ?? 'N/A',
                            icon: Icons.payment,
                          ),
                          _buildDetailRow(
                            'Finance Type',
                            item['financeType'] ?? 'N/A',
                            icon: Icons.account_balance,
                          ),
                          _buildDetailRow(
                            'Sold By',
                            item['soldBy'] ?? 'N/A',
                            icon: Icons.person_outline,
                          ),
                          _buildDetailRow(
                            'Sold Date',
                            item['soldAt'] != null
                                ? DateFormat(
                                    'dd MMM yyyy, hh:mm a',
                                  ).format(item['soldAt'])
                                : 'N/A',
                            icon: Icons.calendar_today,
                          ),
                        ]),

                      // Return Information (if returned)
                      if (status == 'returned')
                        _buildDetailSection('Return Information', [
                          _buildDetailRow(
                            'Returned By',
                            item['returnedBy'] ?? 'N/A',
                            icon: Icons.person_outline,
                          ),
                          _buildDetailRow(
                            'Return Reason',
                            item['reason'] ?? 'N/A',
                            icon: Icons.info_outline,
                          ),
                          _buildDetailRow(
                            'Returned Date',
                            item['returnedAt'] != null
                                ? DateFormat(
                                    'dd MMM yyyy, hh:mm a',
                                  ).format(item['returnedAt'])
                                : 'N/A',
                            icon: Icons.calendar_today,
                          ),
                        ]),

                      // Timestamp Section
                      _buildDetailSection('Timestamps', [
                        _buildDetailRow(
                          'Created At',
                          DateFormat('dd MMM yyyy, hh:mm a').format(createdAt),
                          icon: Icons.add_circle_outline,
                        ),
                        _buildDetailRow(
                          'Uploaded At',
                          DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(uploadedDate),
                          icon: Icons.upload_file,
                        ),
                        _buildDetailRow(
                          'Last Updated',
                          DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(updatedDate),
                          icon: Icons.update,
                        ),
                        _buildDetailRow(
                          'Uploaded By',
                          item['uploadedBy'] ?? 'N/A',
                          icon: Icons.person_add,
                        ),
                        _buildDetailRow(
                          'Uploaded By ID',
                          item['uploadedById'] ?? 'N/A',
                          icon: Icons.badge,
                        ),
                      ]),

                      // Additional Info (if available)
                      if (item['notes'] != null || item['description'] != null)
                        _buildDetailSection('Additional Notes', [
                          _buildDetailRow(
                            'Notes',
                            item['notes'] ?? item['description'] ?? 'N/A',
                            icon: Icons.note,
                          ),
                        ]),
                    ],
                  ),
                ),
              ),

              // Action Buttons with proper alignment
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Action buttons using Wrap for proper alignment
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  // Transfer Button (only for available items)
                  if (status == 'available' && item['type'] == 'phone_stock')
                    SizedBox(
                      width: 90,
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _transferToAnotherShop(item);
                        },
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: const Text(
                          'Transfer',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),

                  // Return Button (only for available items)
                  if (status == 'available' && item['type'] == 'phone_stock')
                    SizedBox(
                      width: 90,
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _returnPhone(item);
                        },
                        icon: const Icon(Icons.assignment_return, size: 16),
                        label: const Text(
                          'Return',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),

                  // Delete Button (always visible)
                  SizedBox(
                    width: 90,
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deletePhonePermanently(item);
                      },
                      icon: const Icon(Icons.delete_forever, size: 16),
                      label: const Text(
                        'Delete',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),

                  // Close Button
                  SizedBox(
                    width: 90,
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontSize: 11),
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

  // Helper method to build detail sections
  Widget _buildDetailSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 14, color: primaryGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  // Helper method to build detail row with icon
  Widget _buildDetailRow(
    String label,
    String value, {
    IconData? icon,
    bool canCopy = false,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(icon, size: 14, color: Colors.grey[600]),
            )
          else
            const SizedBox(width: 22),
          Container(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.visible,
                  ),
                ),
                if (canCopy && onCopy != null)
                  IconButton(
                    icon: const Icon(Icons.content_copy, size: 14),
                    onPressed: onCopy,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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

  // Helper methods for status colors and icons
  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return const Color(0xFF4CAF50);
      case 'sold':
        return const Color(0xFF2196F3);
      case 'returned':
        return const Color(0xFFFF9800);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'available':
        return Icons.check_circle;
      case 'sold':
        return Icons.shopping_cart;
      case 'returned':
        return Icons.assignment_return;
      default:
        return Icons.help;
    }
  }
}

// IMEI Scanner Dialog for Inventory Screen
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
      insetPadding: const EdgeInsets.all(20),
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
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0A4D2E),
                borderRadius: BorderRadius.only(
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
                        const Text(
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
                    const Center(
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
                        padding: const EdgeInsets.all(12),
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
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _lastScannedData!,
                                style: const TextStyle(color: Colors.white),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        backgroundColor: const Color(0xFF0A4D2E),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Scan Again'),
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
