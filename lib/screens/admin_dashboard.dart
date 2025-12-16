import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String? _selectedShop;
  String _timePeriod = 'monthly';
  bool _isLoading = true;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  final CollectionReference accessoriesServiceSales = FirebaseFirestore.instance
      .collection('accessories_service_sales');
  final CollectionReference baseModelSales = FirebaseFirestore.instance
      .collection('base_model_sale');
  final CollectionReference phoneSales = FirebaseFirestore.instance.collection(
    'phoneSales',
  );
  final CollectionReference secondsPhoneSales = FirebaseFirestore.instance
      .collection('seconds_phone_sale');

  // Green color scheme
  final Color primaryGreen = Color(0xFF0A4D2E);
  final Color secondaryGreen = Color(0xFF1A7D4A);
  final Color accentGreen = Color(0xFF28A745);
  final Color lightGreen = Color(0xFFE8F5E9);
  final Color cardGreen = Color(0xFF2E7D32);
  final Color warningColor = Color(0xFFFFC107);
  final Color dangerColor = Color(0xFFDC3545);

  // Data lists
  List<Sale> allSales = [];
  List<Map<String, dynamic>> shops = [];

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all data concurrently
      await Future.wait([
        _fetchAccessoriesServiceSales(),
        _fetchBaseModelSales(),
        _fetchPhoneSales(),
        _fetchSecondsPhoneSales(),
        _fetchShops(),
      ]);

      // Sort all sales by date (newest first)
      allSales.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        _isLoading = false;
      });
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: dangerColor,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _fetchAccessoriesServiceSales() async {
    try {
      final snapshot = await accessoriesServiceSales.get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Parse date
        DateTime saleDate;
        if (data['date'] is Timestamp) {
          saleDate = (data['date'] as Timestamp).toDate();
        } else {
          final dateStr = data['dateString'] ?? '2025-12-13';
          saleDate = DateFormat('yyyy-MM-dd').parse(dateStr);
        }

        // Calculate profit (assume 35% margin for accessories and service)
        final totalAmount = (data['totalSaleAmount'] ?? 0).toDouble();
        final profit = totalAmount * 0.35;
        final costPrice = totalAmount - profit;

        allSales.add(
          Sale(
            id: doc.id,
            type: 'accessories_service_sale',
            shopName: data['shopName'] ?? 'Unknown Shop',
            shopId: data['shopId'] ?? '',
            amount: totalAmount,
            date: saleDate,
            customerName: _getCustomerNameFromData(data),
            category: 'Service',
            itemName: 'Accessories & Services',
            profit: profit,
            costPrice: costPrice,
            cashAmount: (data['cashAmount'] ?? 0).toDouble(),
            cardAmount: (data['cardAmount'] ?? 0).toDouble(),
            gpayAmount: (data['gpayAmount'] ?? 0).toDouble(),
            salesPersonName: data['salesPersonName'] ?? 'Unknown',
          ),
        );
      }
    } catch (e) {
      print('Error fetching accessories service sales: $e');
    }
  }

  Future<void> _fetchBaseModelSales() async {
    try {
      final snapshot = await baseModelSales.get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Parse date
        DateTime saleDate;
        if (data['timestamp'] != null) {
          saleDate = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
        } else if (data['uploadedAt'] is Timestamp) {
          saleDate = (data['uploadedAt'] as Timestamp).toDate();
        } else {
          saleDate = DateTime.now();
        }

        final price = (data['price'] ?? 0).toDouble();
        final profit = price * 0.25;
        final costPrice = price - profit;

        allSales.add(
          Sale(
            id: doc.id,
            type: 'base_model_sale',
            shopName: data['shopName'] ?? 'Unknown Shop',
            shopId: data['shopId'] ?? '',
            amount: price,
            date: saleDate,
            customerName: data['customerName'] ?? 'Unknown Customer',
            category: 'Base Model',
            itemName: data['modelName'] ?? 'Base Model Phone',
            brand: data['brand'] ?? '',
            model: data['modelName'] ?? '',
            profit: profit,
            costPrice: costPrice,
            cashAmount: (data['cash'] ?? 0).toDouble(),
            cardAmount: (data['card'] ?? 0).toDouble(),
            gpayAmount: (data['gpay'] ?? 0).toDouble(),
            salesPersonName: data['salesPersonName'] ?? 'Unknown',
            customerPhone: data['customerPhone'] ?? '',
          ),
        );
      }
    } catch (e) {
      print('Error fetching base model sales: $e');
    }
  }

  Future<void> _fetchPhoneSales() async {
    try {
      final snapshot = await phoneSales.get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Parse date
        DateTime saleDate;
        if (data['saleDate'] is Timestamp) {
          saleDate = (data['saleDate'] as Timestamp).toDate();
        } else if (data['createdAt'] is Timestamp) {
          saleDate = (data['createdAt'] as Timestamp).toDate();
        } else {
          saleDate = DateTime.now();
        }

        final effectivePrice = (data['effectivePrice'] ?? 0).toDouble();
        final disbursementAmount = (data['disbursementAmount'] ?? 0).toDouble();
        final profit = effectivePrice - disbursementAmount;

        allSales.add(
          Sale(
            id: doc.id,
            type: 'phone_sale',
            shopName: data['shopName'] ?? 'Unknown Shop',
            shopId: data['shopId'] ?? '',
            amount: effectivePrice,
            date: saleDate,
            customerName: data['customerName'] ?? 'Unknown Customer',
            category: 'New Phone',
            itemName: data['productModel'] ?? 'New Phone',
            brand: data['brand'] ?? '',
            model: data['productModel'] ?? '',
            profit: profit > 0 ? profit : effectivePrice * 0.2,
            costPrice: disbursementAmount > 0
                ? disbursementAmount
                : effectivePrice * 0.8,
            cashAmount: (data['paymentBreakdown']?['cash'] ?? 0).toDouble(),
            cardAmount: (data['paymentBreakdown']?['card'] ?? 0).toDouble(),
            downPayment: (data['downPayment'] ?? 0).toDouble(),
            financeType: data['financeType'],
            purchaseMode: data['purchaseMode'],
            salesPersonEmail: data['userEmail'] ?? 'Unknown',
            customerPhone: data['customerPhone'] ?? '',
            imei: data['imei'] ?? '',
            discount: (data['discount'] ?? 0).toDouble(),
            exchangeValue: (data['exchangeValue'] ?? 0).toDouble(),
            amountToPay: (data['amountToPay'] ?? 0).toDouble(),
            balanceReturnedToCustomer: (data['balanceReturnedToCustomer'] ?? 0)
                .toDouble(),
            customerCredit: (data['customerCredit'] ?? 0).toDouble(),
            gpayAmount: (data['paymentBreakdown']?['gpay'] ?? 0).toDouble(),
            addedAt: (data['createdAt'] is Timestamp)
                ? (data['createdAt'] as Timestamp).toDate()
                : saleDate,
          ),
        );
      }
    } catch (e) {
      print('Error fetching phone sales: $e');
    }
  }

  Future<void> _fetchSecondsPhoneSales() async {
    try {
      final snapshot = await secondsPhoneSales.get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Parse date
        DateTime saleDate;
        if (data['uploadedAt'] is Timestamp) {
          saleDate = (data['uploadedAt'] as Timestamp).toDate();
        } else if (data['timestamp'] != null) {
          saleDate = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
        } else {
          saleDate = DateTime.now();
        }

        final price = (data['price'] ?? 0).toDouble();
        final profit = price * 0.3;
        final costPrice = price - profit;

        allSales.add(
          Sale(
            id: doc.id,
            type: 'seconds_phone_sale',
            shopName: data['shopName'] ?? 'Unknown Shop',
            shopId: data['shopId'] ?? '',
            amount: price,
            date: saleDate,
            customerName: data['customerName'] ?? 'Unknown Customer',
            category: 'Second Phone',
            itemName: data['productName'] ?? 'Second Hand Phone',
            profit: profit,
            costPrice: costPrice,
            cashAmount: (data['cash'] ?? 0).toDouble(),
            cardAmount: (data['card'] ?? 0).toDouble(),
            gpayAmount: (data['gpay'] ?? 0).toDouble(),
            salesPersonName: data['uploadedByEmail'] ?? 'Unknown',
            customerPhone: data['customerPhone'] ?? '',
            imei: data['imei'] ?? '',
            defect: data['defect'] ?? '',
          ),
        );
      }
    } catch (e) {
      print('Error fetching seconds phone sales: $e');
    }
  }

  Future<void> _fetchShops() async {
    try {
      final shopIds = <String>{};
      final shopMap = <String, Map<String, dynamic>>{};

      for (var sale in allSales) {
        if (!shopIds.contains(sale.shopId)) {
          shopIds.add(sale.shopId);
          shopMap[sale.shopId] = {
            'id': sale.shopId,
            'name': sale.shopName,
            'target': _getShopTarget(sale.shopName),
          };
        }
      }

      shops = shopMap.values.toList();

      if (shops.isEmpty) {
        shops = [
          {
            'id': 'Mk9k3DiuelPsEbE0MCqQ',
            'name': 'MobileHouse1(shed)',
            'target': 150000.0,
          },
          {
            'id': 'BrqQtjE0Uo9mCYcUSiK3',
            'name': 'MobileHouse2(3way)',
            'target': 180000.0,
          },
        ];
      }
    } catch (e) {
      print('Error fetching shops: $e');
    }
  }

  double _getShopTarget(String shopName) {
    if (shopName.contains('MobileHouse1')) {
      return 150000.0;
    } else if (shopName.contains('MobileHouse2')) {
      return 180000.0;
    } else {
      return 100000.0;
    }
  }

  String _getCustomerNameFromData(Map<String, dynamic> data) {
    if (data['customerName'] != null &&
        data['customerName'].toString().isNotEmpty) {
      return data['customerName'];
    } else if (data['salesPersonName'] != null &&
        data['salesPersonName'].toString().isNotEmpty) {
      return 'Customer of ${data['salesPersonName']}';
    } else {
      return 'Walk-in Customer';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        title: Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryGreen,
        elevation: 2,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchAllData,
            tooltip: 'Refresh Data',
            color: Colors.white,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading ? _buildLoadingScreen() : _buildDashboardContent(),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: secondaryGreen, strokeWidth: 3),
          SizedBox(height: 20),
          Text(
            'Loading dashboard data...',
            style: TextStyle(
              color: primaryGreen,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Fetching from Firebase...',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: secondaryGreen,
      backgroundColor: lightGreen,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            _buildPerformanceInsights(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryGreen, secondaryGreen],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
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
                      'Monthly Revenue',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '₹${_formatNumber(_calculateTotalSales())}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: Colors.white.withOpacity(0.8),
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedDate),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
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
                    Icon(Icons.trending_up, color: Colors.white, size: 24),
                    SizedBox(height: 6),
                    Text(
                      '+12.5%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderStat(
                  'Total Sales',
                  '₹${_formatNumber(_calculateTotalSales())}',
                  Icons.currency_rupee,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.white.withOpacity(0.3),
                ),
                _buildHeaderStat(
                  'Transactions',
                  '${_filterSales().length}',
                  Icons.receipt,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.9), size: 16),
              SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTimePeriodSelector(),
              SizedBox(height: 16),
              _buildShopFilter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePeriodSelector() {
    List<Map<String, dynamic>> periods = [
      {'label': 'Today', 'icon': Icons.today, 'value': 'daily'},
      {'label': 'Week', 'icon': Icons.calendar_view_week, 'value': 'weekly'},
      {'label': 'Month', 'icon': Icons.calendar_month, 'value': 'monthly'},
      {'label': 'Year', 'icon': Icons.calendar_today, 'value': 'yearly'},
      {'label': 'Custom', 'icon': Icons.date_range, 'value': 'custom'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time Period',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: primaryGreen,
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: periods.length,
            itemBuilder: (context, index) {
              bool isSelected = _timePeriod == periods[index]['value'];
              return Container(
                margin: EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _timePeriod = periods[index]['value'];
                      if (_timePeriod == 'custom') {
                        _showCustomDateRangePicker();
                      }
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? secondaryGreen : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? secondaryGreen
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: secondaryGreen.withOpacity(0.3),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          periods[index]['icon'],
                          size: 16,
                          color: isSelected ? Colors.white : secondaryGreen,
                        ),
                        SizedBox(width: 6),
                        Text(
                          periods[index]['label'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShopFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shop Filter',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: primaryGreen,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.store, color: secondaryGreen, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedShop,
                    hint: Text(
                      'All Shops',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'All Shops',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                      ...shops.map<DropdownMenuItem<String>>((shop) {
                        return DropdownMenuItem<String>(
                          value: shop['id'] as String,
                          child: Text(
                            shop['name'] as String,
                            style: TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (String? value) {
                      setState(() {
                        _selectedShop = value;
                      });
                    },
                    dropdownColor: Colors.white,
                    elevation: 2,
                    icon: Icon(Icons.arrow_drop_down, color: secondaryGreen),
                  ),
                ),
              ),
              if (_selectedShop != null)
                IconButton(
                  icon: Icon(Icons.clear, size: 18, color: Colors.grey[600]),
                  onPressed: () {
                    setState(() {
                      _selectedShop = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceInsights() {
    List<Sale> filteredSales = _filterSales();
    if (filteredSales.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No sales data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Try selecting a different time period',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Map<String, double> categoryPerformance = {};
    Map<String, int> categoryCount = {};
    Map<String, double> categoryProfit = {};

    for (var sale in filteredSales) {
      categoryPerformance[sale.category] =
          (categoryPerformance[sale.category] ?? 0.0) + sale.amount;
      categoryCount[sale.category] = (categoryCount[sale.category] ?? 0) + 1;
      categoryProfit[sale.category] =
          (categoryProfit[sale.category] ?? 0.0) + (sale.profit ?? 0.0);
    }

    // Get total sales for percentage calculation
    double totalSales = _calculateTotalSales();
    double totalProfit = categoryProfit.values.fold(
      0.0,
      (sum, profit) => sum + profit,
    );

    // Sort categories by amount (highest first)
    var sortedCategories = categoryPerformance.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: primaryGreen, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Category Performance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Add summary row at the top
              Container(
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryGreen.withOpacity(0.1)),
                ),
                padding: EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Total Sales',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '₹${_formatNumber(totalSales)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Total Profit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '₹${_formatNumber(totalProfit)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Categories',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${sortedCategories.length}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: secondaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              ...sortedCategories.map((entry) {
                String category = entry.key;
                double amount = entry.value;
                int count = categoryCount[category] ?? 0;
                double profit = categoryProfit[category] ?? 0.0;
                double percentage = totalSales > 0
                    ? (amount / totalSales) * 100
                    : 0.0;
                double profitMargin = amount > 0
                    ? (profit / amount) * 100
                    : 0.0;

                return Container(
                  margin: EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getCategoryColor(
                                category,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(
                                _getCategoryIcon(category),
                                color: _getCategoryColor(category),
                                size: 20,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Colors.grey[800],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: secondaryGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${count} sales',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: secondaryGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '₹${_formatNumber(amount)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: primaryGreen,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Profit: ₹${_formatNumber(profit)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${percentage.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          '${profitMargin.toStringAsFixed(1)}% margin',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: profitMargin > 20
                                                ? Colors.green
                                                : profitMargin > 10
                                                ? Colors.orange
                                                : Colors.red,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          _getCategoryColor(category),
                        ),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryGreen, secondaryGreen],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 40,
                    color: primaryGreen,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'MobileHouse Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Dashboard',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            Icons.dashboard,
            'Dashboard',
            onTap: () {
              Navigator.pop(context);
            },
            isSelected: true,
          ),
          Divider(height: 1),
          // Phone Sales Section
          _buildDrawerItem(
            Icons.phone_android,
            'Phone Sales Details',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PhoneSalesDetailsScreen(
                    allSales: allSales,
                    formatNumber: _formatNumber,
                  ),
                ),
              );
            },
          ),
          _buildDrawerItem(
            Icons.bar_chart,
            'Phone Sales Reports',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PhoneSalesReportsScreen(
                    allSales: allSales,
                    phoneSales: allSales
                        .where((s) => s.type == 'phone_sale')
                        .toList(),
                    formatNumber: _formatNumber,
                  ),
                ),
              );
            },
          ),
          Divider(height: 1),
          // Other Categories
          _buildDrawerItem(
            Icons.build,
            'Accessories & Service',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryDetailsScreen(
                    category: 'Service',
                    sales: _filterSales(),
                    formatNumber: _formatNumber,
                    getCategoryColor: _getCategoryColor,
                  ),
                ),
              );
            },
          ),
          _buildDrawerItem(
            Icons.phone_iphone,
            'Second Phone Sales',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryDetailsScreen(
                    category: 'Second Phone',
                    sales: _filterSales(),
                    formatNumber: _formatNumber,
                    getCategoryColor: _getCategoryColor,
                  ),
                ),
              );
            },
          ),
          _buildDrawerItem(
            Icons.phone,
            'Base Model Sales',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryDetailsScreen(
                    category: 'Base Model',
                    sales: _filterSales(),
                    formatNumber: _formatNumber,
                    getCategoryColor: _getCategoryColor,
                  ),
                ),
              );
            },
          ),
          Divider(height: 1),
          _buildDrawerItem(
            Icons.store,
            'Shop-wise Details',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShopWiseDetailsScreen(
                    sales: _filterSales(),
                    formatNumber: _formatNumber,
                    getCategoryColor: _getCategoryColor,
                  ),
                ),
              );
            },
          ),
          Divider(height: 1),
          _buildDrawerItem(
            Icons.settings,
            'Settings',
            onTap: () {
              Navigator.pop(context);
              // Add settings navigation
            },
          ),
          _buildDrawerItem(
            Icons.logout,
            'Logout',
            onTap: () {
              Navigator.pop(context);
              // Add logout functionality
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title, {
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? secondaryGreen : Colors.grey[700],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? secondaryGreen : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isSelected ? secondaryGreen.withOpacity(0.1) : null,
      onTap: onTap,
    );
  }

  Future<void> _refreshData() async {
    await _fetchAllData();
  }

  Future<void> _showCustomDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2026),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: secondaryGreen,
              secondary: accentGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
  }

  // Data calculation methods
  List<Sale> _filterSales() {
    DateTime startDate;
    DateTime endDate;

    switch (_timePeriod) {
      case 'daily':
        startDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'weekly':
        startDate = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        endDate = startDate.add(Duration(days: 7, seconds: -1));
        break;
      case 'monthly':
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          1,
        ).add(Duration(seconds: -1));
        break;
      case 'yearly':
        startDate = DateTime(_selectedDate.year, 1, 1);
        endDate = DateTime(
          _selectedDate.year + 1,
          1,
          1,
        ).add(Duration(seconds: -1));
        break;
      case 'custom':
        startDate =
            _customStartDate ?? DateTime.now().subtract(Duration(days: 30));
        endDate = _customEndDate ?? DateTime.now();
        break;
      default:
        startDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        endDate = startDate.add(Duration(days: 1, seconds: -1));
    }

    return allSales.where((sale) {
      bool dateMatch =
          sale.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
      bool shopMatch = _selectedShop == null || sale.shopId == _selectedShop;
      return dateMatch && shopMatch;
    }).toList();
  }

  double _calculateTotalSales() {
    return _filterSales().fold(0.0, (sum, sale) => sum + sale.amount);
  }

  double _calculateAverageSale() {
    List<Sale> sales = _filterSales();
    if (sales.isEmpty) return 0.0;
    return sales.fold(0.0, (sum, sale) => sum + sale.amount) / sales.length;
  }

  String _formatNumber(double number) {
    if (number >= 10000000) {
      return '${(number / 10000000).toStringAsFixed(2)}Cr';
    } else if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(2)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(number >= 100 ? 0 : 1);
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'New Phone':
        return Color(0xFF4CAF50);
      case 'Base Model':
        return Color(0xFF2196F3);
      case 'Second Phone':
        return Color(0xFF9C27B0);
      case 'Service':
        return Color(0xFFFF9800);
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'New Phone':
        return Icons.phone_android;
      case 'Base Model':
        return Icons.phone_iphone;
      case 'Second Phone':
        return Icons.phone_iphone_outlined;
      case 'Service':
        return Icons.build;
      default:
        return Icons.category;
    }
  }
}

