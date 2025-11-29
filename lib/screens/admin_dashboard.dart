import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Color scheme
  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _secondaryColor = const Color(0xFF64748B);
  final Color _accentColor = const Color(0xFF10B981);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _infoColor = const Color(0xFF8B5CF6);
  final Color _backgroundColor = const Color(0xFFF8FAFC);

  // Time period selections
  String _selectedPeriod = 'Today';
  final List<String> _periods = [
    'Today',
    'Yesterday',
    'This Week',
    'This Month',
    'Last Month',
    'This Year',
    'Custom',
  ];

  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Data variables
  Map<String, dynamic> _overallStats = {};
  List<Map<String, dynamic>> _shopDetails = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // Helper method to convert dynamic map to Map<String, dynamic>
  Map<String, dynamic> _convertDynamicMap(Map<dynamic, dynamic> dynamicMap) {
    final Map<String, dynamic> convertedMap = {};
    dynamicMap.forEach((key, value) {
      convertedMap[key.toString()] = value;
    });
    return convertedMap;
  }

  // Safe document data conversion
  Map<String, dynamic> _safeConvertDocumentData(dynamic docData) {
    if (docData == null) return {};
    if (docData is Map<String, dynamic>) return docData;
    if (docData is Map<dynamic, dynamic>) return _convertDynamicMap(docData);
    return {};
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    await _loadOverallStats();
    await _loadShopDetails();

    setState(() {
      _isLoading = false;
    });
  }

  // Helper methods for type conversion
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is bool) return value ? 1 : 0;
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is bool) return value ? 1.0 : 0.0;
    return 0.0;
  }

  // Custom date formatting
  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatDateLong(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _loadOverallStats() async {
    try {
      DateTime startDate = _getStartDateForPeriod(_selectedPeriod);
      DateTime endDate = _getEndDateForPeriod(_selectedPeriod);

      QuerySnapshot salesSnapshot = await _firestore
          .collection('sales')
          .where('saleDate', isGreaterThanOrEqualTo: startDate)
          .where('saleDate', isLessThanOrEqualTo: endDate)
          .get();

      double totalSales = 0;
      double totalService = 0;
      double totalAmount = 0;
      int totalPhonesSold = 0;
      double totalPhoneValue = 0;
      int totalTransactions = salesSnapshot.docs.length;
      Set<String> uniqueShops = {};

      for (var doc in salesSnapshot.docs) {
        // Safe type conversion
        var saleData = _safeConvertDocumentData(doc.data());

        totalSales += _toDouble(saleData['saleAmount']);
        totalService += _toDouble(saleData['serviceAmount']);
        totalAmount += _toDouble(saleData['totalAmount']);
        totalPhonesSold += _toInt(saleData['totalPhonesSold']);
        totalPhoneValue += _toDouble(saleData['totalPhoneSalesValue']);

        String shopId = saleData['shopId']?.toString() ?? 'unknown';
        uniqueShops.add(shopId);
      }

      double averageSale = totalTransactions > 0
          ? totalAmount / totalTransactions
          : 0;

      setState(() {
        _overallStats = {
          'totalSales': totalSales,
          'totalService': totalService,
          'totalAmount': totalAmount,
          'totalPhonesSold': totalPhonesSold,
          'totalPhoneValue': totalPhoneValue,
          'totalTransactions': totalTransactions,
          'uniqueShops': uniqueShops.length,
          'averageSale': averageSale,
        };
      });
    } catch (e) {
      print('Error loading overall stats: $e');
    }
  }

  Future<void> _loadShopDetails() async {
    try {
      DateTime startDate = _getStartDateForPeriod(_selectedPeriod);
      DateTime endDate = _getEndDateForPeriod(_selectedPeriod);

      QuerySnapshot salesSnapshot = await _firestore
          .collection('sales')
          .where('saleDate', isGreaterThanOrEqualTo: startDate)
          .where('saleDate', isLessThanOrEqualTo: endDate)
          .get();

      Map<String, Map<String, dynamic>> shopData = {};

      for (var doc in salesSnapshot.docs) {
        // Safe type conversion
        var saleData = _safeConvertDocumentData(doc.data());

        String shopId = saleData['shopId']?.toString() ?? 'unknown';
        String shopName = saleData['shopName']?.toString() ?? 'Unknown Shop';

        if (!shopData.containsKey(shopId)) {
          shopData[shopId] = {
            'shopName': shopName,
            'shopId': shopId,
            'totalSales': 0.0,
            'totalService': 0.0,
            'totalAmount': 0.0,
            'totalPhonesSold': 0,
            'totalPhoneValue': 0.0,
            'transactionCount': 0,
            'phoneBrands': <String, dynamic>{},
          };
        }

        shopData[shopId]!['totalSales'] += _toDouble(saleData['saleAmount']);
        shopData[shopId]!['totalService'] += _toDouble(
          saleData['serviceAmount'],
        );
        shopData[shopId]!['totalAmount'] += _toDouble(saleData['totalAmount']);
        shopData[shopId]!['totalPhonesSold'] += _toInt(
          saleData['totalPhonesSold'],
        );
        shopData[shopId]!['totalPhoneValue'] += _toDouble(
          saleData['totalPhoneSalesValue'],
        );
        shopData[shopId]!['transactionCount'] += 1;

        // Process phone brands data with safe type conversion
        var phoneSales = saleData['phoneSales'];
        if (phoneSales != null) {
          Map<String, dynamic> convertedPhoneSales = {};

          if (phoneSales is Map<dynamic, dynamic>) {
            convertedPhoneSales = _convertDynamicMap(phoneSales);
          } else if (phoneSales is Map<String, dynamic>) {
            convertedPhoneSales = phoneSales;
          }

          convertedPhoneSales.forEach((brand, brandData) {
            if (brandData != null) {
              Map<String, dynamic> convertedBrandData = {};

              if (brandData is Map<dynamic, dynamic>) {
                convertedBrandData = _convertDynamicMap(brandData);
              } else if (brandData is Map<String, dynamic>) {
                convertedBrandData = brandData;
              }

              if (!shopData[shopId]!['phoneBrands'].containsKey(brand)) {
                shopData[shopId]!['phoneBrands'][brand] = {
                  'quantity': 0,
                  'totalValue': 0.0,
                };
              }
              shopData[shopId]!['phoneBrands'][brand]['quantity'] += _toInt(
                convertedBrandData['quantity'],
              );
              shopData[shopId]!['phoneBrands'][brand]['totalValue'] +=
                  _toDouble(convertedBrandData['totalValue']);
            }
          });
        }
      }

      // Convert to list and sort by total amount
      List<Map<String, dynamic>> shopList = shopData.values.toList();
      shopList.sort(
        (a, b) =>
            (b['totalAmount'] as double).compareTo(a['totalAmount'] as double),
      );

      setState(() {
        _shopDetails = shopList;
      });
    } catch (e) {
      print('Error loading shop details: $e');
    }
  }

  DateTime _getStartDateForPeriod(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'Yesterday':
        return DateTime(now.year, now.month, now.day - 1);
      case 'This Week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      case 'Last Month':
        final lastMonth = now.month == 1
            ? DateTime(now.year - 1, 12, 1)
            : DateTime(now.year, now.month - 1, 1);
        return lastMonth;
      case 'This Year':
        return DateTime(now.year, 1, 1);
      case 'Custom':
        return _customStartDate ?? DateTime(now.year, now.month, now.day);
      default:
        return DateTime(now.year, now.month, now.day);
    }
  }

  DateTime _getEndDateForPeriod(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'Today':
      case 'Yesterday':
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case 'This Week':
        return DateTime(
          now.year,
          now.month,
          now.day + (7 - now.weekday),
          23,
          59,
          59,
        );
      case 'This Month':
        return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case 'Last Month':
        final lastMonth = now.month == 1
            ? DateTime(now.year - 1, 12, 31, 23, 59, 59)
            : DateTime(now.year, now.month, 0, 23, 59, 59);
        return lastMonth;
      case 'This Year':
        return DateTime(now.year, 12, 31, 23, 59, 59);
      case 'Custom':
        return _customEndDate ??
            DateTime(now.year, now.month, now.day, 23, 59, 59);
      default:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  Future<void> _selectCustomDateRange() async {
    final DateTime? pickedStart = await showDatePicker(
      context: context,
      initialDate: _customStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedStart != null) {
      final DateTime? pickedEnd = await showDatePicker(
        context: context,
        initialDate: _customEndDate ?? pickedStart,
        firstDate: pickedStart,
        lastDate: DateTime.now(),
      );

      if (pickedEnd != null) {
        setState(() {
          _customStartDate = pickedStart;
          _customEndDate = pickedEnd;
          _selectedPeriod = 'Custom';
        });
        await _loadDashboardData();
      }
    }
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Report Period',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const Spacer(),
              if (_selectedPeriod == 'Custom' &&
                  _customStartDate != null &&
                  _customEndDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_formatDateLong(_customStartDate!)} - ${_formatDateLong(_customEndDate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _periods.map((period) {
                final isSelected = period == _selectedPeriod;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (period == 'Custom') {
                        await _selectCustomDateRange();
                      } else {
                        setState(() {
                          _selectedPeriod = period;
                        });
                        await _loadDashboardData();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected
                          ? _primaryColor
                          : Colors.white,
                      foregroundColor: isSelected
                          ? Colors.white
                          : _secondaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? _primaryColor
                              : _secondaryColor.withOpacity(0.3),
                        ),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: Text(period),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStats() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(Icons.bar_chart, color: _primaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'All Shops Summary - $_selectedPeriod',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            children: [
              _buildStatCard(
                'Total Revenue',
                '₹${(_overallStats['totalAmount'] ?? 0).toStringAsFixed(0)}',
                Icons.attach_money,
                _accentColor,
                '${_overallStats['totalTransactions'] ?? 0} transactions',
              ),
              _buildStatCard(
                'Product Sales',
                '₹${(_overallStats['totalSales'] ?? 0).toStringAsFixed(0)}',
                Icons.shopping_bag,
                _primaryColor,
                'Product revenue',
              ),
              _buildStatCard(
                'Service Revenue',
                '₹${(_overallStats['totalService'] ?? 0).toStringAsFixed(0)}',
                Icons.build,
                _warningColor,
                'Service income',
              ),
              _buildStatCard(
                'Phones Sold',
                '${_overallStats['totalPhonesSold'] ?? 0}',
                Icons.phone_android,
                _infoColor,
                '₹${(_overallStats['totalPhoneValue'] ?? 0).toStringAsFixed(0)} total value',
              ),
              _buildStatCard(
                'Active Shops',
                '${_overallStats['uniqueShops'] ?? 0}',
                Icons.store,
                Colors.green,
                'Participating shops',
              ),
              _buildStatCard(
                'Avg. Sale',
                '₹${(_overallStats['averageSale'] ?? 0).toStringAsFixed(0)}',
                Icons.trending_up,
                Colors.purple,
                'Per transaction',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: _secondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: _secondaryColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopDetails() {
    if (_shopDetails.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.store,
                size: 64,
                color: _secondaryColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No shop data available',
                style: TextStyle(fontSize: 16, color: _secondaryColor),
              ),
              const SizedBox(height: 8),
              Text(
                'for $_selectedPeriod',
                style: TextStyle(
                  fontSize: 14,
                  color: _secondaryColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront, color: _primaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Shop Performance Details ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
            Text(
              '(${_selectedPeriod})',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            ..._shopDetails.asMap().entries.map((entry) {
              final index = entry.key;
              final shop = entry.value;
              return _buildShopCard(shop, index);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop, int index) {
    bool isExpanded = shop['_isExpanded'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Shop header
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            title: Text(
              shop['shopName']?.toString() ?? 'Unknown Shop',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${shop['transactionCount']} transactions • ₹${(shop['totalAmount'] as double).toStringAsFixed(0)} total',
              style: TextStyle(color: _secondaryColor),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: _primaryColor,
            ),
            onTap: () {
              setState(() {
                shop['_isExpanded'] = !isExpanded;
              });
            },
          ),

          // Expanded details
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Financial Summary
                  _buildShopDetailSection(
                    'Financial Summary',
                    Icons.attach_money,
                    _accentColor,
                    [
                      _buildDetailRow(
                        'Product Sales',
                        '₹${(shop['totalSales'] as double).toStringAsFixed(0)}',
                      ),
                      _buildDetailRow(
                        'Service Revenue',
                        '₹${(shop['totalService'] as double).toStringAsFixed(0)}',
                      ),
                      _buildDetailRow(
                        'Total Revenue',
                        '₹${(shop['totalAmount'] as double).toStringAsFixed(0)}',
                        isBold: true,
                      ),
                      _buildDetailRow(
                        'Transactions',
                        '${shop['transactionCount']}',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Phone Sales
                  _buildShopDetailSection(
                    'Phone Sales',
                    Icons.phone_android,
                    _infoColor,
                    [
                      _buildDetailRow(
                        'Phones Sold',
                        '${shop['totalPhonesSold']} units',
                      ),
                      _buildDetailRow(
                        'Phone Sales Value',
                        '₹${(shop['totalPhoneValue'] as double).toStringAsFixed(0)}',
                      ),
                      _buildDetailRow(
                        'Avg. Phone Price',
                        '₹${shop['totalPhonesSold'] > 0 ? ((shop['totalPhoneValue'] as double) / (shop['totalPhonesSold'] as int)).toStringAsFixed(0) : '0'}',
                      ),
                    ],
                  ),

                  // Phone Brands Breakdown
                  if (shop['phoneBrands'] != null &&
                      (shop['phoneBrands'] as Map).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildPhoneBrandsSection(
                      shop['phoneBrands'] as Map<String, dynamic>,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShopDetailSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _secondaryColor, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: _secondaryColor,
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneBrandsSection(Map<String, dynamic> phoneBrands) {
    // Sort brands by total value
    var sortedBrands = phoneBrands.entries.toList()
      ..sort((a, b) {
        final valueA =
            (a.value as Map<String, dynamic>)['totalValue'] as double;
        final valueB =
            (b.value as Map<String, dynamic>)['totalValue'] as double;
        return valueB.compareTo(valueA);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.phone_iphone, color: _warningColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'Phone Brands Breakdown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _warningColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...sortedBrands.take(5).map((entry) {
          final brand = entry.key;
          final data = entry.value as Map<String, dynamic>;
          return _buildBrandRow(brand, data);
        }).toList(),
        if (sortedBrands.length > 5) ...[
          const SizedBox(height: 8),
          Text(
            '+ ${sortedBrands.length - 5} more brands',
            style: TextStyle(
              color: _secondaryColor.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBrandRow(String brand, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getBrandColor(brand).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(
                Icons.phone_android,
                size: 16,
                color: _getBrandColor(brand),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getBrandDisplayName(brand),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${data['quantity']} units',
            style: TextStyle(color: _secondaryColor, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Text(
            '₹${(data['totalValue'] as double).toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Color _getBrandColor(String brand) {
    final colors = {
      'iphone': const Color(0xFFA2AAAD),
      'samsung': const Color(0xFF1428A0),
      'vivo': const Color(0xFF415FFF),
      'oppo': const Color(0xFF46C1BE),
      'redmi': const Color(0xFFFF6900),
      'realme': const Color(0xFFFFC915),
      'iqoo': const Color(0xFF5600FF),
      'moto': const Color(0xFFE10032),
      'nokia': const Color(0xFF124191),
      'infinix': const Color(0xFF000000),
      'itel': const Color(0xFFFF0000),
    };
    return colors[brand] ?? _primaryColor;
  }

  String _getBrandDisplayName(String brand) {
    final names = {
      'iphone': 'iPhone',
      'samsung': 'Samsung',
      'vivo': 'Vivo',
      'oppo': 'Oppo',
      'redmi': 'Redmi',
      'realme': 'Realme',
      'iqoo': 'iQOO',
      'moto': 'Motorola',
      'nokia': 'Nokia',
      'infinix': 'Infinix',
      'itel': 'Itel',
    };
    return names[brand] ?? brand.toUpperCase();
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _primaryColor),
          const SizedBox(height: 16),
          Text(
            'Loading dashboard data...',
            style: TextStyle(fontSize: 16, color: _secondaryColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Sales Dashboard'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period Selector
                  _buildPeriodSelector(),

                  // Overall Stats
                  _buildOverallStats(),

                  // Shop Details
                  _buildShopDetails(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
