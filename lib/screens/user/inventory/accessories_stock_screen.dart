import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sales_stock/providers/auth_provider.dart';
// Point this at your GSTAccessoriesSaleUpload file.
import '../sale/gst_accessories_sale_upload.dart';

const String _kAccessoriesStockCollection = 'accessoriesStock';
const String _kAccessoriesSoldCollection = 'accessoriesSoldRecords';
const String _kAccessoriesReturnCollection = 'accessoriesReturns';
const String _kShopsCollection = 'Mobile_house_Shops';
const String _fixedCategory = 'Accessories';

class AccessoriesStockScreen extends StatefulWidget {
  const AccessoriesStockScreen({super.key});

  @override
  State<AccessoriesStockScreen> createState() => _AccessoriesStockScreenState();
}

enum _StockTab { available, sold, returned }

class _AccessoriesStockScreenState extends State<AccessoriesStockScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  _StockTab _tab = _StockTab.available;
  String _query = '';
  bool _loading = true;
  String? _error;

  List<QueryDocumentSnapshot> _allStock = [];
  List<QueryDocumentSnapshot> _allReturns = [];
  List<Map<String, dynamic>> _shops = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? get _shopId =>
      Provider.of<AuthProvider>(context, listen: false).user?.shopId;

  Future<void> _loadAll() async {
    await Future.wait([_loadStockAndReturns(), _loadShops()]);
  }

  Future<void> _loadStockAndReturns() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final shopId = _shopId;

      Query stockQuery = _firestore.collection(_kAccessoriesStockCollection);
      if (shopId != null && shopId.isNotEmpty) {
        stockQuery = stockQuery.where('shopId', isEqualTo: shopId);
      }
      final stockSnap = await stockQuery.get();

      Query returnQuery = _firestore.collection(_kAccessoriesReturnCollection);
      if (shopId != null && shopId.isNotEmpty) {
        returnQuery = returnQuery.where('originalShopId', isEqualTo: shopId);
      }
      final returnSnap = await returnQuery.get();

      final stockDocs = stockSnap.docs.toList()
        ..sort((a, b) {
          final an = ((a.data() as Map<String, dynamic>)['productName'] ?? '')
              .toString()
              .toLowerCase();
          final bn = ((b.data() as Map<String, dynamic>)['productName'] ?? '')
              .toString()
              .toLowerCase();
          return an.compareTo(bn);
        });

      if (!mounted) return;
      setState(() {
        _allStock = stockDocs;
        _allReturns = returnSnap.docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadShops() async {
    try {
      final snapshot = await _firestore.collection(_kShopsCollection).get();
      if (!mounted) return;
      setState(() {
        _shops = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['shopName'] ?? 'Unknown Shop',
            'address': data['address'] ?? '',
          };
        }).toList();
      });
    } catch (_) {}
  }

  List<QueryDocumentSnapshot> _itemsForTab(_StockTab tab) {
    if (tab == _StockTab.returned) {
      if (_query.isEmpty) return _allReturns;
      return _allReturns.where((d) {
        final m = d.data() as Map<String, dynamic>;
        final haystack = [
          m['productName'],
          m['productBrand'],
          m['reason'],
        ].where((e) => e != null).join(' ').toLowerCase();
        return haystack.contains(_query);
      }).toList();
    }

    final list = _allStock.where((d) {
      final m = d.data() as Map<String, dynamic>;
      final qty = (m['quantity'] as num?)?.toInt() ?? 0;
      final status = (m['status'] ?? 'available').toString().toLowerCase();
      final isReturned = (m['isReturned'] as bool?) ?? false;
      if (isReturned || status == 'returned') return false;
      return tab == _StockTab.available ? qty > 0 : qty <= 0;
    }).toList();

    if (_query.isEmpty) return list;
    return list.where((d) {
      final m = d.data() as Map<String, dynamic>;
      final haystack = [
        m['productName'],
        m['productBrand'],
        m['modelName'],
        m['category'],
        m['purchaseInvoiceNo'],
      ].where((e) => e != null).join(' ').toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  List<QueryDocumentSnapshot> get _filtered => _itemsForTab(_tab);

  int _totalUnits(List<QueryDocumentSnapshot> docs) {
    var total = 0;
    for (final d in docs) {
      total +=
          ((d.data() as Map<String, dynamic>)['quantity'] as num?)?.toInt() ??
          0;
    }
    return total;
  }

  double _totalSaleValue(List<QueryDocumentSnapshot> docs) {
    var total = 0.0;
    for (final d in docs) {
      final m = d.data() as Map<String, dynamic>;
      final qty = (m['quantity'] as num?)?.toInt() ?? 0;
      final price = (m['productPrice'] as num?)?.toDouble() ?? 0.0;
      total += qty * price;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Accessories Stock',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'New Direct Sale',
              onPressed: _openDirectSale,
              icon: const Icon(Icons.add_shopping_cart),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            _buildTabBar(),
            _buildSummaryStrip(),
            Expanded(child: _buildBody()),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openDirectSale,
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          icon: const Icon(Icons.point_of_sale),
          label: const Text('Direct Sale'),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      color: Colors.white,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search accessories by name, brand or invoice…',
                  hintStyle: TextStyle(fontSize: 12),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => _searchController.clear(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final counts = {
      _StockTab.available: _itemsForTab(_StockTab.available).length,
      _StockTab.sold: _itemsForTab(_StockTab.sold).length,
      _StockTab.returned: _itemsForTab(_StockTab.returned).length,
    };

    Widget tab(_StockTab t, String label, IconData icon, MaterialColor color) {
      final selected = _tab == t;
      final count = counts[t] ?? 0;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = t),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: selected ? color[50] : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? color : Colors.grey[300]!,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: selected ? color[700] : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: selected ? color[800] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: selected ? color[800] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          tab(
            _StockTab.available,
            'Available',
            Icons.check_circle_outline,
            Colors.green,
          ),
          tab(_StockTab.sold, 'Sold', Icons.sell_outlined, Colors.orange),
          tab(
            _StockTab.returned,
            'Return',
            Icons.assignment_return_outlined,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip() {
    final items = _filtered;
    final units = _totalUnits(items);
    final sale = _totalSaleValue(items);

    final MaterialColor accent = _tab == _StockTab.available
        ? Colors.green
        : _tab == _StockTab.sold
        ? Colors.orange
        : Colors.red;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          _summaryTile(
            icon: Icons.inventory_2_outlined,
            label: 'Units',
            value: '$units',
            color: accent,
          ),
          const SizedBox(width: 8),
          _summaryTile(
            icon: Icons.currency_rupee,
            label: 'Sale Value',
            value: NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹',
              decimalDigits: 0,
            ).format(sale),
            color: accent,
          ),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color[100]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color[700]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 10, color: color[800]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color[800],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              const Text(
                'Failed to load accessories stock',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filtered;
    if (items.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final doc = items[index];
          if (_tab == _StockTab.returned) {
            return _AccessoryReturnCard(doc: doc);
          }
          return _AccessoryStockCard(
            doc: doc,
            tab: _tab,
            busy: _isProcessing,
            onSell: _tab == _StockTab.available ? () => _sellStock(doc) : null,
            onTransfer: _tab == _StockTab.available
                ? () => _transferStock(doc)
                : null,
            onReturn: _tab == _StockTab.available
                ? () => _returnStock(doc)
                : null,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearch = _query.isNotEmpty;
    final label = isSearch
        ? 'No results for "$_query"'
        : switch (_tab) {
            _StockTab.available => 'No available accessories in stock',
            _StockTab.sold => 'No sold accessories yet',
            _StockTab.returned => 'No returns recorded',
          };
    final icon = switch (_tab) {
      _StockTab.available => Icons.inventory_2_outlined,
      _StockTab.sold => Icons.sell_outlined,
      _StockTab.returned => Icons.assignment_return_outlined,
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 10),
        Center(
          child: Text(
            isSearch ? 'No results found' : 'No stock found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // =========================================================================
  // DIRECT SALE (no product pre-selected)
  // =========================================================================
  Future<void> _openDirectSale() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GSTAccessoriesSaleUpload()),
    );

    if (saved == true) {
      _showSuccess('Sale completed');
      await _loadStockAndReturns();
    }
  }

  // =========================================================================
  // SELL  — opens GSTAccessoriesSaleUpload with product auto-filled.
  // Stock is updated ONLY after the bill screen returns true.
  // =========================================================================
  Future<void> _sellStock(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final available = (data['quantity'] as num?)?.toInt() ?? 0;
    if (available <= 0) {
      _showError('This item is out of stock');
      return;
    }

    final defaultPrice = (data['productPrice'] as num?)?.toDouble() ?? 0.0;
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController(
      text: defaultPrice.toStringAsFixed(2),
    );

    int tempQty = 1;
    double tempPrice = defaultPrice;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final valid = tempQty > 0 && tempQty <= available && tempPrice > 0;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.sell, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sell Accessory',
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
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (data['productName'] ?? 'Item').toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          (data['productBrand'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Available: $available pcs',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final q = int.tryParse(v);
                            if (q != null) setS(() => tempQty = q);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Sale Price',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final p = double.tryParse(v);
                            if (p != null) setS(() => tempPrice = p);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (tempQty > available)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Only $available available',
                        style: TextStyle(fontSize: 11, color: Colors.red[700]),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: valid ? () => Navigator.of(ctx).pop(true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continue to Bill'),
              ),
            ],
          );
        },
      ),
    );

    qtyController.dispose();
    priceController.dispose();

    if (confirm != true) return;

    // Open the GST bill form with the accessory data pre-filled.
    final billProductData = {
      'productName': data['productName'] ?? '',
      'productBrand': data['productBrand'] ?? '',
      'productPrice': defaultPrice, // pre-GST base for reference
      'sellingPrice': tempPrice,
      'quantity': tempQty,
      'modelId': doc.id,
      'totalAmount': tempQty * tempPrice,
      'category': _fixedCategory,
      'billType': 'accessorySale',
    };

    setState(() => _isProcessing = true);
    try {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GSTAccessoriesSaleUpload(productData: billProductData),
        ),
      );

      if (saved != true) {
        // User backed out or bill failed — leave stock untouched.
        return;
      }

      // ------- bill saved successfully → now mark stock as sold -------
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        _showError('User not authenticated');
        return;
      }

      final stockRef = _firestore
          .collection(_kAccessoriesStockCollection)
          .doc(doc.id);

      int newQty = 0;

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(stockRef);
        if (!snap.exists) throw Exception('Stock record not found');
        final fresh = snap.data() as Map<String, dynamic>;
        final freshQty = (fresh['quantity'] as num?)?.toInt() ?? 0;
        if (freshQty < tempQty) {
          throw Exception('Only $freshQty left in stock');
        }

        newQty = freshQty - tempQty;

        tx.update(stockRef, {
          'quantity': newQty,
          'status': newQty > 0 ? 'available' : 'sold',
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': user.email ?? user.name ?? 'Unknown',
          if (newQty == 0) 'soldAt': FieldValue.serverTimestamp(),
          if (newQty == 0) 'soldBy': user.email ?? user.name ?? 'Unknown',
          if (newQty == 0) 'soldById': user.uid,
        });

        final soldRef = _firestore
            .collection(_kAccessoriesSoldCollection)
            .doc();
        tx.set(soldRef, {
          'category': _fixedCategory,
          'productBrand': fresh['productBrand'] ?? '',
          'productName': fresh['productName'] ?? '',
          'productPrice': fresh['productPrice'] ?? 0,
          'purchaseRate': fresh['purchaseRate'] ?? 0,
          'purchaseInvoiceNo': fresh['purchaseInvoiceNo'] ?? '',
          'quantity': tempQty,
          'sellingPrice': tempPrice,
          'totalAmount': tempQty * tempPrice,
          'shopId': fresh['shopId'] ?? '',
          'shopName': fresh['shopName'] ?? '',
          'soldBy': user.email ?? user.name ?? 'Unknown',
          'soldById': user.uid,
          'soldAt': FieldValue.serverTimestamp(),
          'originalStockId': doc.id,
          'billGenerated': true,
          'remainingQuantity': newQty,
        });
      });

      _showSuccess('$tempQty unit(s) sold. Stock marked as sold.');
      await _loadStockAndReturns();
    } catch (e) {
      _showError('Failed to complete sale: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // =========================================================================
  // TRANSFER  (batched write; pre-query target doc)
  // =========================================================================
  Future<void> _transferStock(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final available = (data['quantity'] as num?)?.toInt() ?? 0;
    if (available <= 0) {
      _showError('This item is out of stock');
      return;
    }

    final currentShopId = (data['shopId'] ?? '').toString();
    final otherShops = _shops.where((s) => s['id'] != currentShopId).toList();

    if (otherShops.isEmpty) {
      _showError('No other shops available for transfer');
      return;
    }

    final qtyController = TextEditingController(text: '1');
    int tempQty = 1;

    final picked = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final valid = tempQty > 0 && tempQty <= available;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.swap_horiz, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Transfer Accessory',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['productName'] ?? 'Item').toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Available: $available pcs',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity to Transfer',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final q = int.tryParse(v);
                    if (q != null) setS(() => tempQty = q);
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select destination shop:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 160,
                  width: 300,
                  child: ListView.builder(
                    itemCount: otherShops.length,
                    itemBuilder: (_, i) {
                      final s = otherShops[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.store,
                          size: 18,
                          color: Colors.blue[700],
                        ),
                        title: Text(
                          (s['name'] ?? '').toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: ((s['address'] ?? '') as String).isNotEmpty
                            ? Text(
                                s['address'],
                                style: const TextStyle(fontSize: 10),
                              )
                            : null,
                        onTap: valid
                            ? () => Navigator.of(ctx).pop({
                                'shopId': s['id'],
                                'shopName': s['name'],
                                'qty': tempQty,
                              })
                            : null,
                      );
                    },
                  ),
                ),
                if (!valid)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Enter a quantity between 1 and $available',
                      style: TextStyle(fontSize: 11, color: Colors.red[700]),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );

    qtyController.dispose();

    if (picked == null) return;

    final newShopId = picked['shopId'] as String;
    final newShopName = picked['shopName'] as String;
    final transferQty = picked['qty'] as int;

    setState(() => _isProcessing = true);
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        _showError('User not authenticated');
        return;
      }

      final sourceShopId = (data['shopId'] ?? '').toString();
      final sourceShopName = (data['shopName'] ?? '').toString();

      final freshSnap = await _firestore
          .collection(_kAccessoriesStockCollection)
          .doc(doc.id)
          .get();
      if (!freshSnap.exists) {
        _showError('Stock record no longer exists');
        return;
      }
      final freshData = freshSnap.data() as Map<String, dynamic>;
      final freshQty = (freshData['quantity'] as num?)?.toInt() ?? 0;
      if (freshQty < transferQty) {
        _showError('Only $freshQty available now');
        return;
      }

      QueryDocumentSnapshot<Map<String, dynamic>>? existingTargetDoc;
      try {
        final targetQuery = await _firestore
            .collection(_kAccessoriesStockCollection)
            .where('shopId', isEqualTo: newShopId)
            .where('category', isEqualTo: _fixedCategory)
            .where('productBrand', isEqualTo: freshData['productBrand'] ?? '')
            .where('productName', isEqualTo: freshData['productName'] ?? '')
            .where('status', isEqualTo: 'available')
            .limit(1)
            .get();
        if (targetQuery.docs.isNotEmpty) {
          existingTargetDoc = targetQuery.docs.first;
        }
      } catch (_) {
        existingTargetDoc = null;
      }

      final batch = _firestore.batch();
      final sourceRef = _firestore
          .collection(_kAccessoriesStockCollection)
          .doc(doc.id);

      if (transferQty == freshQty) {
        batch.update(sourceRef, {
          'shopId': newShopId,
          'shopName': newShopName,
          'transferredBy': user.email ?? user.name ?? 'Unknown',
          'transferredById': user.uid,
          'transferredFromShopId': sourceShopId,
          'transferredFromShopName': sourceShopName,
          'transferredAt': FieldValue.serverTimestamp(),
          'previousShopId': sourceShopId,
          'previousShopName': sourceShopName,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': user.email ?? user.name ?? 'Unknown',
        });
      } else {
        batch.update(sourceRef, {
          'quantity': freshQty - transferQty,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': user.email ?? user.name ?? 'Unknown',
        });

        if (existingTargetDoc != null) {
          final targetData = existingTargetDoc.data();
          final targetQty = (targetData['quantity'] as num?)?.toInt() ?? 0;
          batch.update(existingTargetDoc.reference, {
            'quantity': targetQty + transferQty,
            'lastUpdatedAt': FieldValue.serverTimestamp(),
            'lastUpdatedBy': user.email ?? user.name ?? 'Unknown',
            'transferredFromShopId': sourceShopId,
            'transferredFromShopName': sourceShopName,
            'transferredAt': FieldValue.serverTimestamp(),
          });
        } else {
          final newRef = _firestore
              .collection(_kAccessoriesStockCollection)
              .doc();
          batch.set(newRef, {
            'category': _fixedCategory,
            'productBrand': freshData['productBrand'] ?? '',
            'productName': freshData['productName'] ?? '',
            'modelName':
                freshData['modelName'] ?? freshData['productName'] ?? '',
            'productPrice': freshData['productPrice'] ?? 0,
            'purchaseRate': freshData['purchaseRate'] ?? 0,
            'purchaseInvoiceNo': freshData['purchaseInvoiceNo'] ?? '',
            'quantity': transferQty,
            'shopId': newShopId,
            'shopName': newShopName,
            'uploadedBy': user.email ?? user.name ?? 'Unknown',
            'uploadedById': user.uid,
            'uploadedAt': FieldValue.serverTimestamp(),
            'status': 'available',
            'createdAt': FieldValue.serverTimestamp(),
            'transferredFromShopId': sourceShopId,
            'transferredFromShopName': sourceShopName,
            'transferredAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      _showSuccess('$transferQty unit(s) transferred to $newShopName');
      await _loadStockAndReturns();
    } catch (e) {
      _showError('Failed to transfer: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // =========================================================================
  // RETURN
  // =========================================================================
  Future<void> _returnStock(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final available = (data['quantity'] as num?)?.toInt() ?? 0;
    if (available <= 0) {
      _showError('This item is out of stock');
      return;
    }

    final qtyController = TextEditingController(text: '1');
    int tempQty = 1;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final valid = tempQty > 0 && tempQty <= available;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.assignment_return,
                  color: Colors.orange[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Return Accessory',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['productName'] ?? 'Item').toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Available: $available pcs',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity to Return',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final q = int.tryParse(v);
                    if (q != null) setS(() => tempQty = q);
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, size: 14, color: Colors.orange),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'This will remove the units from stock and create a return record.',
                          style: TextStyle(fontSize: 10, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: valid ? () => Navigator.of(ctx).pop(true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Return'),
              ),
            ],
          );
        },
      ),
    );

    qtyController.dispose();
    if (result != true) return;

    setState(() => _isProcessing = true);
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        _showError('User not authenticated');
        return;
      }

      final stockRef = _firestore
          .collection(_kAccessoriesStockCollection)
          .doc(doc.id);

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(stockRef);
        if (!snap.exists) throw Exception('Stock record not found');
        final fresh = snap.data() as Map<String, dynamic>;
        final freshQty = (fresh['quantity'] as num?)?.toInt() ?? 0;
        if (freshQty < tempQty) {
          throw Exception('Only $freshQty available');
        }

        final returnRef = _firestore
            .collection(_kAccessoriesReturnCollection)
            .doc();
        tx.set(returnRef, {
          'modelId': doc.id,
          'category': _fixedCategory,
          'productBrand': data['productBrand'] ?? '',
          'productName': data['productName'] ?? '',
          'productPrice': data['productPrice'] ?? 0,
          'purchaseRate': data['purchaseRate'] ?? 0,
          'purchaseInvoiceNo': data['purchaseInvoiceNo'] ?? '',
          'quantity': tempQty,
          'originalShopId': data['shopId'] ?? '',
          'originalShopName': data['shopName'] ?? '',
          'returnedBy': user.email ?? user.name ?? 'Unknown',
          'returnedById': user.uid,
          'returnedAt': FieldValue.serverTimestamp(),
          'reason': 'returned_to_inventory',
          'status': 'returned',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (tempQty == freshQty) {
          tx.delete(stockRef);
        } else {
          tx.update(stockRef, {
            'quantity': freshQty - tempQty,
            'lastUpdatedAt': FieldValue.serverTimestamp(),
            'lastUpdatedBy': user.email ?? user.name ?? 'Unknown',
          });
        }
      });

      _showSuccess('$tempQty unit(s) returned successfully');
      await _loadStockAndReturns();
    } catch (e) {
      _showError('Failed to return: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

// =========================================================================
// STOCK CARD
// =========================================================================
class _AccessoryStockCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final _StockTab tab;
  final bool busy;
  final VoidCallback? onSell;
  final VoidCallback? onTransfer;
  final VoidCallback? onReturn;

  const _AccessoryStockCard({
    required this.doc,
    required this.tab,
    required this.busy,
    this.onSell,
    this.onTransfer,
    this.onReturn,
  });

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('dd MMM yyyy').format(ts.toDate());
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final m = doc.data() as Map<String, dynamic>;
    final name = (m['productName'] ?? 'Unknown').toString();
    final brand = (m['productBrand'] ?? '').toString();
    final invoice = (m['purchaseInvoiceNo'] ?? '').toString();
    final qty = (m['quantity'] as num?)?.toInt() ?? 0;
    final saleRate = (m['productPrice'] as num?)?.toDouble() ?? 0.0;

    final MaterialColor badgeColor = switch (tab) {
      _StockTab.available => Colors.green,
      _StockTab.sold => Colors.orange,
      _StockTab.returned => Colors.red,
    };

    final String badgeText = switch (tab) {
      _StockTab.available => '$qty pcs',
      _StockTab.sold => 'SOLD',
      _StockTab.returned => 'RETURN',
    };

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: badgeColor[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.headphones,
                    size: 22,
                    color: badgeColor[700],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (brand.isNotEmpty)
                        Text(
                          brand,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (invoice.isNotEmpty)
                        Text(
                          'Invoice: $invoice',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    '₹${saleRate.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.person, size: 10, color: Colors.grey[500]),
                const SizedBox(width: 3),
                Text(
                  _formatDate(m['uploadedAt'] ?? m['createdAt']),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
            if (tab == _StockTab.available &&
                (onSell != null || onTransfer != null || onReturn != null)) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onSell != null)
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: busy ? null : onSell,
                          icon: const Icon(Icons.sell, size: 14),
                          label: const Text(
                            'Sell',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (onTransfer != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: busy ? null : onTransfer,
                          icon: const Icon(Icons.swap_horiz, size: 14),
                          label: const Text(
                            'Transfer',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (onReturn != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: busy ? null : onReturn,
                          icon: const Icon(Icons.assignment_return, size: 14),
                          label: const Text(
                            'Return',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// RETURNED CARD
// =========================================================================
class _AccessoryReturnCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;

  const _AccessoryReturnCard({required this.doc});

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('dd MMM yyyy').format(ts.toDate());
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final m = doc.data() as Map<String, dynamic>;
    final name = (m['productName'] ?? 'Unknown').toString();
    final brand = (m['productBrand'] ?? '').toString();
    final qty = (m['quantity'] as num?)?.toInt() ?? 0;
    final price = (m['productPrice'] as num?)?.toDouble() ?? 0.0;
    final returnedBy = (m['returnedBy'] ?? '').toString();
    final shopName = (m['originalShopName'] ?? '').toString();
    final reason = (m['reason'] ?? '').toString();

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.assignment_return,
                    size: 22,
                    color: Colors.orange[800],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (brand.isNotEmpty)
                        Text(
                          brand,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Qty: $qty',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '₹${price.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 6),
            _row(
              Icons.assignment_return,
              'Returned: ${_formatDate(m['returnedAt'])}',
            ),
            if (returnedBy.isNotEmpty) _row(Icons.person, 'By: $returnedBy'),
            if (shopName.isNotEmpty) _row(Icons.store, 'Shop: $shopName'),
            if (reason.isNotEmpty)
              _row(
                Icons.info_outline,
                'Reason: ${reason.replaceAll('_', ' ')}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 10, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