// Sale Model Class
class Sale {
  final String id;
  final String type;
  final String shopName;
  final String shopId;
  final double amount;
  final DateTime date;
  final String customerName;
  final String category;
  final String itemName;
  final String? brand;
  final String? model;
  final double? profit;
  final double? costPrice;
  final double? cashAmount;
  final double? cardAmount;
  final double? gpayAmount;
  final double? downPayment;
  final String? financeType;
  final String? purchaseMode;
  final String? salesPersonName;
  final String? salesPersonEmail;
  final String? customerPhone;
  final String? imei;
  final String? defect;
  final double? discount;
  final double? exchangeValue;
  final double? amountToPay;
  final double? balanceReturnedToCustomer;
  final double? customerCredit;
  final DateTime? addedAt;

  Sale({
    required this.id,
    required this.type,
    required this.shopName,
    required this.shopId,
    required this.amount,
    required this.date,
    required this.customerName,
    required this.category,
    required this.itemName,
    this.brand,
    this.model,
    this.profit,
    this.costPrice,
    this.cashAmount,
    this.cardAmount,
    this.gpayAmount,
    this.downPayment,
    this.financeType,
    this.purchaseMode,
    this.salesPersonName,
    this.salesPersonEmail,
    this.customerPhone,
    this.imei,
    this.defect,
    this.discount,
    this.exchangeValue,
    this.amountToPay,
    this.balanceReturnedToCustomer,
    this.customerCredit,
    this.addedAt,
  });
}

