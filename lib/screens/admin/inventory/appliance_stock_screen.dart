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

        for (var doc in filteredDocs) {
          final data = doc.data() as Map<String, dynamic>;
          int quantity = (data['quantity'] ?? 0).toInt();
          double price = (data['productPrice'] ?? 0).toDouble();

          totalItems += quantity;
          totalValue += (price * quantity);

          if (data['status'] == 'available') {
            availableItems += quantity;
            availableValue += (price * quantity);
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
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.left,
              decoration: InputDecoration(
                hintText: 'Search by Product Name, Brand...',
                hintStyle: const TextStyle(fontSize: 12),
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
                    style: TextStyle(fontSize: 12, color: primaryGreen),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          'All Status',
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'available',
                        child: Text(
                          'Available',
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'sold',
                        child: Text(
                          'Sold',
                          style: TextStyle(fontSize: 12),
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
                    style: TextStyle(fontSize: 12, color: primaryGreen),
                    hint: const Text(
                      'All Shops',
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.left,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'All Shops',
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      ...widget.shops.map((shop) {
                        return DropdownMenuItem<String>(
                          value: shop['id'] as String?,
                          child: Text(
                            shop['name'] as String? ?? 'Unknown',
                            style: const TextStyle(fontSize: 12),
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
                          style: TextStyle(fontSize: 12, color: primaryGreen),
                          hint: const Text(
                            'All Brands',
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.left,
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                'All Brands',
                                style: TextStyle(fontSize: 12),
                                textAlign: TextAlign.left,
                              ),
                            ),
                            ..._brands.map((brand) {
                              return DropdownMenuItem<String>(
                                value: brand,
                                child: Text(
                                  brand,
                                  style: const TextStyle(fontSize: 12),
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
              // Header
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
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
