// lib/screens/admin/inventory/brand_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Create a typedef for the formatNumber function
typedef FormatNumberFunction = String Function(double number);

class BrandDetailsScreen extends StatefulWidget {
  final String? shopId;
  final String? shopName;
  final FormatNumberFunction formatNumber;

  const BrandDetailsScreen({
    Key? key,
    this.shopId,
    this.shopName,
    required this.formatNumber,
  }) : super(key: key);

  @override
  _BrandDetailsScreenState createState() => _BrandDetailsScreenState();
}

class _BrandDetailsScreenState extends State<BrandDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference phoneStockCollection = FirebaseFirestore.instance
      .collection('phoneStock');

  bool _isLoading = true;
  List<Map<String, dynamic>> _allStockItems = [];
  Map<String, Map<String, dynamic>> _brandSummary = {};
  Map<String, Map<String, Map<String, dynamic>>> _shopWiseBrandSummary = {};
  double _totalStockValue = 0;
  int _totalStockCount = 0;

  // Green color scheme matching the dashboard
  final Color primaryGreen = Color(0xFF0A4D2E);
  final Color secondaryGreen = Color(0xFF1A7D4A);
  final Color lightGreen = Color(0xFFE8F5E9);
  final Color cardGreen = Color(0xFF2E7D32);
  final Color accentColor = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _fetchPhoneStock();
  }

  Future<void> _fetchPhoneStock() async {
    try {
      setState(() {
        _isLoading = true;
        _allStockItems.clear();
        _brandSummary.clear();
        _shopWiseBrandSummary.clear();
        _totalStockValue = 0;
        _totalStockCount = 0;
      });

      Query query = phoneStockCollection;

      // Filter by shop if specified
      if (widget.shopId != null && widget.shopId!.isNotEmpty) {
        query = query.where('shopId', isEqualTo: widget.shopId);
      }

      final snapshot = await query.get();

      for (var doc in snapshot.docs) {
        // Convert the document data to Map<String, dynamic>
        final Map<String, dynamic> data = _convertToMap(doc.data());

        // Only include available stock
        if (data['status'] == 'available') {
          final brand = data['productBrand']?.toString() ?? 'Unknown Brand';
          final model = data['productName']?.toString() ?? 'Unknown Model';
          final price = _parseDouble(data['productPrice']);
          final imei = data['imei']?.toString() ?? 'N/A';
          final shopName = data['shopName']?.toString() ?? 'Unknown Shop';
          final shopId = data['shopId']?.toString() ?? '';

          // Parse date
          DateTime uploadedAt = DateTime.now();
          if (data['uploadedAt'] is Timestamp) {
            uploadedAt = (data['uploadedAt'] as Timestamp).toDate();
          } else if (data['createdAt'] is Timestamp) {
            uploadedAt = (data['createdAt'] as Timestamp).toDate();
          }

          final stockItem = {
            'id': doc.id,
            'brand': brand,
            'model': model,
            'price': price,
            'imei': imei,
            'shopName': shopName,
            'shopId': shopId,
            'uploadedAt': uploadedAt,
            'uploadedBy': data['uploadedBy']?.toString() ?? 'Unknown',
            'status': data['status']?.toString() ?? 'available',
          };

          _allStockItems.add(stockItem);

          // Update brand summary
          if (!_brandSummary.containsKey(brand)) {
            _brandSummary[brand] = {
              'count': 0,
              'totalValue': 0.0,
              'items': <Map<String, dynamic>>[],
              'shopDistribution': <String, Map<String, dynamic>>{},
            };
          }

          _brandSummary[brand]!['count'] =
              (_brandSummary[brand]!['count'] as int) + 1;
          _brandSummary[brand]!['totalValue'] =
              (_brandSummary[brand]!['totalValue'] as double) + price;
          (_brandSummary[brand]!['items'] as List<Map<String, dynamic>>).add(
            stockItem,
          );

          // Update shop distribution
          final shopDist =
              _brandSummary[brand]!['shopDistribution']
                  as Map<String, Map<String, dynamic>>;
          if (!shopDist.containsKey(shopName)) {
            shopDist[shopName] = {'count': 0, 'totalValue': 0.0};
          }
          shopDist[shopName]!['count'] =
              (shopDist[shopName]!['count'] as int) + 1;
          shopDist[shopName]!['totalValue'] =
              (shopDist[shopName]!['totalValue'] as double) + price;

          // Update shop-wise brand summary
          if (!_shopWiseBrandSummary.containsKey(shopName)) {
            _shopWiseBrandSummary[shopName] = {};
          }
          if (!_shopWiseBrandSummary[shopName]!.containsKey(brand)) {
            _shopWiseBrandSummary[shopName]![brand] = {
              'count': 0,
              'totalValue': 0.0,
            };
          }
          _shopWiseBrandSummary[shopName]![brand]!['count'] =
              (_shopWiseBrandSummary[shopName]![brand]!['count'] as int) + 1;
          _shopWiseBrandSummary[shopName]![brand]!['totalValue'] =
              (_shopWiseBrandSummary[shopName]![brand]!['totalValue']
                  as double) +
              price;

          // Update totals
          _totalStockCount++;
          _totalStockValue += price;
        }
      }

      // Sort brands by total value (descending)
      final sortedBrands = _brandSummary.entries.toList()
        ..sort(
          (a, b) => (b.value['totalValue'] as double).compareTo(
            a.value['totalValue'] as double,
          ),
        );

      final sortedMap = Map<String, Map<String, dynamic>>.fromEntries(
        sortedBrands,
      );
      _brandSummary = sortedMap;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching phone stock: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading brand details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper function to convert dynamic data to Map<String, dynamic>
  Map<String, dynamic> _convertToMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      // Convert Map<dynamic, dynamic> to Map<String, dynamic>
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  // Helper function to parse double safely
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: secondaryGreen, strokeWidth: 3),
          SizedBox(height: 16),
          Text(
            'Loading brand details...',
            style: TextStyle(
              color: primaryGreen,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryGreen, secondaryGreen],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.shopName != null ? '${widget.shopName}' : 'All Shops',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Brand-wise Stock Summary',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStat(
                'Total Brands',
                '${_brandSummary.length}',
                Icons.category,
              ),
              _buildSummaryStat(
                'Total Stock',
                '$_totalStockCount',
                Icons.inventory,
              ),
              _buildSummaryStat(
                'Total Value',
                '₹${widget.formatNumber(_totalStockValue)}',
                Icons.currency_rupee,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildShopWiseBrandSummary() {
    if (_shopWiseBrandSummary.isEmpty) {
      return SizedBox();
    }

    return Card(
      margin: EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(Icons.store, color: primaryGreen),
        title: Text(
          'Shop-wise Brand Summary',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: primaryGreen,
          ),
        ),
        subtitle: Text(
          '${_shopWiseBrandSummary.length} shops',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _shopWiseBrandSummary.entries.map((shopEntry) {
                final shopName = shopEntry.key;
                final brands = shopEntry.value;
                final brandsList = brands.entries.toList()
                  ..sort(
                    (a, b) => (b.value['totalValue'] as double).compareTo(
                      a.value['totalValue'] as double,
                    ),
                  );

                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.store_outlined,
                            size: 14,
                            color: primaryGreen,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              shopName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryGreen,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: lightGreen,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${brands.length} brands',
                              style: TextStyle(
                                fontSize: 10,
                                color: secondaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      // Flexible height container that adapts to content
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: 200, // Maximum height
                          minHeight: 50, // Minimum height
                        ),
                        child: SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: brandsList.map((brandEntry) {
                              final brand = brandEntry.key;
                              final data = brandEntry.value;
                              final count = data['count'] as int;
                              final value = data['totalValue'] as double;

                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _getBrandColor(brand),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        brand,
                                        style: TextStyle(fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '₹${widget.formatNumber(value)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: secondaryGreen,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandList() {
    if (_brandSummary.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, size: 48, color: Colors.grey[400]),
            SizedBox(height: 12),
            Text(
              'No stock available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              widget.shopName != null
                  ? 'No stock found for ${widget.shopName}'
                  : 'No stock found in any shop',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.all(8),
      itemCount: _brandSummary.length,
      itemBuilder: (context, index) {
        final brand = _brandSummary.keys.elementAt(index);
        final data = _brandSummary[brand]!;
        final count = data['count'] as int;
        final totalValue = data['totalValue'] as double;
        final shopDistribution =
            data['shopDistribution'] as Map<String, Map<String, dynamic>>;
        final shopDistributionList = shopDistribution.entries.toList()
          ..sort(
            (a, b) => (b.value['totalValue'] as double).compareTo(
              a.value['totalValue'] as double,
            ),
          );

        return Card(
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: EdgeInsets.symmetric(horizontal: 12),
            leading: CircleAvatar(
              backgroundColor: _getBrandColor(brand),
              radius: 16,
              child: Text(
                brand.substring(0, 1),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            title: Text(
              brand,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '$count items',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            trailing: Text(
              '₹${widget.formatNumber(totalValue)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: secondaryGreen,
              ),
            ),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand summary in compact form
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDetailItem('Total Items', '$count'),
                        _buildDetailItem(
                          'Total Value',
                          '₹${widget.formatNumber(totalValue)}',
                        ),
                      ],
                    ),
                    SizedBox(height: 12),

                    // Shop distribution
                    Row(
                      children: [
                        Text(
                          'Shop Distribution',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryGreen,
                          ),
                        ),
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: lightGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${shopDistributionList.length} shops',
                            style: TextStyle(
                              fontSize: 9,
                              color: secondaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),

                    // Flexible height container for shop distribution
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 150, // Maximum height
                        minHeight: 40, // Minimum height
                      ),
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: shopDistributionList.map((entry) {
                            final shopName = entry.key;
                            final shopData = entry.value;
                            final shopCount = shopData['count'] as int;
                            final shopValue = shopData['totalValue'] as double;

                            return Container(
                              margin: EdgeInsets.only(bottom: 4),
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      shopName,
                                      style: TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: lightGreen,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$shopCount',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: secondaryGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '₹${widget.formatNumber(shopValue)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    SizedBox(height: 12),

                    // View all items button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          _showBrandItemsDialog(
                            brand,
                            data['items'] as List<Map<String, dynamic>>,
                          );
                        },
                        icon: Icon(Icons.list, size: 14, color: secondaryGreen),
                        label: Text(
                          'View All Items',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: lightGreen,
                          padding: EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primaryGreen,
          ),
        ),
      ],
    );
  }

  void _showBrandItemsDialog(String brand, List<Map<String, dynamic>> items) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 18,
                        child: Text(
                          brand.substring(0, 1),
                          style: TextStyle(
                            color: primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              brand,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${items.length} items',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '₹${widget.formatNumber(items.fold(0.0, (sum, item) => sum + (item['price'] as double)))}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content with flexible height
                Expanded(
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: items.map((item) {
                          return Container(
                            margin: EdgeInsets.only(bottom: 6),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['model'] as String,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '₹${widget.formatNumber(item['price'] as double)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: secondaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _buildInfoChip(
                                      Icons.store,
                                      item['shopName'] as String,
                                    ),
                                    _buildInfoChip(
                                      Icons.confirmation_number,
                                      'IMEI: ${(item['imei'] as String).substring(0, 8)}...',
                                    ),
                                    _buildInfoChip(
                                      Icons.calendar_today,
                                      DateFormat(
                                        'dd/MM/yy',
                                      ).format(item['uploadedAt'] as DateTime),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // Footer
                Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: lightGreen,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.grey[600]),
          SizedBox(width: 2),
          Text(text, style: TextStyle(fontSize: 9, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Color _getBrandColor(String brand) {
    // Assign colors based on brand name
    final brandColors = {
      'Samsung': Color(0xFF1428A0),
      'Apple': Color(0xFFA2AAAD),
      'Oppo': Color(0xFF0082CB),
      'Vivo': Color(0xFF415FFF),
      'OnePlus': Color(0xFFF5010C),
      'Xiaomi': Color(0xFFFF6900),
      'Realme': Color(0xFFFFC20E),
      'Nokia': Color(0xFF124191),
      'Motorola': Color(0xFFE1000F),
      'Google': Color(0xFF4285F4),
    };

    return brandColors[brand] ?? _generateColorFromString(brand);
  }

  Color _generateColorFromString(String input) {
    // Generate a consistent color from string hash
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = input.codeUnitAt(i) + ((hash << 5) - hash);
    }

    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.7, 0.8).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        title: Text('Brand Details'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 20),
            onPressed: _fetchPhoneStock,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingScreen()
          : LayoutBuilder(
              builder: (context, constraints) {
                return RefreshIndicator(
                  onRefresh: _fetchPhoneStock,
                  color: secondaryGreen,
                  backgroundColor: lightGreen,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSummaryHeader(),
                          if (widget.shopId == null &&
                              _shopWiseBrandSummary.isNotEmpty)
                            _buildShopWiseBrandSummary(),
                          _buildBrandList(),
                          // Add padding at bottom for better scrolling
                          SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