// Category Details Screen
class CategoryDetailsScreen extends StatelessWidget {
  final String category;
  final List<Sale> sales;
  final String Function(double) formatNumber;
  final Color Function(String) getCategoryColor;

  CategoryDetailsScreen({
    required this.category,
    required this.sales,
    required this.formatNumber,
    required this.getCategoryColor,
  });

  @override
  Widget build(BuildContext context) {
    List<Sale> categorySales = sales
        .where((sale) => sale.category == category)
        .toList();

    // Group by shop
    Map<String, List<Sale>> shopWiseSales = {};
    for (var sale in categorySales) {
      if (!shopWiseSales.containsKey(sale.shopName)) {
        shopWiseSales[sale.shopName] = [];
      }
      shopWiseSales[sale.shopName]!.add(sale);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$category Details'),
        backgroundColor: Color(0xFF0A4D2E),
        elevation: 2,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Summary Card
            Container(
              padding: EdgeInsets.all(16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Total Sales',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '₹${formatNumber(categorySales.fold(0.0, (sum, sale) => sum + sale.amount))}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A4D2E),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'Total Sales Count',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${categorySales.length}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A7D4A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Shop-wise breakdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Shop-wise Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A4D2E),
                ),
              ),
            ),
            SizedBox(height: 8),
            ...shopWiseSales.entries.map((entry) {
              String shopName = entry.key;
              List<Sale> shopSales = entry.value;
              double shopTotal = shopSales.fold(
                0.0,
                (sum, sale) => sum + sale.amount,
              );
              double shopProfit = shopSales.fold(
                0.0,
                (sum, sale) => sum + (sale.profit ?? 0.0),
              );

              return Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              shopName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFF1A7D4A).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${shopSales.length} sales',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1A7D4A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total: ₹${formatNumber(shopTotal)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0A4D2E),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Profit: ₹${formatNumber(shopProfit)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Avg: ₹${formatNumber(shopTotal / shopSales.length)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// Shop Wise Details Screen
class ShopWiseDetailsScreen extends StatelessWidget {
  final List<Sale> sales;
  final String Function(double) formatNumber;
  final Color Function(String) getCategoryColor;

  ShopWiseDetailsScreen({
    required this.sales,
    required this.formatNumber,
    required this.getCategoryColor,
  });

  @override
  Widget build(BuildContext context) {
    // Group by shop
    Map<String, List<Sale>> shopWiseSales = {};
    for (var sale in sales) {
      if (!shopWiseSales.containsKey(sale.shopName)) {
        shopWiseSales[sale.shopName] = [];
      }
      shopWiseSales[sale.shopName]!.add(sale);
    }

    // Calculate shop totals
    Map<String, Map<String, dynamic>> shopTotals = {};
    shopWiseSales.forEach((shopName, salesList) {
      double totalSales = salesList.fold(0.0, (sum, sale) => sum + sale.amount);
      double totalProfit = salesList.fold(
        0.0,
        (sum, sale) => sum + (sale.profit ?? 0.0),
      );
      int transactionCount = salesList.length;
      double averageSale = totalSales / transactionCount;

      // Group by category within shop
      Map<String, double> categorySales = {};
      Map<String, int> categoryCount = {};
      for (var sale in salesList) {
        categorySales[sale.category] =
            (categorySales[sale.category] ?? 0.0) + sale.amount;
        categoryCount[sale.category] = (categoryCount[sale.category] ?? 0) + 1;
      }

      shopTotals[shopName] = {
        'totalSales': totalSales,
        'totalProfit': totalProfit,
        'transactionCount': transactionCount,
        'averageSale': averageSale,
        'categorySales': categorySales,
        'categoryCount': categoryCount,
      };
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Shop-wise Details'),
        backgroundColor: Color(0xFF0A4D2E),
        elevation: 2,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Summary
            Container(
              padding: EdgeInsets.all(16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Total Shops',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${shopWiseSales.length}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A4D2E),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Total Transactions',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${sales.length}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A7D4A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Total Sales',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '₹${formatNumber(sales.fold(0.0, (sum, sale) => sum + sale.amount))}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A4D2E),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Total Profit',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '₹${formatNumber(sales.fold(0.0, (sum, sale) => sum + (sale.profit ?? 0.0)))}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Shop Details
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Shop Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A4D2E),
                ),
              ),
            ),
            SizedBox(height: 8),
            ...shopTotals.entries.map((entry) {
              String shopName = entry.key;
              var data = entry.value;

              return Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    leading: Icon(Icons.store, color: Color(0xFF1A7D4A)),
                    title: Text(
                      shopName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      '${data['transactionCount']} transactions',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      '₹${formatNumber(data['totalSales'])}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                        fontSize: 16,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Profit:'),
                                Text(
                                  '₹${formatNumber(data['totalProfit'])}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Avg Sale:'),
                                Text(
                                  '₹${formatNumber(data['averageSale'])}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Divider(),
                            SizedBox(height: 8),
                            Text(
                              'Category Breakdown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A4D2E),
                              ),
                            ),
                            SizedBox(height: 8),
                            ...(data['categorySales'] as Map<String, double>)
                                .entries
                                .map((categoryEntry) {
                                  String category = categoryEntry.key;
                                  double amount = categoryEntry.value;
                                  int count =
                                      (data['categoryCount']
                                          as Map<String, int>)[category] ??
                                      0;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: getCategoryColor(
                                                  category,
                                                ).withOpacity(0.8),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(category),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              '₹${formatNumber(amount)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Color(
                                                  0xFF1A7D4A,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '$count',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF1A7D4A),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// Phone Sales Details Screen
class PhoneSalesDetailsScreen extends StatefulWidget {
  final List<Sale> allSales;
  final String Function(double) formatNumber;

  PhoneSalesDetailsScreen({required this.allSales, required this.formatNumber});

  @override
  _PhoneSalesDetailsScreenState createState() =>
      _PhoneSalesDetailsScreenState();
}

class _PhoneSalesDetailsScreenState extends State<PhoneSalesDetailsScreen> {
  List<Sale> _phoneSales = [];
  String? _selectedBrand;
  String? _selectedShop;
  String? _selectedFinanceType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _sortAscending = false;
  String _sortColumn = 'date';

  @override
  void initState() {
    super.initState();
    _filterPhoneSales();
  }

  void _filterPhoneSales() {
    setState(() {
      _phoneSales = widget.allSales
          .where((sale) => sale.type == 'phone_sale')
          .where(
            (sale) => _selectedBrand == null || sale.brand == _selectedBrand,
          )
          .where(
            (sale) => _selectedShop == null || sale.shopName == _selectedShop,
          )
          .where(
            (sale) =>
                _selectedFinanceType == null ||
                sale.financeType == _selectedFinanceType,
          )
          .where((sale) {
            if (_startDate == null && _endDate == null) return true;
            if (_startDate != null && sale.date.isBefore(_startDate!))
              return false;
            if (_endDate != null && sale.date.isAfter(_endDate!)) return false;
            return true;
          })
          .toList();

      // Sort the list
      _phoneSales.sort((a, b) {
        int result;
        switch (_sortColumn) {
          case 'customerName':
            result = a.customerName.compareTo(b.customerName);
            break;
          case 'date':
            result = a.date.compareTo(b.date);
            break;
          case 'amount':
            result = a.amount.compareTo(b.amount);
            break;
          case 'brand':
            result = (a.brand ?? '').compareTo(b.brand ?? '');
            break;
          default:
            result = a.date.compareTo(b.date);
        }
        return _sortAscending ? result : -result;
      });
    });
  }

  List<String> _getUniqueBrands() {
    Set<String> brands = {};
    for (var sale in widget.allSales.where((s) => s.type == 'phone_sale')) {
      if (sale.brand != null && sale.brand!.isNotEmpty) {
        brands.add(sale.brand!);
      }
    }
    return brands.toList()..sort();
  }

  List<String> _getUniqueShops() {
    Set<String> shops = {};
    for (var sale in widget.allSales.where((s) => s.type == 'phone_sale')) {
      shops.add(sale.shopName);
    }
    return shops.toList()..sort();
  }

  List<String> _getUniqueFinanceTypes() {
    Set<String> types = {};
    for (var sale in widget.allSales.where((s) => s.type == 'phone_sale')) {
      if (sale.financeType != null && sale.financeType!.isNotEmpty) {
        types.add(sale.financeType!);
      }
    }
    return types.toList()..sort();
  }

  double _calculateTotalAmount() {
    return _phoneSales.fold(0.0, (sum, sale) => sum + sale.amount);
  }

  double _calculateTotalProfit() {
    return _phoneSales.fold(0.0, (sum, sale) => sum + (sale.profit ?? 0));
  }

  Color _getStatusColor(String purchaseMode) {
    switch (purchaseMode?.toLowerCase()) {
      case 'emi':
        return Color(0xFF2196F3);
      case 'cash':
        return Color(0xFF4CAF50);
      case 'card':
        return Color(0xFF9C27B0);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Phone Sales Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        elevation: 2,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt),
            color: Colors.white,
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: Icon(Icons.bar_chart),
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PhoneSalesReportsScreen(
                    allSales: widget.allSales,
                    phoneSales: _phoneSales,
                    formatNumber: widget.formatNumber,
                  ),
                ),
              );
            },
            tooltip: 'Reports',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            padding: EdgeInsets.all(16),
            color: Color(0xFFE8F5E9),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Total Sales',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '₹${widget.formatNumber(_calculateTotalAmount())}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Total Profit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '₹${widget.formatNumber(_calculateTotalProfit())}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Transactions',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${_phoneSales.length}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Active Filters
          if (_selectedBrand != null ||
              _selectedShop != null ||
              _selectedFinanceType != null ||
              _startDate != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedBrand != null)
                    Chip(
                      label: Text('Brand: $_selectedBrand'),
                      onDeleted: () {
                        setState(() {
                          _selectedBrand = null;
                        });
                        _filterPhoneSales();
                      },
                    ),
                  if (_selectedShop != null)
                    Chip(
                      label: Text('Shop: $_selectedShop'),
                      onDeleted: () {
                        setState(() {
                          _selectedShop = null;
                        });
                        _filterPhoneSales();
                      },
                    ),
                  if (_selectedFinanceType != null)
                    Chip(
                      label: Text('Finance: $_selectedFinanceType'),
                      onDeleted: () {
                        setState(() {
                          _selectedFinanceType = null;
                        });
                        _filterPhoneSales();
                      },
                    ),
                  if (_startDate != null)
                    Chip(
                      label: Text(
                        'From: ${DateFormat('dd-MMM-yyyy').format(_startDate!)}',
                      ),
                      onDeleted: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                        _filterPhoneSales();
                      },
                    ),
                ],
              ),
            ),

          // Sales List
          Expanded(
            child: _phoneSales.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone_iphone,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No phone sales found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try changing your filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _phoneSales.length,
                    itemBuilder: (context, index) {
                      final sale = _phoneSales[index];
                      return _buildSaleCard(sale);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Sale sale) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    sale.customerName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A4D2E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(sale.purchaseMode ?? ''),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    sale.purchaseMode ?? 'Unknown',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  sale.customerPhone ?? 'No phone',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.branding_watermark,
                  size: 16,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 8),
                Text(
                  '${sale.brand ?? 'Unknown'} - ${sale.model ?? 'Unknown'}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(height: 1),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sale Amount',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '₹${widget.formatNumber(sale.amount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Profit',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '₹${widget.formatNumber(sale.profit ?? 0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finance Type',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      sale.financeType ?? 'Cash',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Shop',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      sale.shopName,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Down Payment',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '₹${widget.formatNumber(sale.downPayment ?? 0)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy').format(sale.date),
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            if (sale.imei != null && sale.imei!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IMEI: ${sale.imei}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            SizedBox(height: 4),
            if (sale.addedAt != null)
              Text(
                'Added: ${DateFormat('dd MMM yyyy HH:mm').format(sale.addedAt!)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            SizedBox(height: 2),
            Text(
              'Sales Person: ${sale.salesPersonEmail ?? sale.salesPersonName ?? 'Unknown'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    List<String> brands = _getUniqueBrands();
    List<String> shops = _getUniqueShops();
    List<String> financeTypes = _getUniqueFinanceTypes();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filter Phone Sales'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterDropdown('Brand', _selectedBrand, brands, (
                      value,
                    ) {
                      setState(() {
                        _selectedBrand = value;
                      });
                    }),
                    SizedBox(height: 16),
                    _buildFilterDropdown('Shop', _selectedShop, shops, (value) {
                      setState(() {
                        _selectedShop = value;
                      });
                    }),
                    SizedBox(height: 16),
                    _buildFilterDropdown(
                      'Finance Type',
                      _selectedFinanceType,
                      financeTypes,
                      (value) {
                        setState(() {
                          _selectedFinanceType = value;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    _buildDateRangeFilter(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedBrand = null;
                      _selectedShop = null;
                      _selectedFinanceType = null;
                      _startDate = null;
                      _endDate = null;
                    });
                    _filterPhoneSales();
                    Navigator.pop(context);
                  },
                  child: Text('Clear All'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _filterPhoneSales();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0A4D2E),
                  ),
                  child: Text('Apply Filters'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String? currentValue,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              hint: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Select $label'),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('All $label'),
                  ),
                ),
                ...items.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(item),
                    ),
                  );
                }).toList(),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Range',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _startDate = date;
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 8),
                      Text(
                        _startDate == null
                            ? 'Start Date'
                            : DateFormat('dd-MMM-yyyy').format(_startDate!),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: _startDate ?? DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 8),
                      Text(
                        _endDate == null
                            ? 'End Date'
                            : DateFormat('dd-MMM-yyyy').format(_endDate!),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Phone Sales Reports Screen
class PhoneSalesReportsScreen extends StatelessWidget {
  final List<Sale> allSales;
  final List<Sale> phoneSales;
  final String Function(double) formatNumber;

  PhoneSalesReportsScreen({
    required this.allSales,
    required this.phoneSales,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Phone Sales Reports',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xFF0A4D2E),
          elevation: 2,
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Brand Wise'),
              Tab(text: 'Shop Wise'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildBrandWiseReport(), _buildShopWiseReport()],
        ),
      ),
    );
  }

  Widget _buildBrandWiseReport() {
    // Group by brand
    Map<String, List<Sale>> brandGroups = {};
    for (var sale in phoneSales) {
      String brand = sale.brand ?? 'Unknown';
      if (!brandGroups.containsKey(brand)) {
        brandGroups[brand] = [];
      }
      brandGroups[brand]!.add(sale);
    }

    // Calculate totals
    List<Map<String, dynamic>> brandData = [];
    brandGroups.forEach((brand, sales) {
      double totalAmount = sales.fold(0.0, (sum, s) => sum + s.amount);
      double totalProfit = sales.fold(0.0, (sum, s) => sum + (s.profit ?? 0));
      int count = sales.length;
      double avgSale = count > 0 ? totalAmount / count : 0;
      double profitMargin = totalAmount > 0
          ? (totalProfit / totalAmount) * 100
          : 0;

      brandData.add({
        'brand': brand,
        'totalAmount': totalAmount,
        'totalProfit': totalProfit,
        'count': count,
        'avgSale': avgSale,
        'profitMargin': profitMargin,
      });
    });

    // Sort by total amount (highest first)
    brandData.sort((a, b) => b['totalAmount'].compareTo(a['totalAmount']));

    double totalAllSales = brandData.fold(
      0.0,
      (sum, item) => sum + item['totalAmount'],
    );
    double totalAllProfit = brandData.fold(
      0.0,
      (sum, item) => sum + item['totalProfit'],
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary
          Container(
            padding: EdgeInsets.all(16),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Brand Performance Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard(
                          'Total Brands',
                          '${brandData.length}',
                          Icons.branding_watermark,
                          Color(0xFF2196F3),
                        ),
                        _buildStatCard(
                          'Total Sales',
                          '₹${formatNumber(totalAllSales)}',
                          Icons.currency_rupee,
                          Color(0xFF4CAF50),
                        ),
                        _buildStatCard(
                          'Total Profit',
                          '₹${formatNumber(totalAllProfit)}',
                          Icons.trending_up,
                          Color(0xFF9C27B0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Brand List
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Brand-wise Performance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A4D2E),
              ),
            ),
          ),
          SizedBox(height: 8),
          ...brandData.map((brand) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              brand['brand'],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A4D2E),
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${brand['count']} sales',
                              style: TextStyle(
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Sales',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '₹${formatNumber(brand['totalAmount'])}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A4D2E),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Avg. Sale',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '₹${formatNumber(brand['avgSale'])}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Profit Margin',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${brand['profitMargin'].toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: brand['profitMargin'] > 15
                                      ? Colors.green
                                      : brand['profitMargin'] > 10
                                      ? Colors.orange
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Profit: ₹${formatNumber(brand['totalProfit'])}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildShopWiseReport() {
    // Group by shop, then by brand within each shop
    Map<String, Map<String, List<Sale>>> shopBrandGroups = {};

    for (var sale in phoneSales) {
      String shop = sale.shopName;
      String brand = sale.brand ?? 'Unknown';

      if (!shopBrandGroups.containsKey(shop)) {
        shopBrandGroups[shop] = {};
      }
      if (!shopBrandGroups[shop]!.containsKey(brand)) {
        shopBrandGroups[shop]![brand] = [];
      }
      shopBrandGroups[shop]![brand]!.add(sale);
    }

    // Calculate shop totals
    List<Map<String, dynamic>> shopData = [];
    shopBrandGroups.forEach((shop, brandMap) {
      double shopTotal = 0;
      double shopProfit = 0;
      int shopCount = 0;

      List<Map<String, dynamic>> brandsInShop = [];

      brandMap.forEach((brand, sales) {
        double brandTotal = sales.fold(0.0, (sum, s) => sum + s.amount);
        double brandProfit = sales.fold(0.0, (sum, s) => sum + (s.profit ?? 0));
        int brandCount = sales.length;

        shopTotal += brandTotal;
        shopProfit += brandProfit;
        shopCount += brandCount;

        brandsInShop.add({
          'brand': brand,
          'total': brandTotal,
          'profit': brandProfit,
          'count': brandCount,
        });
      });

      // Sort brands within shop by total (highest first)
      brandsInShop.sort((a, b) => b['total'].compareTo(a['total']));

      shopData.add({
        'shop': shop,
        'total': shopTotal,
        'profit': shopProfit,
        'count': shopCount,
        'brands': brandsInShop,
      });
    });

    // Sort shops by total (highest first)
    shopData.sort((a, b) => b['total'].compareTo(a['total']));

    double totalAllSales = shopData.fold(
      0.0,
      (sum, item) => sum + item['total'],
    );
    double totalAllProfit = shopData.fold(
      0.0,
      (sum, item) => sum + item['profit'],
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary
          Container(
            padding: EdgeInsets.all(16),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Shop Performance Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard(
                          'Total Shops',
                          '${shopData.length}',
                          Icons.store,
                          Color(0xFF2196F3),
                        ),
                        _buildStatCard(
                          'Total Sales',
                          '₹${formatNumber(totalAllSales)}',
                          Icons.currency_rupee,
                          Color(0xFF4CAF50),
                        ),
                        _buildStatCard(
                          'Avg/Shop',
                          '₹${formatNumber(shopData.isNotEmpty ? totalAllSales / shopData.length : 0)}',
                          Icons.assessment,
                          Color(0xFF9C27B0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Shop List
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Shop-wise Performance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A4D2E),
              ),
            ),
          ),
          SizedBox(height: 8),
          ...shopData.map((shop) {
            double shopMargin = shop['total'] > 0
                ? (shop['profit'] / shop['total']) * 100
                : 0;

            return Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  leading: Icon(Icons.store, color: Color(0xFF1A7D4A)),
                  title: Text(
                    shop['shop'],
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    '${shop['count']} sales • ${shop['brands'].length} brands',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${formatNumber(shop['total'])}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A4D2E),
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Profit: ₹${formatNumber(shop['profit'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          // Shop summary
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Shop Summary',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0A4D2E),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Avg. Sale: ₹${formatNumber(shop['total'] / shop['count'])}',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Margin',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${shopMargin.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: shopMargin > 15
                                            ? Colors.green
                                            : shopMargin > 10
                                            ? Colors.orange
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),

                          // Brands within this shop
                          Text(
                            'Brands in this Shop',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A4D2E),
                            ),
                          ),
                          SizedBox(height: 8),
                          ...(shop['brands'] as List<Map<String, dynamic>>).map((
                            brand,
                          ) {
                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[200]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      brand['brand'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${formatNumber(brand['total'])}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0A4D2E),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            '${brand['count']} sales',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '₹${formatNumber(brand['profit'])} profit',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF4CAF50),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }
}
