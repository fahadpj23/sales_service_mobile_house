// lib/screens/admin/inventory/appliance_stock_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ApplianceStockScreen extends StatefulWidget {
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  const ApplianceStockScreen({
    super.key,
    required this.formatNumber,
    required this.shops,
  });

  @override
  State<ApplianceStockScreen> createState() => _ApplianceStockScreenState();
}

class _ApplianceStockScreenState extends State<ApplianceStockScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedStatus = 'all';
  String? _selectedShopId;
  String? _selectedBrand;
  String _searchQuery = '';

  final Color primaryGreen = const Color(0xFF0A4D2E);
  final Color secondaryGreen = const Color(0xFF1A7D4A);
  final Color accentGreen = const Color(0xFF28A745);
  final Color lightGreen = const Color(0xFFE8F5E9);
  final Color warningColor = const Color(0xFFFFC107);
  final Color dangerColor = const Color(0xFFDC3545);

  // Cache for brand list
  List<String> _brands = [];
  bool _isLoadingBrands = true;

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    try {
      final snapshot = await _firestore.collection('applianceStock').get();
      final brands = <String>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['productBrand'] != null &&
            data['productBrand'].toString().isNotEmpty) {
          brands.add(data['productBrand'].toString());
        }
      }

      setState(() {
        _brands = brands.toList()..sort();
        _isLoadingBrands = false;
      });
    } catch (e) {
      print('Error loading brands: $e');
      setState(() {
        _isLoadingBrands = false;
      });
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
                'Transfer Appliance to Another Shop',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Appliance: ${data['productName']}',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                'Quantity: ${data['quantity']} units',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Divider(height: 24),
              Text(
                'Select Destination Shop:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              ...availableShops.map((shop) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryGreen.withOpacity(0.1),
                    child: Icon(Icons.store, color: primaryGreen, size: 20),
                  ),
                  title: Text(shop['name'] ?? 'Unknown'),
                  subtitle: Text('Transfer appliance to this shop'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _transferAppliance(
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

  // Transfer appliance to another shop
  Future<void> _transferAppliance(
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
      await _firestore.collection('applianceStock').doc(docId).update({
        'shopId': newShopId,
        'shopName': newShopName,
        'transferredAt': FieldValue.serverTimestamp(),
        'transferredFrom': data['shopName'],
        'status': 'available', // Reset status to available
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': data['uploadedBy'],
      });

      // Add transfer record to history collection
      await _firestore.collection('applianceTransferHistory').add({
        'applianceId': docId,
        'productName': data['productName'],
        'quantity': data['quantity'],
        'fromShopId': data['shopId'],
        'fromShopName': data['shopName'],
        'toShopId': newShopId,
        'toShopName': newShopName,
        'transferredBy': data['uploadedBy'],
        'transferredAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appliance transferred successfully to $newShopName'),
          backgroundColor: accentGreen,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error transferring appliance: $e'),
          backgroundColor: dangerColor,
        ),
      );
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
          title: Text('Delete Appliance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this appliance?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('Product: ${data['productName']}'),
              Text('Brand: ${data['productBrand']}'),
              Text('Quantity: ${data['quantity']} units'),
              Text('Shop: ${data['shopName']}'),
              SizedBox(height: 12),
              Text(
                'This action cannot be undone!',
                style: TextStyle(color: dangerColor, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteAppliance(docId, data);
              },
              style: ElevatedButton.styleFrom(backgroundColor: dangerColor),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // Delete appliance
  Future<void> _deleteAppliance(String docId, Map<String, dynamic> data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      // Add to deleted records collection before deleting
      await _firestore.collection('applianceDeletedRecords').add({
        'originalId': docId,
        'productName': data['productName'],
        'productBrand': data['productBrand'],
        'productPrice': data['productPrice'],
        'quantity': data['quantity'],
        'shopId': data['shopId'],
        'shopName': data['shopName'],
        'uploadedBy': data['uploadedBy'],
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': data['uploadedBy'],
        'reason': 'Manual deletion',
      });

      // Delete from main collection
      await _firestore.collection('applianceStock').doc(docId).delete();

      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appliance deleted successfully'),
          backgroundColor: dangerColor,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting appliance: $e'),
          backgroundColor: dangerColor,
        ),
      );
    }
  }

  // Show return dialog (ONLY RETURN, NO REFUND)
  Future<void> _showReturnDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final TextEditingController reasonController = TextEditingController();
    int quantityToReturn = 1;
    int maxQuantity = (data['quantity'] ?? 0).toInt();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Return Appliance'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appliance: ${data['productName']}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Brand: ${data['productBrand']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  Text('Quantity to return:'),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, color: primaryGreen),
                        onPressed: () {
                          if (quantityToReturn > 1) {
                            setState(() {
                              quantityToReturn--;
                            });
                          }
                        },
                      ),
                      Container(
                        width: 60,
                        child: Text(
                          '$quantityToReturn',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: primaryGreen),
                        onPressed: () {
                          if (quantityToReturn < maxQuantity) {
                            setState(() {
                              quantityToReturn++;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  Text(
                    'Available quantity: $maxQuantity units',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  Text('Reason for return:'),
                  SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'e.g., Damaged, Wrong model, Customer return...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
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
                    await _returnAppliance(
                      docId,
                      data,
                      quantityToReturn,
                      reasonController.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: warningColor,
                  ),
                  child: Text('Return'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Return appliance (NO REFUND)
  Future<void> _returnAppliance(
    String docId,
    Map<String, dynamic> data,
    int quantityToReturn,
    String reason,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      int currentQuantity = (data['quantity'] ?? 0).toInt();
      int newQuantity = currentQuantity - quantityToReturn;

      if (newQuantity < 0) {
        throw Exception('Cannot return more than available quantity');
      }

      // Update appliance stock
      final updateData = {
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': data['uploadedBy'],
      };

      // If quantity becomes 0, mark as sold out or returned
      if (newQuantity == 0) {
        updateData['status'] = 'returned';
        updateData['returnedAt'] = FieldValue.serverTimestamp();
        updateData['returnReason'] = reason;
        updateData['returnedBy'] = data['uploadedBy'];
      }

      await _firestore
          .collection('applianceStock')
          .doc(docId)
          .update(updateData);

      // Add to returns collection
      await _firestore.collection('applianceReturns').add({
        'applianceId': docId,
        'productName': data['productName'],
        'productBrand': data['productBrand'],
        'productPrice': data['productPrice'],
        'quantityReturned': quantityToReturn,
        'shopId': data['shopId'],
        'shopName': data['shopName'],
        'returnReason': reason,
        'returnedBy': data['uploadedBy'],
        'returnedAt': FieldValue.serverTimestamp(),
        'status': 'returned',
      });

      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$quantityToReturn unit(s) returned successfully'),
          backgroundColor: warningColor,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing return: $e'),
          backgroundColor: dangerColor,
        ),
      );
    }
  }

  // Show options menu for each appliance card
  void _showOptionsMenu(String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Options for ${data['productName']}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.swap_horiz, color: primaryGreen),
                title: Text('Transfer to Another Shop'),
                subtitle: Text('Move this appliance to a different shop'),
                onTap: () {
                  Navigator.pop(context);
                  _showTransferDialog(docId, data);
                },
              ),
              ListTile(
                leading: Icon(Icons.assignment_return, color: warningColor),
                title: Text('Return'),
                subtitle: Text('Mark this appliance as returned'),
                onTap: () {
                  Navigator.pop(context);
                  _showReturnDialog(docId, data);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: dangerColor),
                title: Text('Delete'),
                subtitle: Text('Permanently remove this appliance'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog(docId, data);
                },
              ),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        title: const Text(
          'Appliances Stock',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              _loadBrands();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          _buildFilterBar(),
          Expanded(child: _buildStockList()),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('applianceStock').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 70,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        var docs = snapshot.data!.docs;

        // Apply all filters in memory for summary
        var filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Status filter
          if (_selectedStatus != 'all') {
            if (data['status'] != _selectedStatus) return false;
          }

          // Shop filter
          if (_selectedShopId != null) {
            if (data['shopId'] != _selectedShopId) return false;
          }

          // Brand filter
          if (_selectedBrand != null) {
            if (data['productBrand'] != _selectedBrand) return false;
          }

          return true;
        }).toList();

        int totalItems = 0;
        double totalValue = 0;
        int availableItems = 0;
        double availableValue = 0;
        int returnedItems = 0;

        for (var doc in filteredDocs) {
          final data = doc.data() as Map<String, dynamic>;
          int quantity = (data['quantity'] ?? 0).toInt();
          double price = (data['productPrice'] ?? 0).toDouble();

          totalItems += quantity;
          totalValue += (price * quantity);

          if (data['status'] == 'available') {
            availableItems += quantity;
            availableValue += (price * quantity);
          } else if (data['status'] == 'returned') {
            returnedItems += quantity;
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Stock',
                  '$totalItems',
                  '₹${widget.formatNumber(totalValue)}',
                  Icons.inventory,
                  primaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Available',
                  '$availableItems',
                  '₹${widget.formatNumber(availableValue)}',
                  Icons.check_circle,
                  accentGreen,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String count,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.left,
                ),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.left,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              textAlign: TextAlign.left,
              decoration: InputDecoration(
                hintText: 'Search by Product Name, Brand...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: primaryGreen, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(height: 8),

          // Filters Row
          Row(
            children: [
              // Status Filter
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: primaryGreen,
                    ),
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          'All Status',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'available',
                        child: Text(
                          'Available',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'sold',
                        child: Text(
                          'Sold',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'returned',
                        child: Text(
                          'Returned',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Shop Filter
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedShopId,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: primaryGreen,
                    ),
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    hint: const Text(
                      'All Shops',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                      textAlign: TextAlign.left,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'All Shops',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      ...widget.shops.map((shop) {
                        return DropdownMenuItem<String>(
                          value: shop['id'] as String?,
                          child: Text(
                            shop['name'] as String? ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (String? value) {
                      setState(() {
                        _selectedShopId = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Brand Filter Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _isLoadingBrands
                      ? const Center(
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : DropdownButton<String>(
                          value: _selectedBrand,
                          isExpanded: true,
                          underline: const SizedBox(),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: primaryGreen,
                          ),
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          hint: const Text(
                            'All Brands',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.left,
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                'All Brands',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                            ..._brands.map((brand) {
                              return DropdownMenuItem<String>(
                                value: brand,
                                child: Text(
                                  brand,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.left,
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (String? value) {
                            setState(() {
                              _selectedBrand = value;
                            });
                          },
                        ),
                ),
              ),
              if (_selectedBrand != null ||
                  _selectedShopId != null ||
                  _selectedStatus != 'all')
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  child: IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    color: dangerColor,
                    onPressed: () {
                      setState(() {
                        _selectedStatus = 'all';
                        _selectedShopId = null;
                        _selectedBrand = null;
                        _searchQuery = '';
                      });
                    },
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('applianceStock')
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 40, color: dangerColor),
                const SizedBox(height: 8),
                Text(
                  'Error loading data',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pull down to refresh',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
                Icon(Icons.kitchen, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No appliances found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        // Apply all filters in memory
        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Status filter
          if (_selectedStatus != 'all') {
            if (data['status'] != _selectedStatus) return false;
          }

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
                Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No matching items',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try changing your filters',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: secondaryGreen,
          child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildStockCard(doc.id, data);
            },
          ),
        );
      },
    );
  }

  Widget _buildStockCard(String docId, Map<String, dynamic> data) {
    DateTime uploadedAt = (data['uploadedAt'] as Timestamp).toDate();
    DateTime? createdAt = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : uploadedAt;
    DateTime? lastUpdatedAt = data['lastUpdatedAt'] != null
        ? (data['lastUpdatedAt'] as Timestamp).toDate()
        : null;

    Color statusColor = data['status'] == 'available'
        ? accentGreen
        : data['status'] == 'returned'
        ? warningColor
        : Colors.grey;
    String status = data['status']?.toString().toUpperCase() ?? 'UNKNOWN';
    int quantity = (data['quantity'] ?? 0).toInt();
    double price = (data['productPrice'] ?? 0).toDouble();
    double totalValue = price * quantity;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: data['status'] == 'available'
              ? Border.all(color: accentGreen.withOpacity(0.2), width: 1)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with options button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.kitchen,
                            color: primaryGreen,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['productName'] ?? 'Unknown Product',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: primaryGreen,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.left,
                              ),
                              Text(
                                data['productBrand'] ?? 'Unknown Brand',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                        ),
                      ],
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
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: 4),
                      // Options menu button
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          size: 18,
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
                                  size: 18,
                                  color: primaryGreen,
                                ),
                                SizedBox(width: 8),
                                Text('Transfer Shop'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'return',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.assignment_return,
                                  size: 18,
                                  color: warningColor,
                                ),
                                SizedBox(width: 8),
                                Text('Return'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: dangerColor,
                                ),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Details
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactDetailRow(
                            'Quantity',
                            '$quantity units',
                          ),
                        ),
                        Expanded(
                          child: _buildCompactDetailRow(
                            'Price',
                            '₹${widget.formatNumber(price)}',
                          ),
                        ),
                        Expanded(
                          child: _buildCompactDetailRow(
                            'Total',
                            '₹${widget.formatNumber(totalValue)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactDetailRow(
                            'Shop',
                            data['shopName'] ?? 'Unknown',
                          ),
                        ),
                        Expanded(
                          child: _buildCompactDetailRow(
                            'By',
                            data['uploadedBy'] ?? 'Unknown',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactDetailRow(
                            'Uploaded',
                            DateFormat('dd/MM/yy hh:mm a').format(uploadedAt),
                          ),
                        ),
                        if (lastUpdatedAt != null)
                          Expanded(
                            child: _buildCompactDetailRow(
                              'Updated',
                              DateFormat(
                                'dd/MM/yy hh:mm a',
                              ).format(lastUpdatedAt),
                            ),
                          ),
                      ],
                    ),
                    if (lastUpdatedAt != null && data['lastUpdatedBy'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildCompactDetailRow(
                                'Updated By',
                                data['lastUpdatedBy'] ?? 'Unknown',
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Show return info if returned
                    if (data['status'] == 'returned' &&
                        data['returnReason'] != null)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: _buildCompactDetailRow(
                          'Return Reason',
                          data['returnReason'] ?? 'N/A',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.left,
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}
