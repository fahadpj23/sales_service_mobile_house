import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:sales_stock/screens/login_screen.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DateTime _selectedDate = DateTime.now();
  String _timePeriod = 'monthly';
  bool _isLoading = true;
  final authService = AuthService();

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
  final CollectionReference shopsCollection = FirebaseFirestore.instance
      .collection('Mobile_house_Shops');

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

        final totalAmount = (data['totalSaleAmount'] ?? 0).toDouble();

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
      final snapshot = await shopsCollection.get();

      shops.clear();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        shops.add({
          'id': doc.id,
          'name': data['shopName'] ?? 'Unknown Shop',
          'address': data['address'] ?? '',
          'manager': data['managerName'] ?? '',
        });
      }

      // Sort shops by name
      shops.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );
    } catch (e) {
      print('Error fetching shops: $e');
      // Fallback to default shops if collection doesn't exist
      shops = [
        {
          'id': 'Mk9k3DiuelPsEbE0MCqQ',
          'name': 'MobileHouse1(shed)',
          'address': 'Shed Area',
          'manager': 'Manager 1',
        },
        {
          'id': 'BrqQtjE0Uo9mCYcUSiK3',
          'name': 'MobileHouse2(3way)',
          'address': '3-way Junction',
          'manager': 'Manager 2',
        },
      ];
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
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed: _fetchAllData,
                tooltip: 'Refresh Data',
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                color: _isLoading ? Colors.grey : Colors.white,
                onPressed: () async {
                  await authService.signOut();
                  Provider.of<AuthProvider>(context, listen: false).clearUser();
                },
              ),
            ],
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
    List<Sale> filteredSales = _filterSales();

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: secondaryGreen,
      backgroundColor: lightGreen,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(),
            _buildTimePeriodSelector(),
            _buildKPIStats(filteredSales),
            _buildPerformanceInsights(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    List<Sale> filteredSales = _filterSales();
    double totalSales = _calculateTotalSales();

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
                      _getPeriodLabel(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '₹${_formatNumber(totalSales)}',
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
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePeriodSelector() {
    List<Map<String, dynamic>> periods = [
      {'label': 'Daily', 'icon': Icons.today, 'value': 'daily'},
      {'label': 'Yesterday', 'icon': Icons.history, 'value': 'yesterday'},
      {
        'label': 'Last Month',
        'icon': Icons.calendar_view_month,
        'value': 'last_month',
      },
      {'label': 'Monthly', 'icon': Icons.calendar_month, 'value': 'monthly'},
      {'label': 'Yearly', 'icon': Icons.calendar_today, 'value': 'yearly'},
    ];

    return Container(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Time Period',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: periods.map((period) {
                  bool isSelected = _timePeriod == period['value'];
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          period['icon'],
                          size: 16,
                          color: isSelected ? Colors.white : secondaryGreen,
                        ),
                        SizedBox(width: 4),
                        Text(
                          period['label'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _timePeriod = period['value'];
                      });
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: secondaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPIStats(List<Sale> filteredSales) {
    double totalSales = _calculateTotalSales();
    int transactionCount = filteredSales.length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildKPIStatCard(
            'Total Sales',
            '₹${_formatNumber(totalSales)}',
            Icons.currency_rupee,
            primaryGreen,
          ),

          _buildKPIStatCard(
            'Transactions',
            '$transactionCount',
            Icons.receipt,
            Color(0xFF9C27B0),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
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

    for (var sale in filteredSales) {
      categoryPerformance[sale.category] =
          (categoryPerformance[sale.category] ?? 0.0) + sale.amount;
      categoryCount[sale.category] = (categoryCount[sale.category] ?? 0) + 1;
    }

    // Get total sales for percentage calculation
    double totalSales = _calculateTotalSales();

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
                                          '$count transactions',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
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

          // Specific Reports
          Divider(height: 1),
          // Shop Reports
          Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'SHOP REPORTS',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildDrawerItem(
            Icons.store,
            'Shop-wise Report',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShopWiseReportScreen(
                    allSales: allSales,
                    shops: shops,
                    formatNumber: _formatNumber,
                    getCategoryColor: _getCategoryColor,
                  ),
                ),
              );
            },
          ),
          Divider(height: 1),
          // Category Reports
          Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'CATEGORY REPORTS',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
          Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'SPECIFIC REPORTS',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildDrawerItem(
            Icons.today,
            'Daily Report',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SpecificReportScreen(
                    title: 'Daily Report',
                    timePeriod: 'daily',
                    allSales: allSales,
                    formatNumber: _formatNumber,
                    shops: shops,
                    getCategoryColor: _getCategoryColor,
                  ),
                ),
              );
            },
          ),
          _buildDrawerItem(
            Icons.history,
            'Yesterday Report',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SpecificReportScreen(
                    title: 'Yesterday Report',
                    timePeriod: 'yesterday',
                    allSales: allSales,
                    formatNumber: _formatNumber,
                    shops: shops,
                    getCategoryColor: _getCategoryColor,
                  ),
                ),
              );
            },
          ),
          _buildDrawerItem(
            Icons.calendar_view_month,
            'Last Month Report',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SpecificReportScreen(
                    title: 'Last Month Report',
                    timePeriod: 'last_month',
                    allSales: allSales,
                    formatNumber: _formatNumber,
                    shops: shops,
                    getCategoryColor: _getCategoryColor,
                  ),
                ),
              );
            },
          ),
          _buildDrawerItem(
            Icons.calendar_month,
            'Monthly Report',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SpecificReportScreen(
                    title: 'Monthly Report',
                    timePeriod: 'monthly',
                    allSales: allSales,
                    formatNumber: _formatNumber,
                    shops: shops,
                    getCategoryColor: _getCategoryColor,
                  ),
                ),
              );
            },
          ),
          _buildDrawerItem(
            Icons.calendar_today,
            'Yearly Report',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SpecificReportScreen(
                    title: 'Yearly Report',
                    timePeriod: 'yearly',
                    allSales: allSales,
                    formatNumber: _formatNumber,
                    shops: shops,
                    getCategoryColor: _getCategoryColor,
                  ),
                ),
              );
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
      dense: true,
      leading: Icon(
        icon,
        color: isSelected ? secondaryGreen : Colors.grey[700],
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? secondaryGreen : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      tileColor: isSelected ? secondaryGreen.withOpacity(0.1) : null,
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Future<void> _refreshData() async {
    await _fetchAllData();
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
      case 'yesterday':
        final yesterday = _selectedDate.subtract(Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'last_month':
        final firstDayOfLastMonth = DateTime(
          _selectedDate.year,
          _selectedDate.month - 1,
          1,
        );
        startDate = firstDayOfLastMonth;
        endDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          1,
        ).add(Duration(seconds: -1));
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
      return dateMatch;
    }).toList();
  }

  double _calculateTotalSales() {
    return _filterSales().fold(0.0, (sum, sale) => sum + sale.amount);
  }

  String _getPeriodLabel() {
    switch (_timePeriod) {
      case 'daily':
        return 'Today\'s Sale';
      case 'yesterday':
        return 'Yesterday\'s Sale';
      case 'last_month':
        return 'Last Month Sale';
      case 'monthly':
        return 'Monthly Sale';
      case 'yearly':
        return 'Yearly Sale';
      default:
        return 'Sale';
    }
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

// Specific Report Screen
class SpecificReportScreen extends StatelessWidget {
  final String title;
  final String timePeriod;
  final List<Sale> allSales;
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;
  final Color Function(String) getCategoryColor;

  SpecificReportScreen({
    required this.title,
    required this.timePeriod,
    required this.allSales,
    required this.formatNumber,
    required this.shops,
    required this.getCategoryColor,
  });

  List<Sale> _filterSalesByPeriod() {
    DateTime startDate;
    DateTime endDate;
    DateTime now = DateTime.now();

    switch (timePeriod) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'yesterday':
        final yesterday = now.subtract(Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'last_month':
        final firstDayOfLastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = firstDayOfLastMonth;
        endDate = DateTime(now.year, now.month, 1).add(Duration(seconds: -1));
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1).add(Duration(seconds: -1));
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
    }

    return allSales.where((sale) {
      return sale.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    List<Sale> filteredSales = _filterSalesByPeriod();
    double totalSales = filteredSales.fold(
      0.0,
      (sum, sale) => sum + sale.amount,
    );

    // Group by shop
    Map<String, List<Sale>> shopGroups = {};
    for (var sale in filteredSales) {
      if (!shopGroups.containsKey(sale.shopName)) {
        shopGroups[sale.shopName] = [];
      }
      shopGroups[sale.shopName]!.add(sale);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSummaryStat(
                            'Total Sales',
                            '₹${formatNumber(totalSales)}',
                            Icons.currency_rupee,
                            Color(0xFF0A4D2E),
                          ),
                          _buildSummaryStat(
                            'Transactions',
                            '${filteredSales.length}',
                            Icons.receipt,
                            Color(0xFF2196F3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Shop-wise Performance
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Shop-wise Performance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A4D2E),
                ),
              ),
            ),
            SizedBox(height: 8),

            ...shopGroups.entries.map((entry) {
              String shopName = entry.key;
              List<Sale> shopSales = entry.value;
              double shopTotal = shopSales.fold(
                0.0,
                (sum, sale) => sum + sale.amount,
              );

              // Find shop manager from shops list
              String? shopManager = '';
              for (var shop in shops) {
                if (shop['name'] == shopName) {
                  shopManager = shop['manager'];
                  break;
                }
              }

              return Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                                    shopName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (shopManager != null &&
                                      shopManager.isNotEmpty)
                                    Text(
                                      'Manager: $shopManager',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
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
                        SizedBox(height: 12),
                        Text(
                          'Sales: ₹${formatNumber(shopTotal)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),

            // Category Breakdown
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'Category Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A4D2E),
                ),
              ),
            ),

            // Category Performance
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Category stats
                      ..._getCategoryStats(filteredSales).map((category) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: getCategoryColor(
                                    category['name'],
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Icon(
                                    _getCategoryIconByName(category['name']),
                                    color: getCategoryColor(category['name']),
                                    size: 20,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${category['count']} sales • ₹${formatNumber(category['amount'])}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  List<Map<String, dynamic>> _getCategoryStats(List<Sale> sales) {
    Map<String, Map<String, dynamic>> categoryStats = {};

    for (var sale in sales) {
      if (!categoryStats.containsKey(sale.category)) {
        categoryStats[sale.category] = {
          'name': sale.category,
          'amount': 0.0,
          'count': 0,
        };
      }
      categoryStats[sale.category]!['amount'] += sale.amount;
      categoryStats[sale.category]!['count'] += 1;
    }

    List<Map<String, dynamic>> result = [];
    categoryStats.forEach((key, value) {
      result.add({
        'name': key,
        'amount': value['amount'],
        'count': value['count'],
      });
    });

    // Sort by amount (highest first)
    result.sort(
      (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
    );

    return result;
  }

  IconData _getCategoryIconByName(String category) {
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

// Shop Wise Report Screen
class ShopWiseReportScreen extends StatelessWidget {
  final List<Sale> allSales;
  final List<Map<String, dynamic>> shops;
  final String Function(double) formatNumber;
  final Color Function(String) getCategoryColor;

  ShopWiseReportScreen({
    required this.allSales,
    required this.shops,
    required this.formatNumber,
    required this.getCategoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 3,
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Shop-wise Reports',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xFF0A4D2E),
          elevation: 2,
          centerTitle: true,
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            unselectedLabelColor: Colors.grey, // Unselected tab label color
            labelStyle: TextStyle(
              fontWeight: FontWeight.normal,
              color: Colors.white,
            ),
            tabs: [
              Tab(text: 'Monthly'),
              Tab(text: 'Daily'),
              Tab(text: 'Yesterday'),
              Tab(text: 'Last Month'),
              Tab(text: 'Yearly'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildShopReport('monthly'),
            _buildShopReport('daily'),
            _buildShopReport('yesterday'),
            _buildShopReport('last_month'),
            _buildShopReport('yearly'),
          ],
        ),
      ),
    );
  }

  Widget _buildShopReport(String period) {
    List<Sale> filteredSales = _filterSalesByPeriod(period);

    // Calculate shop performance
    List<Map<String, dynamic>> shopPerformance = [];

    for (var shop in shops) {
      String shopName = shop['name'];

      // Get sales for this shop
      List<Sale> shopSales = filteredSales
          .where((sale) => sale.shopName == shopName)
          .toList();

      double totalSales = shopSales.fold(0.0, (sum, sale) => sum + sale.amount);
      int transactionCount = shopSales.length;
      double avgSale = transactionCount > 0 ? totalSales / transactionCount : 0;

      // Get category breakdown
      Map<String, double> categorySales = {};
      for (var sale in shopSales) {
        categorySales[sale.category] =
            (categorySales[sale.category] ?? 0.0) + sale.amount;
      }

      shopPerformance.add({
        'shop': shop,
        'totalSales': totalSales,
        'transactionCount': transactionCount,
        'avgSale': avgSale,
        'categorySales': categorySales,
      });
    }

    // Sort by total sales (highest first)
    shopPerformance.sort((a, b) => b['totalSales'].compareTo(a['totalSales']));

    double totalAllSales = shopPerformance.fold(
      0.0,
      (sum, item) => sum + item['totalSales'],
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
                      '${_getPeriodLabel(period)} Shop Performance',
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
                        _buildReportStat(
                          'Total Shops',
                          '${shops.length}',
                          Icons.store,
                          Color(0xFF2196F3),
                        ),
                        _buildReportStat(
                          'Total Sales',
                          '₹${formatNumber(totalAllSales)}',
                          Icons.currency_rupee,
                          Color(0xFF4CAF50),
                        ),
                        _buildReportStat(
                          'Avg/Shop',
                          '₹${formatNumber(shopPerformance.isNotEmpty ? totalAllSales / shopPerformance.length : 0)}',
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
          ...shopPerformance.map((performance) {
            var shop = performance['shop'] as Map<String, dynamic>;
            String shopName = shop['name'];
            String shopManager = shop['manager'] ?? '';
            String shopAddress = shop['address'] ?? '';

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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$shopManager • $shopAddress',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${performance['transactionCount']} transactions',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${formatNumber(performance['totalSales'])}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A4D2E),
                          fontSize: 16,
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
                                      'Avg. Sale: ₹${formatNumber(performance['avgSale'])}',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),

                          // Brands within this shop
                          if ((performance['categorySales']
                                  as Map<String, double>)
                              .isNotEmpty)
                            Column(
                              children: [
                                Text(
                                  'Category Breakdown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0A4D2E),
                                  ),
                                ),
                                SizedBox(height: 8),
                                ...(performance['categorySales']
                                        as Map<String, double>)
                                    .entries
                                    .map((entry) {
                                      String category = entry.key;
                                      double amount = entry.value;

                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: getCategoryColor(
                                                  category,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                category,
                                                style: TextStyle(fontSize: 14),
                                              ),
                                            ),
                                            Text(
                                              '₹${formatNumber(amount)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    })
                                    .toList(),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReportStat(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildPerformanceStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A4D2E),
          ),
        ),
        SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  List<Sale> _filterSalesByPeriod(String period) {
    DateTime startDate;
    DateTime endDate;
    DateTime now = DateTime.now();

    switch (period) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'yesterday':
        final yesterday = now.subtract(Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'last_month':
        final firstDayOfLastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = firstDayOfLastMonth;
        endDate = DateTime(now.year, now.month, 1).add(Duration(seconds: -1));
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1).add(Duration(seconds: -1));
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
    }

    return allSales.where((sale) {
      return sale.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
    }).toList();
  }

  String _getPeriodLabel(String period) {
    switch (period) {
      case 'daily':
        return 'Daily';
      case 'yesterday':
        return 'Yesterday';
      case 'last_month':
        return 'Last Month';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return 'Period';
    }
  }
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
class PhoneSalesReportsScreen extends StatefulWidget {
  final List<Sale> allSales;
  final List<Sale> phoneSales;
  final String Function(double) formatNumber;

  PhoneSalesReportsScreen({
    required this.allSales,
    required this.phoneSales,
    required this.formatNumber,
  });

  @override
  _PhoneSalesReportsScreenState createState() =>
      _PhoneSalesReportsScreenState();
}

class _PhoneSalesReportsScreenState extends State<PhoneSalesReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Sale> _filteredPhoneSales = [];
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Time periods
  final List<String> _timePeriods = [
    'today',
    'yesterday',
    'monthly',
    'last_monthly',
    'yearly',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: 2,
    ); // Default to monthly
    _filteredPhoneSales = _filterByTimePeriod('monthly');
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _handleTabChange(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange(int index) {
    final period = _timePeriods[index];
    if (period == 'custom') {
      _showCustomDateRangePicker();
    } else {
      setState(() {
        _filteredPhoneSales = _filterByTimePeriod(period);
      });
    }
  }

  List<Sale> _filterByTimePeriod(String period) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (period) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'yesterday':
        final yesterday = now.subtract(Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = startDate.add(Duration(days: 1, seconds: -1));
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
        break;
      case 'last_monthly':
        final firstDayOfLastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = firstDayOfLastMonth;
        endDate = DateTime(now.year, now.month, 1).add(Duration(seconds: -1));
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1).add(Duration(seconds: -1));
        break;
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          startDate = _customStartDate!;
          endDate = _customEndDate!.add(Duration(days: 1, seconds: -1));
        } else {
          // Default to monthly if no custom date selected
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(
            now.year,
            now.month + 1,
            1,
          ).add(Duration(seconds: -1));
        }
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
    }

    return widget.phoneSales.where((sale) {
      return sale.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
    }).toList();
  }

  Future<void> _showCustomDateRangePicker() async {
    final DateTime? start = await showDatePicker(
      context: context,
      initialDate: _customStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Color(0xFF0A4D2E),
            colorScheme: ColorScheme.light(primary: Color(0xFF0A4D2E)),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (start != null) {
      final DateTime? end = await showDatePicker(
        context: context,
        initialDate: _customEndDate ?? start,
        firstDate: start,
        lastDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              primaryColor: Color(0xFF0A4D2E),
              colorScheme: ColorScheme.light(primary: Color(0xFF0A4D2E)),
              buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
            ),
            child: child!,
          );
        },
      );

      if (end != null) {
        setState(() {
          _customStartDate = start;
          _customEndDate = end;
          _filteredPhoneSales = _filterByTimePeriod('custom');
        });
      }
    }
  }

  String _getPeriodLabel(String period) {
    switch (period) {
      case 'today':
        return 'Today';
      case 'yesterday':
        return 'Yesterday';
      case 'monthly':
        return 'Monthly';
      case 'last_monthly':
        return 'Last Month';
      case 'yearly':
        return 'Yearly';
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          return '${DateFormat('dd MMM').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}';
        }
        return 'Custom';
      default:
        return 'Monthly';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Phone Sales Reports',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        elevation: 2,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: [
            Tab(text: 'Today'),
            Tab(text: 'Yesterday'),
            Tab(text: 'Monthly'),
            Tab(text: 'Last Month'),
            Tab(text: 'Yearly'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 16),
                  SizedBox(width: 4),
                  Text('Custom'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportView(),
          _buildReportView(),
          _buildReportView(),
          _buildReportView(),
          _buildReportView(),
          _buildReportView(),
        ],
      ),
    );
  }

  Widget _buildReportView() {
    final period = _timePeriods[_tabController.index];
    final periodLabel = _getPeriodLabel(period);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Period Summary Card
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
                child: Column(
                  children: [
                    Text(
                      periodLabel,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryStat(
                          'Total Sales',
                          '₹${widget.formatNumber(_filteredPhoneSales.fold(0.0, (sum, sale) => sum + sale.amount))}',
                          Icons.currency_rupee,
                          Color(0xFF0A4D2E),
                        ),
                        _buildSummaryStat(
                          'Transactions',
                          '${_filteredPhoneSales.length}',
                          Icons.receipt,
                          Color(0xFF2196F3),
                        ),
                        _buildSummaryStat(
                          'Avg Sale',
                          _filteredPhoneSales.isNotEmpty
                              ? '₹${widget.formatNumber(_filteredPhoneSales.fold(0.0, (sum, sale) => sum + sale.amount) / _filteredPhoneSales.length)}'
                              : '₹0',
                          Icons.trending_up,
                          Color(0xFF4CAF50),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Brand Wise & Shop Wise Tabs
          Container(
            color: Color(0xFF0A4D2E),
            child: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'Brand Wise'),
                Tab(text: 'Shop Wise'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              children: [_buildBrandWiseReport(), _buildShopWiseReport()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildBrandWiseReport() {
    if (_filteredPhoneSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_iphone, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No phone sales data',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Try selecting a different time period',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Group by brand
    Map<String, List<Sale>> brandGroups = {};
    for (var sale in _filteredPhoneSales) {
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
      int count = sales.length;
      double avgSale = count > 0 ? totalAmount / count : 0;

      brandData.add({
        'brand': brand,
        'totalAmount': totalAmount,
        'count': count,
        'avgSale': avgSale,
      });
    });

    // Sort by total amount (highest first)
    brandData.sort((a, b) => b['totalAmount'].compareTo(a['totalAmount']));

    double totalAllSales = brandData.fold(
      0.0,
      (sum, item) => sum + item['totalAmount'],
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          // Brand Performance Summary
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
                      'Brand Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniStatCard(
                          'Brands',
                          '${brandData.length}',
                          Icons.branding_watermark,
                          Color(0xFF2196F3),
                        ),
                        _buildMiniStatCard(
                          'Total Sales',
                          '₹${widget.formatNumber(totalAllSales)}',
                          Icons.currency_rupee,
                          Color(0xFF4CAF50),
                        ),
                        _buildMiniStatCard(
                          'Avg/Brand',
                          '₹${widget.formatNumber(brandData.isNotEmpty ? totalAllSales / brandData.length : 0)}',
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

          // Brand List
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
                                '₹${widget.formatNumber(brand['totalAmount'])}',
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
                                'Avg. Sale',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '₹${widget.formatNumber(brand['avgSale'])}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: brandData.isNotEmpty
                            ? brand['totalAmount'] / totalAllSales
                            : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF4CAF50),
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),

          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildShopWiseReport() {
    if (_filteredPhoneSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No shop sales data',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Try selecting a different time period',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Group by shop, then by brand within each shop
    Map<String, Map<String, List<Sale>>> shopBrandGroups = {};

    for (var sale in _filteredPhoneSales) {
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
      int shopCount = 0;

      List<Map<String, dynamic>> brandsInShop = [];

      brandMap.forEach((brand, sales) {
        double brandTotal = sales.fold(0.0, (sum, s) => sum + s.amount);
        int brandCount = sales.length;

        shopTotal += brandTotal;
        shopCount += brandCount;

        brandsInShop.add({
          'brand': brand,
          'total': brandTotal,
          'count': brandCount,
        });
      });

      // Sort brands within shop by total (highest first)
      brandsInShop.sort((a, b) => b['total'].compareTo(a['total']));

      shopData.add({
        'shop': shop,
        'total': shopTotal,
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

    return SingleChildScrollView(
      child: Column(
        children: [
          // Shop Performance Summary
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
                      'Shop Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniStatCard(
                          'Shops',
                          '${shopData.length}',
                          Icons.store,
                          Color(0xFF2196F3),
                        ),
                        _buildMiniStatCard(
                          'Total Sales',
                          '₹${widget.formatNumber(totalAllSales)}',
                          Icons.currency_rupee,
                          Color(0xFF4CAF50),
                        ),
                        _buildMiniStatCard(
                          'Avg/Shop',
                          '₹${widget.formatNumber(shopData.isNotEmpty ? totalAllSales / shopData.length : 0)}',
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
          ...shopData.map((shop) {
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
                        '₹${widget.formatNumber(shop['total'])}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A4D2E),
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${shop['count']} sales',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w600,
                          ),
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
                                      'Avg. Sale: ₹${widget.formatNumber(shop['total'] / shop['count'])}',
                                      style: TextStyle(fontSize: 12),
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
                                        '₹${widget.formatNumber(brand['total'])}',
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

  Widget _buildMiniStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
      ],
    );
  }
}
