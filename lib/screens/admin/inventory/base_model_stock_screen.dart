// lib/screens/admin/inventory/base_model_stock_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BaseModelStockScreen extends StatefulWidget {
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  const BaseModelStockScreen({
    super.key,
    required this.formatNumber,
    required this.shops,
  });

  @override
  State<BaseModelStockScreen> createState() => _BaseModelStockScreenState();
}

class _BaseModelStockScreenState extends State<BaseModelStockScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedStatus = 'available';
  String? _selectedShopId;
  String? _selectedBrand;
  String _searchQuery = '';

  final Color primaryGreen = Color(0xFF0A4D2E);
  final Color secondaryGreen = Color(0xFF1A7D4A);
  final Color accentGreen = Color(0xFF28A745);
  final Color lightGreen = Color(0xFFE8F5E9);
  final Color warningColor = Color(0xFFFFC107);
  final Color dangerColor = Color(0xFFDC3545);

  // Status colors
  final Color availableColor = Color(0xFF4CAF50);
  final Color soldColor = Color(0xFF2196F3);
  final Color returnedColor = Color(0xFFFF9800);

  // Cache for brand list
  List<String> _brands = [];
  bool _isLoadingBrands = true;

  // Cache for counts
  Map<String, int> _statusCounts = {'available': 0, 'sold': 0, 'returned': 0};
  Map<String, double> _statusValues = {
    'available': 0,
    'sold': 0,
    'returned': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    try {
      final snapshot = await _firestore.collection('baseModelStock').get();
      final brands = <String>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['productBrand'] != null &&
            data['productBrand'].toString().isNotEmpty) {
          brands.add(data['productBrand'].toString());
        }
      }

      if (mounted) {
        setState(() {
          _brands = brands.toList()..sort();
          _isLoadingBrands = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBrands = false;
        });
      }
    }
  }

  // Show transfer dialog - DIRECT SHOP SELECTION without dropdown
  Future<void> _showTransferDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    // Filter out current shop
    final availableShops = widget.shops
        .where((shop) => shop['id'] != data['shopId'])
        .toList();

    if (availableShops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No other shops available for transfer'),
          backgroundColor: warningColor,
        ),
      );
      return;
    }

    // Show direct shop selection in a bottom sheet
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer Device to Another Shop',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Device: ${data['productName']}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                'IMEI: ${data['imei']}',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Divider(height: 20),
              Text(
                'Select Destination Shop:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 10),
              ...availableShops.map((shop) {
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: primaryGreen.withOpacity(0.1),
                    child: Icon(Icons.store, color: primaryGreen, size: 18),
                  ),
                  title: Text(
                    shop['name'] ?? 'Unknown',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    'Transfer device to this shop',
                    style: TextStyle(fontSize: 11),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _transferDevice(
                      docId,
                      data,
                      shop['id'],
                      shop['name'],
                    );
                  },
                );
              }),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Transfer device to another shop
  Future<void> _transferDevice(
    String docId,
    Map<String, dynamic> data,
    String newShopId,
    String newShopName,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      await _firestore.collection('baseModelStock').doc(docId).update({
        'shopId': newShopId,
        'shopName': newShopName,
        'transferredAt': FieldValue.serverTimestamp(),
        'transferredFrom': data['shopName'],
        'status': 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('baseModelTransferHistory').add({
        'deviceId': docId,
        'imei': data['imei'],
        'productName': data['productName'],
        'fromShopId': data['shopId'],
        'fromShopName': data['shopName'],
        'toShopId': newShopId,
        'toShopName': newShopName,
        'transferredBy': data['uploadedBy'],
        'transferredAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device transferred successfully to $newShopName'),
            backgroundColor: accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error transferring device: $e'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  // Show delete confirmation dialog
  Future<void> _showDeleteDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Device', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this device?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Product: ${data['productName']}',
                style: TextStyle(fontSize: 13),
              ),
              Text('IMEI: ${data['imei']}', style: TextStyle(fontSize: 13)),
              Text('Shop: ${data['shopName']}', style: TextStyle(fontSize: 13)),
              SizedBox(height: 10),
              Text(
                'This action cannot be undone!',
                style: TextStyle(fontSize: 11, color: dangerColor),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(fontSize: 13)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteDevice(docId, data);
              },
              style: ElevatedButton.styleFrom(backgroundColor: dangerColor),
              child: Text('Delete', style: TextStyle(fontSize: 13)),
            ),
          ],
        );
      },
    );
  }

  // Delete device
  Future<void> _deleteDevice(String docId, Map<String, dynamic> data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      await _firestore.collection('baseModelDeletedRecords').add({
        'originalId': docId,
        'imei': data['imei'],
        'productName': data['productName'],
        'productBrand': data['productBrand'],
        'productPrice': data['productPrice'],
        'shopId': data['shopId'],
        'shopName': data['shopName'],
        'uploadedBy': data['uploadedBy'],
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': data['uploadedBy'],
        'reason': 'Manual deletion',
      });

      await _firestore.collection('baseModelStock').doc(docId).delete();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device deleted successfully'),
            backgroundColor: dangerColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting device: $e'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  // Show return dialog (ONLY RETURN, NO REFUND)
  Future<void> _showReturnDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Return Device', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Device: ${data['productName']}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                'IMEI: ${data['imei']}',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              SizedBox(height: 14),
              Text('Reason for return:', style: TextStyle(fontSize: 13)),
              SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g., Damaged, Wrong model, Customer return...',
                  hintStyle: TextStyle(fontSize: 12),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(fontSize: 13)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please provide a reason for return'),
                      backgroundColor: warningColor,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                await _returnDevice(docId, data, reasonController.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: warningColor),
              child: Text('Return', style: TextStyle(fontSize: 13)),
            ),
          ],
        );
      },
    );
  }

  // Return device (NO REFUND)
  Future<void> _returnDevice(
    String docId,
    Map<String, dynamic> data,
    String reason,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      await _firestore.collection('baseModelStock').doc(docId).update({
        'status': 'returned',
        'returnedAt': FieldValue.serverTimestamp(),
        'returnReason': reason,
        'returnedBy': data['uploadedBy'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('baseModelReturns').add({
        'deviceId': docId,
        'imei': data['imei'],
        'productName': data['productName'],
        'productBrand': data['productBrand'],
        'productPrice': data['productPrice'],
        'shopId': data['shopId'],
        'shopName': data['shopName'],
        'returnReason': reason,
        'returnedBy': data['uploadedBy'],
        'returnedAt': FieldValue.serverTimestamp(),
        'status': 'returned',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device marked as returned successfully'),
            backgroundColor: warningColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing return: $e'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return availableColor;
      case 'sold':
        return soldColor;
      case 'returned':
        return returnedColor;
      default:
        return Colors.grey;
    }
  }

  String _getStatusIcon(String status) {
    switch (status) {
      case 'available':
        return '✓';
      case 'sold':
        return '✕';
      case 'returned':
        return '↺';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        title: Text(
          'Base Model Stock',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 20),
            onPressed: () {
              _loadBrands();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(),
          _buildStatusChips(),
          const Divider(height: 1, color: Colors.grey),
          Expanded(child: _buildStockList()),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: EdgeInsets.all(10),
      color: Colors.white,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: TextField(
          style: TextStyle(fontSize: 12),
          textAlign: TextAlign.left,
          decoration: InputDecoration(
            hintText: 'Search by IMEI, Product Name or Brand...',
            hintStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search, color: primaryGreen, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 16, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
      ),
    );
  }

  Widget _buildStatusChips() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          _buildStatusChip('Available', 'available', availableColor),
          SizedBox(width: 6),
          _buildStatusChip('Sold', 'sold', soldColor),
          SizedBox(width: 6),
          _buildStatusChip('Returned', 'returned', returnedColor),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String statusValue, Color color) {
    final isSelected = _selectedStatus == statusValue;
    int count = _statusCounts[statusValue] ?? 0;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.white : color,
            ),
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
          if (count > 0) ...[
            SizedBox(width: 3),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.3)
                    : color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStatus = statusValue;
          });
        }
      },
      selectedColor: color,
      backgroundColor: Colors.grey[100],
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? color : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      labelPadding: EdgeInsets.symmetric(horizontal: 3),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildStockList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('baseModelStock')
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 36, color: dangerColor),
                SizedBox(height: 6),
                Text(
                  'Error loading data',
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

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory, size: 40, color: Colors.grey[400]),
                SizedBox(height: 6),
                Text(
                  'No base model stock found',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        // Calculate counts from snapshot data
        int available = 0;
        int sold = 0;
        int returned = 0;
        double availableValue = 0;
        double soldValue = 0;
        double returnedValue = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          double price = (data['productPrice'] ?? 0).toDouble();
          String status = data['status'] ?? '';

          if (status == 'available') {
            available++;
            availableValue += price;
          } else if (status == 'sold') {
            sold++;
            soldValue += price;
          } else if (status == 'returned') {
            returned++;
            returnedValue += price;
          }
        }

        // Update counts without triggering setState during build
        _statusCounts = {
          'available': available,
          'sold': sold,
          'returned': returned,
        };
        _statusValues = {
          'available': availableValue,
          'sold': soldValue,
          'returned': returnedValue,
        };

        // Apply filters
        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Status filter
          if (data['status'] != _selectedStatus) return false;

          // Shop filter
          if (_selectedShopId != null) {
            if (data['shopId'] != _selectedShopId) return false;
          }

          // Brand filter
          if (_selectedBrand != null) {
            if (data['productBrand'] != _selectedBrand) return false;
          }

          // Search filter
          if (_searchQuery.isNotEmpty) {
            bool matches =
                (data['imei']?.toString().toLowerCase().contains(
                      _searchQuery,
                    ) ??
                    false) ||
                (data['productName']?.toString().toLowerCase().contains(
                      _searchQuery,
                    ) ??
                    false) ||
                (data['productBrand']?.toString().toLowerCase().contains(
                      _searchQuery,
                    ) ??
                    false);
            if (!matches) return false;
          }

          return true;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 40, color: Colors.grey[400]),
                SizedBox(height: 6),
                Text(
                  'No ${_selectedStatus} items found',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Try changing your filters',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        // Show count of selected status
        int selectedCount = docs.length;
        double selectedValue = 0;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          selectedValue += (data['productPrice'] ?? 0).toDouble();
        }

        return Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getStatusColor(_selectedStatus),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '${_selectedStatus.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(_selectedStatus),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$selectedCount items · ₹${widget.formatNumber(selectedValue)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _loadBrands();
                },
                color: secondaryGreen,
                child: ListView.builder(
                  padding: EdgeInsets.all(6),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildStockCard(doc.id, data);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStockCard(String docId, Map<String, dynamic> data) {
    DateTime uploadedAt = (data['uploadedAt'] as Timestamp).toDate();

    String status = data['status']?.toString() ?? 'unknown';
    Color statusColor = _getStatusColor(status);

    return Card(
      margin: EdgeInsets.only(bottom: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['productName'] ?? 'Unknown Product',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        data['productBrand'] ?? 'Unknown Brand',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _getStatusIcon(status),
                            style: TextStyle(
                              fontSize: 8,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 3),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 16,
                        color: primaryGreen,
                      ),
                      onSelected: (value) {
                        if (value == 'transfer') {
                          _showTransferDialog(docId, data);
                        } else if (value == 'return') {
                          _showReturnDialog(docId, data);
                        } else if (value == 'delete') {
                          _showDeleteDialog(docId, data);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'transfer',
                          child: Row(
                            children: [
                              Icon(
                                Icons.swap_horiz,
                                size: 16,
                                color: primaryGreen,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Transfer Shop',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'return',
                          child: Row(
                            children: [
                              Icon(
                                Icons.assignment_return,
                                size: 16,
                                color: warningColor,
                              ),
                              SizedBox(width: 6),
                              Text('Return', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: dangerColor,
                              ),
                              SizedBox(width: 6),
                              Text('Delete', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 6),

            // Details Grid
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem('IMEI', data['imei'] ?? 'N/A'),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'Price',
                          '₹${widget.formatNumber((data['productPrice'] ?? 0).toDouble())}',
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'Shop',
                          data['shopName'] ?? 'Unknown',
                        ),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'By',
                          data['uploadedBy'] ?? 'Unknown',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'Uploaded',
                          DateFormat('dd/MM/yy').format(uploadedAt),
                        ),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'Time',
                          DateFormat('hh:mm a').format(uploadedAt),
                        ),
                      ),
                    ],
                  ),
                  if (status == 'returned' && data['returnReason'] != null) ...[
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            'Return Reason',
                            data['returnReason'] ?? 'N/A',
                            color: returnedColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (status == 'sold') ...[
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            'Sold At',
                            data['soldAt'] != null
                                ? DateFormat('dd/MM/yy').format(
                                    (data['soldAt'] as Timestamp).toDate(),
                                  )
                                : 'N/A',
                            color: soldColor,
                          ),
                        ),
                        Expanded(
                          child: _buildDetailItem(
                            'Sold By',
                            data['soldBy'] ?? 'Unknown',
                            color: soldColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1),
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
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
