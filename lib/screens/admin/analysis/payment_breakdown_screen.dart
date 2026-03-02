import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/sale.dart';

class PaymentBreakdownScreen extends StatefulWidget {
  final List<Sale> allSales;
  final List<Map<String, dynamic>> shops;
  final String Function(double) formatNumber;

  const PaymentBreakdownScreen({
    super.key,
    required this.allSales,
    required this.shops,
    required this.formatNumber,
  });

  @override
  State<PaymentBreakdownScreen> createState() => _PaymentBreakdownScreenState();
}

class _PaymentBreakdownScreenState extends State<PaymentBreakdownScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedShop = 'All Shops';
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedDateRange = 'This Month';
  bool _showFilters = true;
  bool _isLoading = false;

  // Enhanced color palette
  final Color primaryGreen = Color(0xFF0A4D2E);
  final Color secondaryGreen = Color(0xFF1A7D4A);
  final Color accentGreen = Color(0xFF28A745);
  final Color lightGreen = Color(0xFFE8F5E9);
  final Color backgroundColor = Color(0xFFF5F8FA);
  final Color cardBackground = Colors.white;
  final Color gradientStart = Color(0xFFF8FBF8);
  final Color gradientEnd = Color(0xFFF0F7F0);

  // Payment method colors
  final Color gpayColor = Color(0xFF4285F4);
  final Color cashColor = Color(0xFF2E7D32);
  final Color cardColor = Color(0xFF7B1FA2);
  final Color creditColor = Color(0xFFFF6F00);
  final Color upiColor = Color(0xFF00BFA5);

  // Date range options
  final List<String> dateRanges = [
    'Today',
    'Yesterday',
    'This Month',
    'Last Month',
    'This Year',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _setDateRange('This Month');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setDateRange(String range) {
    setState(() {
      _selectedDateRange = range;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      switch (range) {
        case 'Today':
          _startDate = today;
          _endDate = today
              .add(Duration(days: 1))
              .subtract(Duration(seconds: 1));
          break;

        case 'Yesterday':
          _startDate = today.subtract(Duration(days: 1));
          _endDate = today.subtract(Duration(seconds: 1));
          break;

        case 'This Month':
          _startDate = DateTime(today.year, today.month, 1);
          _endDate = DateTime(today.year, today.month + 1, 0, 23, 59, 59);
          break;

        case 'Last Month':
          _startDate = DateTime(today.year, today.month - 1, 1);
          _endDate = DateTime(today.year, today.month, 0, 23, 59, 59);
          break;

        case 'This Year':
          _startDate = DateTime(today.year, 1, 1);
          _endDate = DateTime(today.year, 12, 31, 23, 59, 59);
          break;

        case 'Custom':
          if (_startDate == null || _endDate == null) {
            _startDate = today.subtract(Duration(days: 30));
            _endDate = today;
          }
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingIndicator()
          : Column(
              children: [
                if (_showFilters) _buildFilterSection(),
                _buildShopSelector(),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [gradientStart, gradientEnd],
                      ),
                    ),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAllCollectionsView(),
                        _buildPhoneSalesView(),
                        _buildBaseModelView(),
                        _buildSecondPhoneView(),
                        _buildAccessoriesView(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Breakdown',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14, // Reduced from 16
              color: Colors.white,
            ),
          ),
          Text(
            '${_getFilteredSales().length} transactions',
            style: TextStyle(
              fontSize: 10, // Reduced from 11
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(48),
        child: Container(
          color: primaryGreen,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ), // Reduced from 12
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Phone'),
              Tab(text: 'Base'),
              Tab(text: 'Second'),
              Tab(text: 'Accessories'),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showFilters ? Icons.filter_alt_off : Icons.filter_alt,
            size: 20,
          ), // Fixed size
          onPressed: () {
            setState(() {
              _showFilters = !_showFilters;
            });
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 20), // Fixed size
          onSelected: (value) {
            if (value == 'export') {
              _showExportOptions();
            } else if (value == 'refresh') {
              setState(() {});
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(
                    Icons.download,
                    size: 16,
                    color: primaryGreen,
                  ), // Reduced from 18
                  SizedBox(width: 6), // Reduced from 8
                  Text(
                    'Export Report',
                    style: TextStyle(fontSize: 13),
                  ), // Added font size
                ],
              ),
            ),
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(
                    Icons.refresh,
                    size: 16,
                    color: primaryGreen,
                  ), // Reduced from 18
                  SizedBox(width: 6), // Reduced from 8
                  Text(
                    'Refresh',
                    style: TextStyle(fontSize: 13),
                  ), // Added font size
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, // Reduced from 10
            offset: Offset(0, 2), // Reduced from 4
          ),
        ],
      ),
      child: Column(
        children: [
          // Date Range Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: dateRanges.map((range) {
                bool isSelected = _selectedDateRange == range;
                return Padding(
                  padding: EdgeInsets.only(right: 6), // Reduced from 8
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(
                      range,
                      style: TextStyle(
                        fontSize: 11, // Reduced from 12
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.white : primaryGreen,
                      ),
                    ),
                    selectedColor: primaryGreen,
                    checkmarkColor: Colors.white,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? primaryGreen : Colors.grey.shade300,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        _setDateRange(range);
                        if (range == 'Custom') {
                          _selectCustomDateRange();
                        }
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 10), // Reduced from 12
          // Custom Date Pickers (only show for Custom range)
          if (_selectedDateRange == 'Custom')
            Container(
              margin: EdgeInsets.only(bottom: 10), // Reduced from 12
              padding: EdgeInsets.all(10), // Reduced from 12
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10), // Reduced from 12
                border: Border.all(color: primaryGreen.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildDatePickerChip(
                      'From: ${_formatDate(_startDate)}',
                      Icons.calendar_today,
                      () => _selectDate(isStart: true),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6,
                    ), // Reduced from 8
                    child: Icon(
                      Icons.arrow_forward,
                      size: 14, // Reduced from 16
                      color: primaryGreen,
                    ),
                  ),
                  Expanded(
                    child: _buildDatePickerChip(
                      'To: ${_formatDate(_endDate)}',
                      Icons.calendar_today,
                      () => _selectDate(isStart: false),
                    ),
                  ),
                ],
              ),
            ),

          // Quick Stats Row
          SizedBox(height: 10), // Reduced from 12
          Row(
            children: [
              _buildQuickStat(
                'Period',
                _getDateRangeText(),
                Icons.date_range,
                primaryGreen,
              ),
              SizedBox(width: 6), // Reduced from 8
              _buildQuickStat(
                'Shops',
                _selectedShop.length > 15
                    ? '${_selectedShop.substring(0, 12)}...'
                    : _selectedShop,
                Icons.store,
                secondaryGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 4,
        ), // Reduced from 8,6
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6), // Reduced from 8
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: color), // Reduced from 14
            SizedBox(width: 3), // Reduced from 4
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 8, // Reduced from 9
                      color: color.withOpacity(0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 10, // Reduced from 11
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 6,
        ), // Reduced from 8
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6), // Reduced from 8
          border: Border.all(color: primaryGreen.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: primaryGreen), // Reduced from 14
            SizedBox(width: 3), // Reduced from 4
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10, // Reduced from 11
                  fontWeight: FontWeight.w500,
                  color: primaryGreen,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopSelector() {
    List<String> shopNames = [
      'All Shops',
      ...widget.shops.map((s) => s['name'] as String),
    ];

    return Container(
      height: 44, // Reduced from 50
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ), // Reduced from 16,8
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: shopNames.length,
        itemBuilder: (context, index) {
          String shop = shopNames[index];
          bool isSelected = _selectedShop == shop;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedShop = shop;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 6), // Reduced from 8
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ), // Reduced from 16,6
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [secondaryGreen, primaryGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(16), // Reduced from 20
                border: Border.all(
                  color: isSelected ? secondaryGreen : Colors.grey.shade300,
                  width: isSelected ? 0 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: secondaryGreen.withOpacity(0.3),
                          blurRadius: 6, // Reduced from 8
                          offset: Offset(0, 2), // Reduced from 3
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  shop.length > 12 ? '${shop.substring(0, 10)}...' : shop,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 11, // Added fixed font size
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Specific view for Phone Sales
  Widget _buildPhoneSalesView() {
    return _buildSpecificCollectionView(
      collectionType: 'phone_sale',
      collectionName: 'Phone',
      icon: Icons.phone_android,
      color: Color(0xFF4CAF50),
    );
  }

  // Specific view for Base Model
  Widget _buildBaseModelView() {
    return _buildSpecificCollectionView(
      collectionType: 'base_model_sale',
      collectionName: 'Base',
      icon: Icons.phone_iphone,
      color: Color(0xFF2196F3),
    );
  }

  // Specific view for Second Phone
  Widget _buildSecondPhoneView() {
    return _buildSpecificCollectionView(
      collectionType: 'seconds_phone_sale',
      collectionName: 'Second',
      icon: Icons.phone_iphone_outlined,
      color: Color(0xFF9C27B0),
    );
  }

  // Specific view for Accessories
  Widget _buildAccessoriesView() {
    return _buildSpecificCollectionView(
      collectionType: 'accessories_service_sale',
      collectionName: 'Accessories',
      icon: Icons.build,
      color: Color(0xFFFF9800),
    );
  }

  // Generic method for specific collection views
  Widget _buildSpecificCollectionView({
    required String collectionType,
    required String collectionName,
    required IconData icon,
    required Color color,
  }) {
    List<Sale> filteredSales = _getFilteredSales()
        .where((s) => s.type == collectionType)
        .toList();

    if (filteredSales.isEmpty) {
      return _buildEnhancedEmptyState(message: 'No $collectionName found');
    }

    // Calculate totals
    double totalGPay = 0, totalCash = 0, totalCard = 0, totalCredit = 0;

    for (var sale in filteredSales) {
      totalGPay += sale.gpayAmount ?? 0;
      totalCash += sale.cashAmount ?? 0;
      totalCard += sale.cardAmount ?? 0;
      totalCredit += sale.customerCredit ?? 0;
    }

    double totalAmount = totalGPay + totalCash + totalCard + totalCredit;

    return SingleChildScrollView(
      padding: EdgeInsets.all(12), // Reduced from 16
      child: Column(
        children: [
          // Summary Card
          Container(
            margin: EdgeInsets.only(bottom: 16), // Reduced from 20
            padding: EdgeInsets.all(16), // Reduced from 20
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.1), Colors.white],
              ),
              borderRadius: BorderRadius.circular(16), // Reduced from 20
              border: Border.all(color: color.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 8, // Reduced from 10
                  offset: Offset(0, 3), // Reduced from 4
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8), // Reduced from 12
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(
                          8,
                        ), // Reduced from 12
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 20,
                      ), // Reduced from 24
                    ),
                    SizedBox(width: 12), // Reduced from 16
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            collectionName,
                            style: TextStyle(
                              fontSize: 16, // Reduced from 18
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            '${filteredSales.length} transactions',
                            style: TextStyle(
                              fontSize: 11, // Reduced from 12
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12, // Reduced from 16
                        vertical: 6, // Reduced from 8
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(
                          20,
                        ), // Reduced from 30
                      ),
                      child: Text(
                        '₹${widget.formatNumber(totalAmount)}',
                        style: TextStyle(
                          fontSize: 14, // Reduced from 16
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16), // Reduced from 20
                Divider(color: color.withOpacity(0.3)),
                SizedBox(height: 12), // Reduced from 16
                // Payment Methods Breakdown
                Text(
                  'Payment Breakdown',
                  style: TextStyle(
                    fontSize: 13, // Reduced from 14
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 10), // Reduced from 12

                _buildPaymentDetailRow(
                  'GPay',
                  totalGPay,
                  totalAmount,
                  gpayColor,
                  Icons.payment,
                ),
                SizedBox(height: 6), // Reduced from 8
                _buildPaymentDetailRow(
                  'Cash',
                  totalCash,
                  totalAmount,
                  cashColor,
                  Icons.money,
                ),
                SizedBox(height: 6), // Reduced from 8
                _buildPaymentDetailRow(
                  'Card',
                  totalCard,
                  totalAmount,
                  cardColor,
                  Icons.credit_card,
                ),
                SizedBox(height: 6), // Reduced from 8
                _buildPaymentDetailRow(
                  'Credit',
                  totalCredit,
                  totalAmount,
                  creditColor,
                  Icons.credit_score,
                ),
              ],
            ),
          ),

          // Recent Transactions
          if (filteredSales.isNotEmpty)
            Container(
              padding: EdgeInsets.all(12), // Reduced from 16
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14), // Reduced from 16
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent',
                    style: TextStyle(
                      fontSize: 14, // Reduced from 16
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  SizedBox(height: 8), // Reduced from 12
                  ...filteredSales
                      .take(5)
                      .map(
                        (sale) => Container(
                          margin: EdgeInsets.only(bottom: 6), // Reduced from 8
                          padding: EdgeInsets.all(8), // Reduced from 12
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(
                              8,
                            ), // Reduced from 12
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat(
                                        'dd MMM',
                                      ).format(sale.date), // Removed year
                                      style: TextStyle(
                                        fontSize: 10, // Reduced from 11
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      sale.customerName.length > 15
                                          ? '${sale.customerName.substring(0, 12)}...'
                                          : sale.customerName,
                                      style: TextStyle(
                                        fontSize: 11, // Reduced from 12
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '₹${widget.formatNumber(sale.amount)}',
                                  style: TextStyle(
                                    fontSize: 11, // Reduced from 12
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (filteredSales.length > 5)
                    Padding(
                      padding: EdgeInsets.only(top: 6), // Reduced from 8
                      child: Center(
                        child: Text(
                          '+ ${filteredSales.length - 5} more',
                          style: TextStyle(
                            fontSize: 11, // Reduced from 12
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
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
  }

  Widget _buildPaymentDetailRow(
    String label,
    double amount,
    double total,
    Color color,
    IconData icon,
  ) {
    double percentage = total > 0 ? (amount / total * 100) : 0;

    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color), // Reduced from 16
            SizedBox(width: 6), // Reduced from 8
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ), // Reduced from 13
            ),
            Spacer(),
            Text(
              '₹${widget.formatNumber(amount)}',
              style: TextStyle(
                fontSize: 12, // Reduced from 13
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(width: 6), // Reduced from 8
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ), // Reduced from 8,2
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10), // Reduced from 12
              ),
              child: Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 10, // Reduced from 11
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 3), // Reduced from 4
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: color.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 3, // Reduced from 4
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

  Widget _buildAllCollectionsView() {
    List<Sale> filteredSales = _getFilteredSales();

    Map<String, Map<String, dynamic>> shopCollectionPayments = {};

    for (var sale in filteredSales) {
      if (!shopCollectionPayments.containsKey(sale.shopName)) {
        shopCollectionPayments[sale.shopName] = {
          'phone_sale': {
            'gpay': 0.0,
            'cash': 0.0,
            'card': 0.0,
            'credit': 0.0,
            'total': 0.0,
          },
          'base_model_sale': {
            'gpay': 0.0,
            'cash': 0.0,
            'card': 0.0,
            'credit': 0.0,
            'total': 0.0,
          },
          'seconds_phone_sale': {
            'gpay': 0.0,
            'cash': 0.0,
            'card': 0.0,
            'credit': 0.0,
            'total': 0.0,
          },
          'accessories_service_sale': {
            'gpay': 0.0,
            'cash': 0.0,
            'card': 0.0,
            'credit': 0.0,
            'total': 0.0,
          },
          'shopTotal': 0.0,
        };
      }
    }

    for (var sale in filteredSales) {
      var shopData = shopCollectionPayments[sale.shopName];
      if (shopData != null) {
        var collectionData = shopData[sale.type];
        if (collectionData != null) {
          collectionData['gpay'] =
              (collectionData['gpay'] as double) + (sale.gpayAmount ?? 0);
          collectionData['cash'] =
              (collectionData['cash'] as double) + (sale.cashAmount ?? 0);
          collectionData['card'] =
              (collectionData['card'] as double) + (sale.cardAmount ?? 0);
          collectionData['credit'] =
              (collectionData['credit'] as double) + (sale.customerCredit ?? 0);
          collectionData['total'] =
              (collectionData['total'] as double) + sale.amount;
        }
        shopData['shopTotal'] = (shopData['shopTotal'] as double) + sale.amount;
      }
    }

    var sortedShops = shopCollectionPayments.entries.toList()
      ..sort(
        (a, b) => (b.value['shopTotal'] as double).compareTo(
          a.value['shopTotal'] as double,
        ),
      );

    if (_selectedShop != 'All Shops') {
      sortedShops = sortedShops.where((s) => s.key == _selectedShop).toList();
    }

    if (sortedShops.isEmpty) {
      return _buildEnhancedEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.all(12), // Reduced from 16
      itemCount: sortedShops.length,
      itemBuilder: (context, index) {
        String shopName = sortedShops[index].key;
        Map<String, dynamic> shopData = sortedShops[index].value;
        double shopTotal = (shopData['shopTotal'] as double?) ?? 0;

        return _buildEnhancedShopCard(shopName, shopTotal, shopData, index);
      },
    );
  }

  Widget _buildEnhancedShopCard(
    String shopName,
    double shopTotal,
    Map<String, dynamic> shopData,
    int index,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12), // Reduced from 16
      child: Card(
        elevation: 3, // Reduced from 4
        shadowColor: primaryGreen.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ), // Reduced from 20
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16), // Reduced from 20
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, lightGreen.withOpacity(0.2)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(12), // Reduced from 16
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced header with rank
                Row(
                  children: [
                    Container(
                      width: 32, // Reduced from 40
                      height: 32, // Reduced from 40
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryGreen, secondaryGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(
                          8,
                        ), // Reduced from 12
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14, // Reduced from 16
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8), // Reduced from 12
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName.length > 20
                                ? '${shopName.substring(0, 17)}...'
                                : shopName,
                            style: TextStyle(
                              fontSize: 14, // Reduced from 16
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                          Text(
                            '${_getActiveCollectionsCount(shopData)} active',
                            style: TextStyle(
                              fontSize: 10, // Reduced from 11
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10, // Reduced from 12
                        vertical: 6, // Reduced from 8
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [secondaryGreen, primaryGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(
                          16,
                        ), // Reduced from 20
                        boxShadow: [
                          BoxShadow(
                            color: secondaryGreen.withOpacity(0.3),
                            blurRadius: 6, // Reduced from 8
                            offset: Offset(0, 2), // Reduced from 3
                          ),
                        ],
                      ),
                      child: Text(
                        '₹${widget.formatNumber(shopTotal)}',
                        style: TextStyle(
                          fontSize: 12, // Reduced from 14
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16), // Reduced from 20
                // Collection types
                GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.6, // Reduced from 1.8
                  crossAxisSpacing: 8, // Reduced from 12
                  mainAxisSpacing: 8, // Reduced from 12
                  children: [
                    if ((shopData['phone_sale']['total'] as double?) != 0)
                      _buildEnhancedCollectionCard(
                        'Phone',
                        (shopData['phone_sale']['total'] as double?) ?? 0,
                        Icons.phone_android,
                        Color(0xFF4CAF50),
                        Map<String, double>.from(shopData['phone_sale']),
                      ),
                    if ((shopData['base_model_sale']['total'] as double?) != 0)
                      _buildEnhancedCollectionCard(
                        'Base',
                        (shopData['base_model_sale']['total'] as double?) ?? 0,
                        Icons.phone_iphone,
                        Color(0xFF2196F3),
                        Map<String, double>.from(shopData['base_model_sale']),
                      ),
                    if ((shopData['seconds_phone_sale']['total'] as double?) !=
                        0)
                      _buildEnhancedCollectionCard(
                        'Second',
                        (shopData['seconds_phone_sale']['total'] as double?) ??
                            0,
                        Icons.phone_iphone_outlined,
                        Color(0xFF9C27B0),
                        Map<String, double>.from(
                          shopData['seconds_phone_sale'],
                        ),
                      ),
                    if ((shopData['accessories_service_sale']['total']
                            as double?) !=
                        0)
                      _buildEnhancedCollectionCard(
                        'Service',
                        (shopData['accessories_service_sale']['total']
                                as double?) ??
                            0,
                        Icons.build,
                        Color(0xFFFF9800),
                        Map<String, double>.from(
                          shopData['accessories_service_sale'],
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 12), // Reduced from 16
                // View details button
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _showEnhancedDetails(shopName, shopData),
                    icon: Icon(Icons.visibility, size: 14), // Reduced from 16
                    label: Text(
                      'View Details',
                      style: TextStyle(fontSize: 12),
                    ), // Added font size
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: secondaryGreen,
                      elevation: 0,
                      side: BorderSide(color: secondaryGreen.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          20,
                        ), // Reduced from 30
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16, // Reduced from 20
                        vertical: 8, // Reduced from 12
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedCollectionCard(
    String title,
    double total,
    IconData icon,
    Color color,
    Map<String, double> payments,
  ) {
    return Container(
      padding: EdgeInsets.all(8), // Reduced from 12
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // Reduced from 16
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4, // Reduced from 6
            offset: Offset(0, 1), // Reduced from 2
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(4), // Reduced from 6
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6), // Reduced from 8
                ),
                child: Icon(icon, size: 12, color: color), // Reduced from 14
              ),
              SizedBox(width: 4), // Reduced from 8
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10, // Reduced from 11
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 6), // Reduced from 8
          Text(
            '₹${widget.formatNumber(total)}',
            style: TextStyle(
              fontSize: 13, // Reduced from 15
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4), // Reduced from 6
          Row(
            children: [
              if ((payments['gpay'] ?? 0) > 0)
                _buildEnhancedIndicator('G', payments['gpay'] ?? 0, gpayColor),
              if ((payments['cash'] ?? 0) > 0)
                _buildEnhancedIndicator('C', payments['cash'] ?? 0, cashColor),
              if ((payments['card'] ?? 0) > 0)
                _buildEnhancedIndicator('CD', payments['card'] ?? 0, cardColor),
              if ((payments['credit'] ?? 0) > 0)
                _buildEnhancedIndicator(
                  'CR',
                  payments['credit'] ?? 0,
                  creditColor,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedIndicator(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.only(right: 1), // Reduced from 2
        padding: EdgeInsets.symmetric(vertical: 2), // Reduced from 3
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(3), // Reduced from 4
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 7, // Reduced from 8
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  void _showEnhancedDetails(String shopName, Map<String, dynamic> shopData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ), // Reduced from 30
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: EdgeInsets.all(16), // Reduced from 20
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      width: 32, // Reduced from 40
                      height: 3, // Reduced from 4
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 16), // Reduced from 20
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8), // Reduced from 12
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryGreen, secondaryGreen],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              12,
                            ), // Reduced from 16
                          ),
                          child: Icon(
                            Icons.store,
                            color: Colors.white,
                            size: 20, // Reduced from 24
                          ),
                        ),
                        SizedBox(width: 12), // Reduced from 16
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shopName.length > 25
                                    ? '${shopName.substring(0, 22)}...'
                                    : shopName,
                                style: TextStyle(
                                  fontSize: 18, // Reduced from 20
                                  fontWeight: FontWeight.bold,
                                  color: primaryGreen,
                                ),
                              ),
                              Text(
                                'Payment Analysis',
                                style: TextStyle(
                                  fontSize: 12, // Reduced from 13
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.grey[600],
                            size: 20,
                          ), // Added size
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero, // Reduced padding
                          constraints: BoxConstraints(), // Reduced constraints
                        ),
                      ],
                    ),
                    SizedBox(height: 20), // Reduced from 24
                    // Detailed content
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          if ((shopData['phone_sale']['total'] as double?) != 0)
                            _buildEnhancedDetailSection(
                              'Phone Sales',
                              Map<String, double>.from(shopData['phone_sale']),
                              Icons.phone_android,
                              Color(0xFF4CAF50),
                            ),
                          if ((shopData['base_model_sale']['total']
                                  as double?) !=
                              0)
                            _buildEnhancedDetailSection(
                              'Base Model',
                              Map<String, double>.from(
                                shopData['base_model_sale'],
                              ),
                              Icons.phone_iphone,
                              Color(0xFF2196F3),
                            ),
                          if ((shopData['seconds_phone_sale']['total']
                                  as double?) !=
                              0)
                            _buildEnhancedDetailSection(
                              'Second Phone',
                              Map<String, double>.from(
                                shopData['seconds_phone_sale'],
                              ),
                              Icons.phone_iphone_outlined,
                              Color(0xFF9C27B0),
                            ),
                          if ((shopData['accessories_service_sale']['total']
                                  as double?) !=
                              0)
                            _buildEnhancedDetailSection(
                              'Accessories',
                              Map<String, double>.from(
                                shopData['accessories_service_sale'],
                              ),
                              Icons.build,
                              Color(0xFFFF9800),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEnhancedDetailSection(
    String title,
    Map<String, double> data,
    IconData icon,
    Color color,
  ) {
    double total = data['total'] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 16), // Reduced from 20
      padding: EdgeInsets.all(16), // Reduced from 20
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.05), Colors.white],
        ),
        borderRadius: BorderRadius.circular(16), // Reduced from 20
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8), // Reduced from 10
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8), // Reduced from 12
                ),
                child: Icon(icon, color: color, size: 18), // Reduced from 20
              ),
              SizedBox(width: 10), // Reduced from 12
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14, // Reduced from 16
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ), // Reduced from 12,6
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16), // Reduced from 20
                ),
                child: Text(
                  '₹${widget.formatNumber(total)}',
                  style: TextStyle(
                    fontSize: 12, // Reduced from 14
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16), // Reduced from 20
          // Payment methods
          _buildPaymentMethodBar(
            'GPay',
            data['gpay'] ?? 0,
            total,
            gpayColor,
            Icons.payment,
          ),
          SizedBox(height: 8), // Reduced from 12
          _buildPaymentMethodBar(
            'Cash',
            data['cash'] ?? 0,
            total,
            cashColor,
            Icons.money,
          ),
          SizedBox(height: 8), // Reduced from 12
          _buildPaymentMethodBar(
            'Card',
            data['card'] ?? 0,
            total,
            cardColor,
            Icons.credit_card,
          ),
          SizedBox(height: 8), // Reduced from 12
          _buildPaymentMethodBar(
            'Credit',
            data['credit'] ?? 0,
            total,
            creditColor,
            Icons.credit_score,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodBar(
    String label,
    double amount,
    double total,
    Color color,
    IconData icon,
  ) {
    double percentage = total > 0 ? (amount / total * 100) : 0;

    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color), // Reduced from 16
            SizedBox(width: 6), // Reduced from 8
            Text(
              label,
              style: TextStyle(
                fontSize: 12, // Reduced from 13
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            Spacer(),
            Text(
              '₹${widget.formatNumber(amount)}',
              style: TextStyle(
                fontSize: 12, // Reduced from 13
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(width: 6), // Reduced from 8
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ), // Reduced from 8,2
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10), // Reduced from 12
              ),
              child: Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 10, // Reduced from 11
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 3), // Reduced from 4
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: color.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 5, // Reduced from 6
          borderRadius: BorderRadius.circular(2), // Reduced from 3
        ),
      ],
    );
  }

  Widget _buildEnhancedEmptyState({String message = 'No data available'}) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24), // Reduced from 32
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16), // Reduced from 20
              decoration: BoxDecoration(
                color: lightGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.payment_outlined,
                size: 40, // Reduced from 48
                color: primaryGreen.withOpacity(0.5),
              ),
            ),
            SizedBox(height: 20), // Reduced from 24
            Text(
              message,
              style: TextStyle(
                fontSize: 16, // Reduced from 18
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            SizedBox(height: 6), // Reduced from 8
            Text(
              'Try adjusting your filters',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12, // Reduced from 13
                color: Colors.grey[600],
                height: 1.3, // Reduced from 1.5
              ),
            ),
            SizedBox(height: 20), // Reduced from 24
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedShop = 'All Shops';
                  _setDateRange('This Month');
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20), // Reduced from 30
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ), // Reduced from 24,12
              ),
              child: Text(
                'Reset Filters',
                style: TextStyle(fontSize: 13),
              ), // Added font size
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
            strokeWidth: 3, // Added stroke width
          ),
          SizedBox(height: 12), // Reduced from 16
          Text(
            'Loading...',
            style: TextStyle(
              color: primaryGreen,
              fontWeight: FontWeight.w600,
              fontSize: 13, // Added font size
            ),
          ),
        ],
      ),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ), // Reduced from 20
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16), // Reduced from 20
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Export Report',
                style: TextStyle(
                  fontSize: 16, // Reduced from 18
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 16), // Reduced from 20
              _buildExportOption(
                'PDF Report',
                Icons.picture_as_pdf,
                Colors.red,
                () {
                  Navigator.pop(context);
                  _showComingSoon();
                },
              ),
              _buildExportOption('Excel', Icons.table_chart, Colors.green, () {
                Navigator.pop(context);
                _showComingSoon();
              }),
              _buildExportOption(
                'CSV File',
                Icons.insert_drive_file,
                Colors.blue,
                () {
                  Navigator.pop(context);
                  _showComingSoon();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExportOption(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(6), // Reduced from 8
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6), // Reduced from 8
        ),
        child: Icon(icon, color: color, size: 18), // Added size
      ),
      title: Text(title, style: TextStyle(fontSize: 14)), // Added font size
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey,
      ), // Reduced from 16
      onTap: onTap,
      dense: true, // Added dense property
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Coming soon!',
          style: TextStyle(fontSize: 13),
        ), // Added font size
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ), // Reduced from 10
        duration: Duration(seconds: 1), // Added duration
      ),
    );
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: primaryGreen,
            colorScheme: ColorScheme.light(primary: primaryGreen),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedDateRange = 'Custom';
      });
    }
  }

  Future<void> _selectDate({required bool isStart}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate! : _endDate!,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: primaryGreen,
            colorScheme: ColorScheme.light(primary: primaryGreen),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = DateTime(picked.year, picked.month, picked.day);
        } else {
          _endDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            23,
            59,
            59,
          );
        }
        _selectedDateRange = 'Custom';
      });
    }
  }

  // Helper methods
  String _formatDate(DateTime? date) {
    if (date == null) return 'Select';
    return DateFormat('dd MMM').format(date); // Removed year
  }

  String _getDateRangeText() {
    if (_startDate == null || _endDate == null) return 'Select';

    if (_selectedDateRange == 'Today') return 'Today';
    if (_selectedDateRange == 'Yesterday') return 'Yesterday';
    if (_selectedDateRange == 'This Month') return 'This Month';
    if (_selectedDateRange == 'Last Month') return 'Last Month';
    if (_selectedDateRange == 'This Year') return 'This Year';

    return '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}';
  }

  List<Sale> _getFilteredSales() {
    return widget.allSales.where((sale) {
      // Shop filter
      if (_selectedShop != 'All Shops' && sale.shopName != _selectedShop) {
        return false;
      }

      // Date filter
      if (_startDate != null && _endDate != null) {
        bool dateInRange =
            sale.date.isAfter(_startDate!.subtract(Duration(days: 1))) &&
            sale.date.isBefore(_endDate!.add(Duration(days: 1)));
        if (!dateInRange) return false;
      }

      return true;
    }).toList();
  }

  int _getActiveCollectionsCount(Map<String, dynamic> shopData) {
    int count = 0;
    if ((shopData['phone_sale']['total'] as double?) != 0) count++;
    if ((shopData['base_model_sale']['total'] as double?) != 0) count++;
    if ((shopData['seconds_phone_sale']['total'] as double?) != 0) count++;
    if ((shopData['accessories_service_sale']['total'] as double?) != 0)
      count++;
    return count;
  }
}
