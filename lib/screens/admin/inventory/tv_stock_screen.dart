// lib/screens/admin/inventory/tv_stock_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TvStockScreen extends StatefulWidget {
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  const TvStockScreen({
    super.key,
    required this.formatNumber,
    required this.shops,
  });

  @override
  State<TvStockScreen> createState() => _TvStockScreenState();
}

class _TvStockScreenState extends State<TvStockScreen> {
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

  // Current user info (you can get this from auth)
  String _currentUserId = "admin@gmail.com";
  String _currentUserName = "Admin";

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
      final snapshot = await _firestore.collection('tvStock').get();
      final brands = <String>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['modelBrand'] != null &&
            data['modelBrand'].toString().isNotEmpty) {
          brands.add(data['modelBrand'].toString());
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

  String _resolveTransferredFromDisplay(Map<String, dynamic> data) {
    final explicit = (data['transferredFromShopName'] as String?)?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final legacy = (data['transferredFrom'] as String?)?.trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;

    return '';
  }

  // ==================== EDIT TV DETAILS ====================
  Future<void> _editTvDetails(String docId, Map<String, dynamic> data) async {
    final TextEditingController modelController = TextEditingController(
      text: data['modelName'] ?? '',
    );
    final TextEditingController brandController = TextEditingController(
      text: data['modelBrand'] ?? '',
    );
    final TextEditingController priceController = TextEditingController(
      text: (data['modelPrice'] ?? 0).toString(),
    );
    final TextEditingController serialController = TextEditingController(
      text: data['serialNumber'] ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: primaryGreen, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Edit TV Details',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Current Details:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Model: ${data['modelName']}',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Brand: ${data['modelBrand']}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Price: ₹${widget.formatNumber((data['modelPrice'] ?? 0).toDouble())}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Serial: ${data['serialNumber'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontFamily: 'Monospace',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Shop: ${data['shopName'] ?? 'Unknown'}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: modelController,
                decoration: const InputDecoration(
                  labelText: 'TV Model Name *',
                  hintText: 'e.g., Samsung 43" Smart LED TV',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  prefixIcon: Icon(Icons.tv, size: 18),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: brandController,
                decoration: const InputDecoration(
                  labelText: 'Brand *',
                  hintText: 'e.g., Samsung',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  prefixIcon: Icon(Icons.branding_watermark, size: 18),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price *',
                  hintText: 'e.g., 35000',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  prefixIcon: Icon(Icons.currency_rupee, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: serialController,
                decoration: const InputDecoration(
                  labelText: 'Serial Number *',
                  hintText: 'e.g., SN123456789',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  prefixIcon: Icon(Icons.confirmation_number, size: 18),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (modelController.text.trim().isEmpty) {
                _showSnackbar('Model name cannot be empty', Colors.orange);
                return;
              }
              if (brandController.text.trim().isEmpty) {
                _showSnackbar('Brand cannot be empty', Colors.orange);
                return;
              }
              final price = double.tryParse(priceController.text.trim());
              if (price == null || price < 0) {
                _showSnackbar('Please enter a valid price', Colors.orange);
                return;
              }
              if (serialController.text.trim().isEmpty) {
                _showSnackbar('Serial number cannot be empty', Colors.orange);
                return;
              }
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final newModel = modelController.text.trim();
    final newBrand = brandController.text.trim();
    final newPrice = double.tryParse(priceController.text.trim()) ?? 0.0;
    final newSerial = serialController.text.trim();

    if (newModel == data['modelName'] &&
        newBrand == data['modelBrand'] &&
        newPrice == (data['modelPrice'] ?? 0).toDouble() &&
        newSerial == data['serialNumber']) {
      _showSnackbar('No changes made', Colors.blue);
      return;
    }

    _showLoadingDialog();

    try {
      await _firestore.collection('tvStock').doc(docId).update({
        'modelName': newModel,
        'modelBrand': newBrand,
        'modelPrice': newPrice,
        'serialNumber': newSerial,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': _currentUserName,
      });

      if (newModel != data['modelName'] || newSerial != data['serialNumber']) {
        try {
          final transferQuery = await _firestore
              .collection('tvTransferHistory')
              .where('tvId', isEqualTo: docId)
              .get();

          for (var doc in transferQuery.docs) {
            await doc.reference.update({
              'modelName': newModel,
              'modelBrand': newBrand,
              'serialNumber': newSerial,
            });
          }
        } catch (e) {
          print('Could not update transfer history: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('TV details updated successfully', accentGreen);
        _loadBrands();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Error updating TV: $e', dangerColor);
      }
    }
  }

  // ==================== CHANGE STATUS (Available / Sold / Returned) ====================
  Future<void> _changeStatus(String docId, Map<String, dynamic> data) async {
    final currentStatus = (data['status'] ?? 'available').toString();
    final source = 'tvStock'; // this screen always reads from tvStock

    // Pick target status
    final String? target = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Status', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current status: ${currentStatus.toUpperCase()}\n'
              'Choose the new status for this TV.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (currentStatus != 'available')
              ListTile(
                leading: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                ),
                title: const Text(
                  'Move to Available',
                  style: TextStyle(fontSize: 13),
                ),
                onTap: () => Navigator.pop(ctx, 'available'),
              ),
            if (currentStatus != 'sold')
              ListTile(
                leading: const Icon(
                  Icons.shopping_cart,
                  color: Color(0xFF2196F3),
                ),
                title: const Text(
                  'Move to Sold',
                  style: TextStyle(fontSize: 13),
                ),
                onTap: () => Navigator.pop(ctx, 'sold'),
              ),
            if (currentStatus != 'returned')
              ListTile(
                leading: const Icon(
                  Icons.assignment_return,
                  color: Color(0xFFFF9800),
                ),
                title: const Text(
                  'Move to Returned',
                  style: TextStyle(fontSize: 13),
                ),
                onTap: () => Navigator.pop(ctx, 'returned'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );

    if (target == null || target == currentStatus) return;

    // If leaving 'sold', the TV already has a bill — warn + delete bill
    if (currentStatus == 'sold') {
      final billIds = await _findBillsForTv(data);

      final proceed = await _showConfirmationDialog(
        title: 'Bill Already Exists',
        message:
            'This TV already has a bill.\n\n'
            'Do you want to continue?\n\n'
            'If you continue, the bill will be removed from the "bills" collection '
            'and the TV will be moved to "${target.toUpperCase()}".',
        confirmText: 'Continue',
        confirmColor: dangerColor,
      );

      if (!proceed) return;

      if (billIds.isNotEmpty) {
        _showLoadingDialog();
        try {
          for (final id in billIds) {
            await _firestore.collection('bills').doc(id).delete();
          }
        } catch (e) {
          if (mounted) Navigator.pop(context);
          _showSnackbar('Error removing bill: $e', dangerColor);
          return;
        }
        if (mounted) Navigator.pop(context);
        _showSnackbar('Bill removed from bills collection', accentGreen);
      }
    }

    // Collect extra info
    Map<String, dynamic> extras = {};

    if (target == 'sold') {
      final r = await _collectSaleInfo(data);
      if (r == null) return;
      extras = r;
    } else if (target == 'returned') {
      final r = await _collectReturnInfo(data);
      if (r == null) return;
      extras = r;
    }

    _showLoadingDialog();

    try {
      if (target == 'returned') {
        // Update existing tvStock doc → returned + add tvReturns record
        await _firestore.collection('tvStock').doc(docId).update({
          'status': 'returned',
          'returnReason': extras['reason'] ?? '',
          'returnedAt': FieldValue.serverTimestamp(),
          'returnedBy': _currentUserName,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await _firestore.collection('tvReturns').add({
          'tvId': docId,
          'serialNumber': data['serialNumber'],
          'modelName': data['modelName'],
          'modelBrand': data['modelBrand'],
          'modelPrice': data['modelPrice'],
          'shopId': data['shopId'],
          'shopName': data['shopName'],
          'returnReason': extras['reason'] ?? '',
          'returnedBy': _currentUserName,
          'returnedAt': FieldValue.serverTimestamp(),
          'status': 'returned',
        });
      } else if (target == 'sold') {
        await _firestore.collection('tvStock').doc(docId).update({
          'status': 'sold',
          'soldTo': extras['soldTo'] ?? '',
          'soldToMobile': extras['soldToMobile'] ?? '',
          'soldBillNo': extras['soldBillNo'] ?? '',
          'soldAmount': extras['soldAmount'] ?? data['modelPrice'],
          'purchaseMode': extras['purchaseMode'] ?? '',
          'financeType': extras['financeType'] ?? '',
          'soldBy': _currentUserName,
          'soldShop': data['shopName'],
          'soldAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (target == 'available') {
        // Restore to available — keep same doc, clear sold / return fields
        await _firestore.collection('tvStock').doc(docId).update({
          'status': 'available',
          'soldTo': FieldValue.delete(),
          'soldToMobile': FieldValue.delete(),
          'soldBillNo': FieldValue.delete(),
          'soldAmount': FieldValue.delete(),
          'purchaseMode': FieldValue.delete(),
          'financeType': FieldValue.delete(),
          'soldBy': FieldValue.delete(),
          'soldShop': FieldValue.delete(),
          'soldAt': FieldValue.delete(),
          'returnReason': FieldValue.delete(),
          'returnedAt': FieldValue.delete(),
          'returnedBy': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Status changed to ${target.toUpperCase()}', accentGreen);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Error changing status: $e', dangerColor);
      }
    }
  }

  /// Finds bill IDs matching this TV (by soldBillNo and/or serial number).
  Future<List<String>> _findBillsForTv(Map<String, dynamic> data) async {
    final List<String> ids = [];
    try {
      final serial = (data['serialNumber'] ?? '').toString();
      final billNo = (data['soldBillNo'] ?? '').toString();

      if (serial.isNotEmpty && serial != 'N/A') {
        final q1 = await _firestore
            .collection('bills')
            .where('serialNumber', isEqualTo: serial)
            .get();
        for (final d in q1.docs) {
          if (!ids.contains(d.id)) ids.add(d.id);
        }
      }

      if (billNo.isNotEmpty) {
        final q2 = await _firestore
            .collection('bills')
            .where('billNumber', isEqualTo: billNo)
            .get();
        for (final d in q2.docs) {
          if (!ids.contains(d.id)) ids.add(d.id);
        }
      }
    } catch (e) {
      print('Error finding bill for TV: $e');
    }
    return ids;
  }

  Future<Map<String, dynamic>?> _collectSaleInfo(
    Map<String, dynamic> data,
  ) async {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final billCtrl = TextEditingController();
    final amountCtrl = TextEditingController(
      text: (data['modelPrice'] ?? 0).toString(),
    );
    final modeCtrl = TextEditingController(text: 'Ready Cash');
    final financeCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sale Information', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Customer Phone',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: billCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Bill Number (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Sold Amount',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: modeCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Purchase Mode (EMI / Ready Cash)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: financeCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Finance Type (if EMI)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );

    if (confirmed != true) return null;

    final amount =
        double.tryParse(amountCtrl.text.trim()) ?? (data['modelPrice'] ?? 0);

    return {
      'soldTo': nameCtrl.text.trim(),
      'soldToMobile': mobileCtrl.text.trim(),
      'soldBillNo': billCtrl.text.trim(),
      'soldAmount': amount,
      'purchaseMode': modeCtrl.text.trim(),
      'financeType': financeCtrl.text.trim(),
    };
  }

  Future<Map<String, dynamic>?> _collectReturnInfo(
    Map<String, dynamic> data,
  ) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return Information', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Return Reason',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    return {'reason': reasonCtrl.text.trim()};
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
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

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    Color confirmColor = Colors.red,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              title,
              style: TextStyle(fontSize: 16, color: confirmColor),
            ),
            content: Text(message, style: const TextStyle(fontSize: 12)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
                child: Text(
                  confirmText,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Show transfer dialog
  Future<void> _showTransferDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final availableShops = widget.shops
        .where((shop) => shop['id'] != data['shopId'])
        .toList();

    if (availableShops.isEmpty) {
      _showSnackbar('No other shops available for transfer', warningColor);
      return;
    }

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
                'Transfer TV to Another Shop',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'TV: ${data['modelName']}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                'Serial: ${data['serialNumber']}',
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
                    'Transfer TV to this shop',
                    style: TextStyle(fontSize: 11),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _transferTV(docId, data, shop['id'], shop['name']);
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

  Future<void> _transferTV(
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
      final fromShopName =
          (data['shopName'] as String?)?.trim().isNotEmpty == true
          ? (data['shopName'] as String).trim()
          : 'Unknown Shop';
      final fromShopId = (data['shopId'] as String?) ?? '';

      await _firestore.collection('tvStock').doc(docId).update({
        'shopId': newShopId,
        'shopName': newShopName,
        'transferredAt': FieldValue.serverTimestamp(),
        'transferredFromShopId': fromShopId,
        'transferredFromShopName': fromShopName,
        'transferredFrom': fromShopName,
        'status': 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('tvTransferHistory').add({
        'tvId': docId,
        'serialNumber': data['serialNumber'],
        'modelName': data['modelName'],
        'fromShopId': data['shopId'],
        'fromShopName': data['shopName'],
        'toShopId': newShopId,
        'toShopName': newShopName,
        'transferredBy': data['uploadedBy'],
        'transferredAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        _showSnackbar(
          'TV transferred successfully to $newShopName',
          accentGreen,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Error transferring TV: $e', dangerColor);
      }
    }
  }

  Future<void> _showDeleteDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete TV Item', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this TV?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Model: ${data['modelName']}',
                style: TextStyle(fontSize: 13),
              ),
              Text(
                'Serial: ${data['serialNumber']}',
                style: TextStyle(fontSize: 13),
              ),
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
                await _deleteTV(docId, data);
              },
              style: ElevatedButton.styleFrom(backgroundColor: dangerColor),
              child: Text('Delete', style: TextStyle(fontSize: 13)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTV(String docId, Map<String, dynamic> data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      await _firestore.collection('tvDeletedRecords').add({
        'originalId': docId,
        'serialNumber': data['serialNumber'],
        'modelName': data['modelName'],
        'modelBrand': data['modelBrand'],
        'modelPrice': data['modelPrice'],
        'shopId': data['shopId'],
        'shopName': data['shopName'],
        'uploadedBy': data['uploadedBy'],
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': _currentUserName,
        'reason': 'Manual deletion',
      });

      await _firestore.collection('tvStock').doc(docId).delete();

      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('TV deleted successfully', dangerColor);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Error deleting TV: $e', dangerColor);
      }
    }
  }

  Future<void> _showReturnDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Return TV', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TV: ${data['modelName']}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                'Serial: ${data['serialNumber']}',
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
                  _showSnackbar(
                    'Please provide a reason for return',
                    warningColor,
                  );
                  return;
                }
                Navigator.pop(context);
                await _returnTV(docId, data, reasonController.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: warningColor),
              child: Text('Return', style: TextStyle(fontSize: 13)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _returnTV(
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
      await _firestore.collection('tvStock').doc(docId).update({
        'status': 'returned',
        'returnedAt': FieldValue.serverTimestamp(),
        'returnReason': reason,
        'returnedBy': _currentUserName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('tvReturns').add({
        'tvId': docId,
        'serialNumber': data['serialNumber'],
        'modelName': data['modelName'],
        'modelBrand': data['modelBrand'],
        'modelPrice': data['modelPrice'],
        'shopId': data['shopId'],
        'shopName': data['shopName'],
        'returnReason': reason,
        'returnedBy': _currentUserName,
        'returnedAt': FieldValue.serverTimestamp(),
        'status': 'returned',
      });

      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('TV marked as returned successfully', warningColor);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('Error processing return: $e', dangerColor);
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
          'TV Stock',
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
          _buildSearchAndFilterArea(),
          _buildStatusChips(),
          const Divider(height: 1, color: Colors.grey),
          Expanded(child: _buildStockList()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterArea() {
    return Container(
      padding: EdgeInsets.all(10),
      color: Colors.white,
      child: Column(
        children: [
          Container(
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
                hintText: 'Search by Serial, Model or Brand...',
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
                contentPadding: EdgeInsets.symmetric(
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
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildShopFilterDropdown()),
              if (_selectedShopId != null) ...[
                SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _selectedShopId = null;
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  style: IconButton.styleFrom(
                    minimumSize: Size(24, 24),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShopFilterDropdown() {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButton<String>(
        value: _selectedShopId,
        isExpanded: true,
        underline: SizedBox(),
        icon: Icon(Icons.storefront, size: 16, color: primaryGreen),
        iconSize: 16,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[800],
          fontWeight: FontWeight.w500,
        ),
        hint: Row(
          children: [
            Icon(Icons.storefront, size: 14, color: Colors.grey[500]),
            SizedBox(width: 4),
            Text(
              'All Shops',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Row(
              children: [
                Icon(Icons.storefront, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'All Shops',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          ...widget.shops.map((shop) {
            final shopName = shop['name'] ?? 'Unknown';
            return DropdownMenuItem<String>(
              value: shop['id'],
              child: Row(
                children: [
                  Icon(Icons.store, size: 14, color: primaryGreen),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      shopName,
                      style: TextStyle(fontSize: 11, color: Colors.grey[800]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
        onChanged: (String? newValue) {
          setState(() {
            _selectedShopId = newValue;
          });
        },
        borderRadius: BorderRadius.circular(8),
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
          .collection('tvStock')
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
                Icon(Icons.tv, size: 40, color: Colors.grey[400]),
                SizedBox(height: 6),
                Text(
                  'No TV stock found',
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

        int available = 0;
        int sold = 0;
        int returned = 0;
        double availableValue = 0;
        double soldValue = 0;
        double returnedValue = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          double price = (data['modelPrice'] ?? 0).toDouble();
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

        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          if (data['status'] != _selectedStatus) return false;

          if (_selectedShopId != null) {
            if (data['shopId'] != _selectedShopId) return false;
          }

          if (_selectedBrand != null) {
            if (data['modelBrand'] != _selectedBrand) return false;
          }

          if (_searchQuery.isNotEmpty) {
            bool matches =
                (data['serialNumber']?.toString().toLowerCase().contains(
                      _searchQuery,
                    ) ??
                    false) ||
                (data['modelName']?.toString().toLowerCase().contains(
                      _searchQuery,
                    ) ??
                    false) ||
                (data['modelBrand']?.toString().toLowerCase().contains(
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

        int selectedCount = docs.length;
        double selectedValue = 0;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          selectedValue += (data['modelPrice'] ?? 0).toDouble();
        }

        String selectedShopName = 'All Shops';
        if (_selectedShopId != null) {
          final shop = widget.shops.firstWhere(
            (s) => s['id'] == _selectedShopId,
            orElse: () => {'name': 'Unknown'},
          );
          selectedShopName = shop['name'] ?? 'Unknown';
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
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          selectedShopName,
                          style: TextStyle(
                            fontSize: 9,
                            color: primaryGreen,
                            fontWeight: FontWeight.w500,
                          ),
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

    final transferredFromDisplay = _resolveTransferredFromDisplay(data);

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['modelName'] ?? 'Unknown Model',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        data['modelBrand'] ?? 'Unknown Brand',
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
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        size: 15,
                        color: primaryGreen.withOpacity(0.7),
                      ),
                      onPressed: () => _editTvDetails(docId, data),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 28),
                      tooltip: 'Edit TV details',
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 16,
                        color: primaryGreen,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editTvDetails(docId, data);
                        } else if (value == 'change_status') {
                          _changeStatus(docId, data);
                        } else if (value == 'transfer') {
                          _showTransferDialog(docId, data);
                        } else if (value == 'return') {
                          _showReturnDialog(docId, data);
                        } else if (value == 'delete') {
                          _showDeleteDialog(docId, data);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16, color: primaryGreen),
                              SizedBox(width: 6),
                              Text(
                                'Edit Details',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // NEW: Change Status
                        PopupMenuItem(
                          value: 'change_status',
                          child: Row(
                            children: [
                              Icon(
                                Icons.swap_vert,
                                size: 16,
                                color: Colors.purple,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Change Status',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
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
                        child: _buildDetailItem(
                          'Serial',
                          data['serialNumber'] ?? 'N/A',
                        ),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'Price',
                          '₹${widget.formatNumber((data['modelPrice'] ?? 0).toDouble())}',
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
                  if (transferredFromDisplay.isNotEmpty) ...[
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            'Transferred From',
                            transferredFromDisplay,
                            color: primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                  if (data['lastUpdatedAt'] != null) ...[
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            'Updated',
                            DateFormat('dd/MM/yy').format(
                              (data['lastUpdatedAt'] as Timestamp).toDate(),
                            ),
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
                    // NEW: customer info if present
                    if ((data['soldTo'] ?? '').toString().isNotEmpty ||
                        (data['soldToMobile'] ?? '').toString().isNotEmpty) ...[
                      SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              'Customer',
                              data['soldTo'] ?? 'N/A',
                              color: soldColor,
                            ),
                          ),
                          Expanded(
                            child: _buildDetailItem(
                              'Mobile',
                              data['soldToMobile'] ?? 'N/A',
                              color: soldColor,
                            ),
                          ),
                        ],
                      ),
                    ],
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
