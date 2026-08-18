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
  String _selectedStatus = 'available';
  String? _selectedShopId;
  String? _selectedBrand;
  String _searchQuery = '';

  static const Color primaryGreen = Color(0xFF0A4D2E);
  static const Color secondaryGreen = Color(0xFF1A7D4A);
  static const Color accentGreen = Color(0xFF28A745);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color dangerColor = Color(0xFFDC3545);

  // Status colors
  final Color availableColor = Color(0xFF4CAF50);
  final Color soldColor = Color(0xFF2196F3);
  final Color returnedColor = Color(0xFFFF9800);

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
      final snapshot = await _firestore.collection('applianceStock').get();
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
      print('Error loading brands: $e');
      if (mounted) {
        setState(() {
          _isLoadingBrands = false;
        });
      }
    }
  }

  // Show quantity selection dialog
  Future<int?> _showQuantitySelectionDialog(
    Map<String, dynamic> data,
    String action,
    String actionLabel,
  ) async {
    int currentQuantity = (data['quantity'] ?? 0).toInt();

    int selectedQuantity = 1;
    TextEditingController reasonController = TextEditingController();

    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    action == 'transfer'
                        ? Icons.swap_horiz
                        : action == 'return'
                        ? Icons.assignment_return
                        : Icons.delete_outline,
                    color: action == 'transfer'
                        ? primaryGreen
                        : action == 'return'
                        ? warningColor
                        : dangerColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Select Quantity to $actionLabel',
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product: ${data['productName']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Brand: ${data['productBrand']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Available: $currentQuantity units',
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Select quantity:',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: selectedQuantity > 1
                                ? primaryGreen
                                : Colors.grey,
                            size: 24,
                          ),
                          onPressed: () {
                            if (selectedQuantity > 1) {
                              setState(() {
                                selectedQuantity--;
                              });
                            }
                          },
                        ),
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: primaryGreen,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$selectedQuantity',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryGreen,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: selectedQuantity < currentQuantity
                                ? primaryGreen
                                : Colors.grey,
                            size: 24,
                          ),
                          onPressed: () {
                            if (selectedQuantity < currentQuantity) {
                              setState(() {
                                selectedQuantity++;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedQuantity = 1;
                            });
                          },
                          child: const Text(
                            'Reset',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedQuantity = currentQuantity;
                            });
                          },
                          child: const Text(
                            'Select All',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    if (action == 'return')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          const Text(
                            'Return Reason:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: reasonController,
                            style: TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'e.g., Damaged, Wrong model...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.all(10),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedQuantity < 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least 1 unit'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    if (selectedQuantity > currentQuantity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cannot select more than $currentQuantity units',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    if (action == 'return' &&
                        reasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please provide a reason for return'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, selectedQuantity);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: action == 'transfer'
                        ? primaryGreen
                        : action == 'return'
                        ? warningColor
                        : dangerColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    '$actionLabel $selectedQuantity',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show transfer dialog with quantity selection
  Future<void> _showTransferDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    int? quantityToTransfer = await _showQuantitySelectionDialog(
      data,
      'transfer',
      'Transfer',
    );

    if (quantityToTransfer == null || quantityToTransfer < 1) return;

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

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer Appliance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 6),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appliance: ${data['productName']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Quantity: $quantityToTransfer units',
                      style: TextStyle(
                        fontSize: 11,
                        color: primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
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
                    'Transfer $quantityToTransfer units to this shop',
                    style: TextStyle(fontSize: 11),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _transferAppliance(
                      docId,
                      data,
                      shop['id'],
                      shop['name'],
                      quantityToTransfer,
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

  // Transfer appliance to another shop with quantity
  Future<void> _transferAppliance(
    String docId,
    Map<String, dynamic> data,
    String newShopId,
    String newShopName,
    int quantityToTransfer,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      int currentQuantity = (data['quantity'] ?? 0).toInt();
      int remainingQuantity = currentQuantity - quantityToTransfer;

      final updateData = {
        'quantity': remainingQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': data['uploadedBy'],
      };

      if (remainingQuantity == 0) {
        updateData['status'] = 'transferred';
        updateData['transferredAt'] = FieldValue.serverTimestamp();
        updateData['transferredTo'] = newShopName;
      }

      await _firestore
          .collection('applianceStock')
          .doc(docId)
          .update(updateData);

      final targetQuery = await _firestore
          .collection('applianceStock')
          .where('productName', isEqualTo: data['productName'])
          .where('productBrand', isEqualTo: data['productBrand'])
          .where('shopId', isEqualTo: newShopId)
          .get();

      if (targetQuery.docs.isNotEmpty) {
        final targetDoc = targetQuery.docs.first;
        final targetData = targetDoc.data();
        int targetQuantity = (targetData['quantity'] ?? 0).toInt();

        await _firestore.collection('applianceStock').doc(targetDoc.id).update({
          'quantity': targetQuantity + quantityToTransfer,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': data['uploadedBy'],
          'status': 'available',
        });
      } else {
        await _firestore.collection('applianceStock').add({
          'productName': data['productName'],
          'productBrand': data['productBrand'],
          'productPrice': data['productPrice'],
          'quantity': quantityToTransfer,
          'shopId': newShopId,
          'shopName': newShopName,
          'uploadedBy': data['uploadedBy'],
          'uploadedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'available',
          'transferredFrom': data['shopName'],
          'transferredAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestore.collection('applianceTransferHistory').add({
        'applianceId': docId,
        'productName': data['productName'],
        'productBrand': data['productBrand'],
        'quantity': quantityToTransfer,
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
            content: Text(
              '$quantityToTransfer unit(s) transferred successfully to $newShopName',
            ),
            backgroundColor: accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error transferring appliance: $e'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  // Show delete confirmation dialog with quantity selection
  Future<void> _showDeleteDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    int? quantityToDelete = await _showQuantitySelectionDialog(
      data,
      'delete',
      'Delete',
    );

    if (quantityToDelete == null || quantityToDelete < 1) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Appliance', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this appliance?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product: ${data['productName']}',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Brand: ${data['productBrand']}',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Quantity to delete: $quantityToDelete units',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Shop: ${data['shopName']}',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
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
              child: Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteAppliance(docId, data, quantityToDelete);
              },
              style: ElevatedButton.styleFrom(backgroundColor: dangerColor),
              child: Text(
                'Delete $quantityToDelete',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  // Delete appliance with quantity
  Future<void> _deleteAppliance(
    String docId,
    Map<String, dynamic> data,
    int quantityToDelete,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      int currentQuantity = (data['quantity'] ?? 0).toInt();
      int remainingQuantity = currentQuantity - quantityToDelete;

      if (remainingQuantity < 0) {
        throw Exception('Cannot delete more than available quantity');
      }

      if (remainingQuantity == 0) {
        await _firestore.collection('applianceDeletedRecords').add({
          'originalId': docId,
          'productName': data['productName'],
          'productBrand': data['productBrand'],
          'productPrice': data['productPrice'],
          'quantity': quantityToDelete,
          'shopId': data['shopId'],
          'shopName': data['shopName'],
          'uploadedBy': data['uploadedBy'],
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': data['uploadedBy'],
          'reason': 'Manual deletion',
        });

        await _firestore.collection('applianceStock').doc(docId).delete();
      } else {
        await _firestore.collection('applianceStock').doc(docId).update({
          'quantity': remainingQuantity,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': data['uploadedBy'],
        });

        await _firestore.collection('applianceDeletedRecords').add({
          'originalId': docId,
          'productName': data['productName'],
          'productBrand': data['productBrand'],
          'productPrice': data['productPrice'],
          'quantity': quantityToDelete,
          'remainingQuantity': remainingQuantity,
          'shopId': data['shopId'],
          'shopName': data['shopName'],
          'uploadedBy': data['uploadedBy'],
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': data['uploadedBy'],
          'reason': 'Partial deletion',
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$quantityToDelete unit(s) deleted successfully'),
            backgroundColor: dangerColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting appliance: $e'),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  // Show return dialog with quantity selection
  Future<void> _showReturnDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    await _showReturnWithReasonDialog(docId, data);
  }

  // Alternative return dialog with reason
  Future<void> _showReturnWithReasonDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    int currentQuantity = (data['quantity'] ?? 0).toInt();
    int selectedQuantity = 1;
    TextEditingController reasonController = TextEditingController();

    int? result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.assignment_return, color: warningColor, size: 20),
                  const SizedBox(width: 10),
                  Text('Return Appliance', style: TextStyle(fontSize: 15)),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product: ${data['productName']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Brand: ${data['productBrand']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Available: $currentQuantity units',
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Select quantity to return:',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: selectedQuantity > 1
                                ? primaryGreen
                                : Colors.grey,
                            size: 24,
                          ),
                          onPressed: () {
                            if (selectedQuantity > 1) {
                              setState(() {
                                selectedQuantity--;
                              });
                            }
                          },
                        ),
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: primaryGreen,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$selectedQuantity',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryGreen,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: selectedQuantity < currentQuantity
                                ? primaryGreen
                                : Colors.grey,
                            size: 24,
                          ),
                          onPressed: () {
                            if (selectedQuantity < currentQuantity) {
                              setState(() {
                                selectedQuantity++;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedQuantity = 1;
                            });
                          },
                          child: const Text(
                            'Reset',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedQuantity = currentQuantity;
                            });
                          },
                          child: const Text(
                            'Select All',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Return Reason:',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      style: TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'e.g., Damaged, Wrong model...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(10),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedQuantity < 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least 1 unit'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    if (selectedQuantity > currentQuantity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cannot select more than $currentQuantity units',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    if (reasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please provide a reason for return'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, selectedQuantity);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: warningColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Return $selectedQuantity',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result < 1) return;

    String reason = reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for return'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _returnAppliance(docId, data, result, reason);
  }

  // Return appliance with quantity
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

      final updateData = {
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': data['uploadedBy'],
      };

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

      await _firestore.collection('applianceReturns').add({
        'applianceId': docId,
        'productName': data['productName'],
        'productBrand': data['productBrand'],
        'productPrice': data['productPrice'],
        'quantityReturned': quantityToReturn,
        'remainingQuantity': newQuantity,
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
            content: Text('$quantityToReturn unit(s) returned successfully'),
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

  // Show options menu for each appliance card
  void _showOptionsMenu(String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Options for ${data['productName']}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              Divider(height: 1),
              ListTile(
                dense: true,
                leading: Icon(Icons.swap_horiz, color: primaryGreen, size: 20),
                title: Text(
                  'Transfer to Another Shop',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  'Move this appliance to a different shop',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showTransferDialog(docId, data);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.assignment_return,
                  color: warningColor,
                  size: 20,
                ),
                title: Text('Return', style: TextStyle(fontSize: 13)),
                subtitle: Text(
                  'Mark this appliance as returned',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showReturnDialog(docId, data);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.delete_outline,
                  color: dangerColor,
                  size: 20,
                ),
                title: Text('Delete', style: TextStyle(fontSize: 13)),
                subtitle: Text(
                  'Permanently remove this appliance',
                  style: TextStyle(fontSize: 11),
                ),
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
        title: const Text(
          'Appliances Stock',
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
            icon: const Icon(Icons.refresh, size: 20),
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
          style: TextStyle(fontSize: 12, color: Colors.black87),
          textAlign: TextAlign.left,
          decoration: InputDecoration(
            hintText: 'Search by Product Name, Brand...',
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
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
                Icon(Icons.error_outline, size: 36, color: dangerColor),
                const SizedBox(height: 6),
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
                Icon(Icons.kitchen, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 6),
                Text(
                  'No appliances found',
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
          int quantity = (data['quantity'] ?? 0).toInt();
          double price = (data['productPrice'] ?? 0).toDouble();
          String status = data['status'] ?? '';

          if (status == 'available') {
            available += quantity;
            availableValue += (price * quantity);
          } else if (status == 'sold') {
            sold += quantity;
            soldValue += (price * quantity);
          } else if (status == 'returned') {
            returned += quantity;
            returnedValue += (price * quantity);
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
                const SizedBox(height: 6),
                Text(
                  'No ${_selectedStatus} items found',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try changing your filters',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        // Show count of selected status
        int selectedCount = 0;
        double selectedValue = 0;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          int quantity = (data['quantity'] ?? 0).toInt();
          double price = (data['productPrice'] ?? 0).toDouble();
          selectedCount += quantity;
          selectedValue += (price * quantity);
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
                    '$selectedCount units · ₹${widget.formatNumber(selectedValue)}',
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
    DateTime? lastUpdatedAt = data['lastUpdatedAt'] != null
        ? (data['lastUpdatedAt'] as Timestamp).toDate()
        : null;

    String status = data['status']?.toString() ?? 'unknown';
    Color statusColor = _getStatusColor(status);
    int quantity = (data['quantity'] ?? 0).toInt();
    double price = (data['productPrice'] ?? 0).toDouble();

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
                        child: _buildDetailItem('Qty', '$quantity units'),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'Price',
                          '₹${widget.formatNumber(price)}',
                        ),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'Total',
                          '₹${widget.formatNumber(price * quantity)}',
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
                  if (lastUpdatedAt != null) ...[
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            'Updated',
                            DateFormat('dd/MM/yy').format(lastUpdatedAt),
                          ),
                        ),
                        Expanded(
                          child: _buildDetailItem(
                            'By',
                            data['lastUpdatedBy'] ?? 'Unknown',
                          ),
                        ),
                      ],
                    ),
                  ],
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
