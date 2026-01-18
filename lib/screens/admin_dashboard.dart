import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      // Clear existing data before fetching new data
      allSales.clear();
      shops.clear();

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
        final serviceAmount = (data['serviceAmount'] ?? 0).toDouble();
        final accessoriesAmount =
            (data['accessoriesAmount'] ?? (totalAmount - serviceAmount))
                .toDouble();

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
            salesPersonName: data['salesPersonName'] ?? '',
            salesPersonEmail: data['salesPersonEmail'] ?? '',
            serviceAmount: serviceAmount,
            accessoriesAmount: accessoriesAmount,
            paymentBreakdownVerified: data['paymentBreakdownVerified'] != null
                ? Map<String, dynamic>.from(data['paymentBreakdownVerified'])
                : null,
            paymentVerified: data['paymentVerified'] ?? false,
            notes: data['notes'] ?? '',
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
            fontSize: 24,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
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
                  // Clear data before logout
                  allSales.clear();
                  shops.clear();
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
            SizedBox(height: 16),
            
            // Brand Analysis Card
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: BrandAnalysisCard(
                allSales: allSales,
                formatNumber: _formatNumber,
                onViewDetails: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BrandAnalysisDetailsScreen(
                        allSales: allSales,
                        formatNumber: _formatNumber,
                        shops: shops,
                      ),
                    ),
                  );
                },
              ),
            ),
            
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SalesDetailsScreen(
                    title: 'Total Sales Details',
                    sales: filteredSales,
                    formatNumber: _formatNumber,
                    shops: shops,
                  ),
                ),
              );
            },
          ),
          _buildKPIStatCard(
            'Transactions',
            '$transactionCount',
            Icons.receipt,
            Color(0xFF9C27B0),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TransactionsDetailsScreen(
                    sales: filteredSales,
                    formatNumber: _formatNumber,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKPIStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
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

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryDetailsScreen(
                          category: category,
                          sales: filteredSales,
                          formatNumber: _formatNumber,
                          getCategoryColor: _getCategoryColor,
                        ),
                      ),
                    );
                  },
                  child: Container(
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

          // INVENTORY MANAGEMENT SECTION
          Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'INVENTORY MANAGEMENT',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildDrawerItem(
            Icons.inventory,
            'Inventory Details',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InventoryDetailsScreen(
                    shops: shops,
                    formatNumber: _formatNumber,
                  ),
                ),
              );
            },
          ),

          // SEARCH SECTION
          Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'SEARCH',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildDrawerItem(
            Icons.search,
            'Search Inventory',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchInventoryScreen(
                    allSales: allSales,
                    shops: shops,
                    formatNumber: _formatNumber,
                  ),
                ),
              );
            },
          ),

          // BRAND ANALYSIS SECTION
          Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'BRAND ANALYSIS',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildDrawerItem(
            Icons.bar_chart,
            'Brand Performance',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BrandAnalysisDetailsScreen(
                    allSales: allSales,
                    formatNumber: _formatNumber,
                    shops: shops,
                  ),
                ),
              );
            },
          ),

          // Continue with existing drawer items...
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
            Icons.analytics,
            'Accessories & Service Report',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AccessoriesServiceReportScreen(
                    allSales: allSales,
                    formatNumber: _formatNumber,
                    shops: shops,
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
          Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'DETAILED REPORTS',
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
          Divider(height: 1),
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
  final double? serviceAmount;
  final double? accessoriesAmount;
  final Map<String, dynamic>? paymentBreakdownVerified;
  final bool? paymentVerified;
  final String? notes;

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
    this.serviceAmount,
    this.accessoriesAmount,
    this.paymentBreakdownVerified,
    this.paymentVerified,
    this.notes,
  });
}

// New Screens with Card Details

// Sales Details Screen
class SalesDetailsScreen extends StatelessWidget {
  final String title;
  final List<Sale> sales;
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  SalesDetailsScreen({
    required this.title,
    required this.sales,
    required this.formatNumber,
    required this.shops,
  });

  @override
  Widget build(BuildContext context) {
    double totalSales = sales.fold(0.0, (sum, sale) => sum + sale.amount);
    
    // Group by shop
    Map<String, List<Sale>> shopGroups = {};
    for (var sale in sales) {
      if (!shopGroups.containsKey(sale.shopName)) {
        shopGroups[sale.shopName] = [];
      }
      shopGroups[sale.shopName]!.add(sale);
    }
    
    // Group by category
    Map<String, List<Sale>> categoryGroups = {};
    for (var sale in sales) {
      if (!categoryGroups.containsKey(sale.category)) {
        categoryGroups[sale.category] = [];
      }
      categoryGroups[sale.category]!.add(sale);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              color: Color(0xFF0A4D2E),
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: 'Summary'),
                  Tab(text: 'Shop-wise'),
                  Tab(text: 'Category-wise'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSummaryTab(totalSales),
                  _buildShopWiseTab(shopGroups),
                  _buildCategoryWiseTab(categoryGroups),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab(double totalSales) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.analytics, size: 64, color: Color(0xFF0A4D2E)),
                    SizedBox(height: 16),
                    Text(
                      'Total Sales',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '₹${formatNumber(totalSales)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A7D4A),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '${sales.length} transactions',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Distribution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Payment Methods
                    _buildDistributionItem('Cash Sales', Icons.currency_rupee, 
                      sales.fold(0.0, (sum, sale) => sum + (sale.cashAmount ?? 0)),
                      Color(0xFF4CAF50)),
                    _buildDistributionItem('Card Sales', Icons.credit_card, 
                      sales.fold(0.0, (sum, sale) => sum + (sale.cardAmount ?? 0)),
                      Color(0xFF2196F3)),
                    _buildDistributionItem('GPay Sales', Icons.payment, 
                      sales.fold(0.0, (sum, sale) => sum + (sale.gpayAmount ?? 0)),
                      Color(0xFF9C27B0)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionItem(String title, IconData icon, double amount, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  '₹${formatNumber(amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopWiseTab(Map<String, List<Sale>> shopGroups) {
    List<Map<String, dynamic>> shopData = [];
    shopGroups.forEach((shopName, sales) {
      double total = sales.fold(0.0, (sum, sale) => sum + sale.amount);
      shopData.add({
        'shopName': shopName,
        'total': total,
        'count': sales.length,
        'sales': sales,
      });
    });
    
    // Sort by total sales
    shopData.sort((a, b) => b['total'].compareTo(a['total']));

    return ListView.builder(
      itemCount: shopData.length,
      itemBuilder: (context, index) {
        var data = shopData[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: Icon(Icons.store, color: Color(0xFF1A7D4A)),
            title: Text(
              data['shopName'],
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${data['count']} sales'),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${formatNumber(data['total'])}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
                Text(
                  'Avg: ₹${formatNumber(data['total'] / data['count'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...(data['sales'] as List<Sale>).map((sale) {
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.shopping_cart, size: 20),
                        title: Text(sale.customerName),
                        subtitle: Text(
                          '${sale.category} • ${DateFormat('dd MMM yyyy').format(sale.date)}',
                        ),
                        trailing: Text(
                          '₹${formatNumber(sale.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryWiseTab(Map<String, List<Sale>> categoryGroups) {
    List<Map<String, dynamic>> categoryData = [];
    categoryGroups.forEach((category, sales) {
      double total = sales.fold(0.0, (sum, sale) => sum + sale.amount);
      categoryData.add({
        'category': category,
        'total': total,
        'count': sales.length,
        'sales': sales,
      });
    });
    
    // Sort by total sales
    categoryData.sort((a, b) => b['total'].compareTo(a['total']));

    return ListView.builder(
      itemCount: categoryData.length,
      itemBuilder: (context, index) {
        var data = categoryData[index];
        Color categoryColor = _getCategoryColor(data['category']);
        
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  _getCategoryIcon(data['category']),
                  color: categoryColor,
                  size: 20,
                ),
              ),
            ),
            title: Text(
              data['category'],
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${data['count']} sales'),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${formatNumber(data['total'])}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
                Text(
                  'Avg: ₹${formatNumber(data['total'] / data['count'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...(data['sales'] as List<Sale>).map((sale) {
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.person, size: 20),
                        title: Text(sale.customerName),
                        subtitle: Text(
                          '${sale.shopName} • ${DateFormat('dd MMM yyyy').format(sale.date)}',
                        ),
                        trailing: Text(
                          '₹${formatNumber(sale.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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

// Transactions Details Screen
class TransactionsDetailsScreen extends StatelessWidget {
  final List<Sale> sales;
  final String Function(double) formatNumber;

  TransactionsDetailsScreen({
    required this.sales,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transactions Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
      ),
      body: Column(
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
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '₹${formatNumber(sales.fold(0.0, (sum, sale) => sum + sale.amount))}',
                          style: TextStyle(
                            fontSize: 20,
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

          // Transactions List
          Expanded(
            child: ListView.builder(
              itemCount: sales.length,
              itemBuilder: (context, index) {
                final sale = sales[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(sale.category).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          _getCategoryIcon(sale.category),
                          color: _getCategoryColor(sale.category),
                          size: 20,
                        ),
                      ),
                    ),
                    title: Text(
                      sale.customerName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${sale.category} • ${sale.shopName}',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(sale.date),
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${formatNumber(sale.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                        SizedBox(height: 2),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(0xFF1A7D4A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sale.type.replaceAll('_', ' '),
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF1A7D4A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      _showTransactionDetails(context, sale);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Sale sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transaction Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Customer', sale.customerName),
              _buildDetailRow('Category', sale.category),
              _buildDetailRow('Shop', sale.shopName),
              _buildDetailRow('Date', DateFormat('dd MMM yyyy, hh:mm a').format(sale.date)),
              _buildDetailRow('Amount', '₹${formatNumber(sale.amount)}'),
              if (sale.customerPhone != null) 
                _buildDetailRow('Phone', sale.customerPhone!),
              if (sale.brand != null) 
                _buildDetailRow('Brand', sale.brand!),
              if (sale.model != null) 
                _buildDetailRow('Model', sale.model!),
              if (sale.imei != null) 
                _buildDetailRow('IMEI', sale.imei!),
              if (sale.salesPersonName != null) 
                _buildDetailRow('Sales Person', sale.salesPersonName!),
              if (sale.cashAmount != null && sale.cashAmount! > 0)
                _buildDetailRow('Cash', '₹${formatNumber(sale.cashAmount!)}'),
              if (sale.cardAmount != null && sale.cardAmount! > 0)
                _buildDetailRow('Card', '₹${formatNumber(sale.cardAmount!)}'),
              if (sale.gpayAmount != null && sale.gpayAmount! > 0)
                _buildDetailRow('GPay', '₹${formatNumber(sale.gpayAmount!)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
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

// Brand Analysis Card for Dashboard
class BrandAnalysisCard extends StatefulWidget {
  final List<Sale> allSales;
  final String Function(double) formatNumber;
  final VoidCallback onViewDetails;

  BrandAnalysisCard({
    required this.allSales,
    required this.formatNumber,
    required this.onViewDetails,
  });

  @override
  _BrandAnalysisCardState createState() => _BrandAnalysisCardState();
}

class _BrandAnalysisCardState extends State<BrandAnalysisCard> {
  String _selectedTimePeriod = 'monthly';
  final List<String> _timePeriods = ['daily', 'monthly', 'yearly'];

  List<Sale> _getFilteredSales() {
    DateTime startDate;
    DateTime endDate;
    DateTime now = DateTime.now();

    switch (_selectedTimePeriod) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
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
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1).add(Duration(seconds: -1));
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
    }

    return widget.allSales.where((sale) {
      return sale.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
    }).toList();
  }

  Map<String, Map<String, dynamic>> _getBrandAnalysis() {
    List<Sale> filteredSales = _getFilteredSales();
    Map<String, Map<String, dynamic>> brandData = {};

    for (var sale in filteredSales) {
      String? brand = sale.brand;
      if (brand == null || brand.isEmpty) continue;

      if (!brandData.containsKey(brand)) {
        brandData[brand] = {
          'totalSales': 0.0,
          'count': 0,
          'categories': <String, double>{},
          'models': <String, int>{},
          'shops': <String, double>{},
        };
      }

      brandData[brand]!['totalSales'] += sale.amount;
      brandData[brand]!['count'] += 1;

      // Track categories
      String category = sale.category;
      brandData[brand]!['categories'][category] =
          (brandData[brand]!['categories'][category] ?? 0.0) + sale.amount;

      // Track models
      String? model = sale.model;
      if (model != null && model.isNotEmpty) {
        brandData[brand]!['models'][model] =
            (brandData[brand]!['models'][model] ?? 0) + 1;
      }

      // Track shops
      brandData[brand]!['shops'][sale.shopName] =
          (brandData[brand]!['shops'][sale.shopName] ?? 0.0) + sale.amount;
    }

    return brandData;
  }

  @override
  Widget build(BuildContext context) {
    final brandAnalysis = _getBrandAnalysis();
    final sortedBrands = brandAnalysis.entries.toList()
      ..sort((a, b) => b.value['totalSales'].compareTo(a.value['totalSales']));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.branding_watermark,
                        color: Color(0xFF0A4D2E), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Brand Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _selectedTimePeriod = value;
                    });
                  },
                  itemBuilder: (context) => _timePeriods.map((period) {
                    return PopupMenuItem(
                      value: period,
                      child: Text(period.toUpperCase()),
                    );
                  }).toList(),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF0A4D2E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedTimePeriod.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down,
                            size: 16, color: Color(0xFF0A4D2E)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Time Period Summary
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTimePeriodLabel(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${sortedBrands.length} Brands',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: widget.onViewDetails,
                    icon: Icon(Icons.analytics, size: 16),
                    label: Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1A7D4A),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Top Brands
            ...sortedBrands.take(3).map((entry) {
              String brand = entry.key;
              var data = entry.value;
              double totalSales = data['totalSales'];
              int count = data['count'];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BrandDetailsScreen(
                        brand: brand,
                        sales: widget.allSales.where((s) => s.brand == brand).toList(),
                        formatNumber: widget.formatNumber,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      // Brand Icon/Initial
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _getBrandColor(brand).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            brand.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getBrandColor(brand),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  brand,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF1A7D4A).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$count sales',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF1A7D4A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            Text(
                              '₹${widget.formatNumber(totalSales)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A4D2E),
                              ),
                            ),
                            SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: sortedBrands.isNotEmpty
                                  ? totalSales / sortedBrands.first.value['totalSales']
                                  : 0,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getBrandColor(brand),
                              ),
                              minHeight: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            if (sortedBrands.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.more_horiz, color: Colors.grey[400]),
                    SizedBox(width: 4),
                    Text(
                      '+${sortedBrands.length - 3} more brands',
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
      ),
    );
  }

  String _getTimePeriodLabel() {
    switch (_selectedTimePeriod) {
      case 'daily':
        return 'Today';
      case 'monthly':
        return 'This Month';
      case 'yearly':
        return 'This Year';
      default:
        return 'This Month';
    }
  }

  Color _getBrandColor(String brand) {
    // Generate consistent color based on brand name
    int hash = brand.hashCode;
    return Color((hash & 0xFFFFFF) | 0xFF000000).withOpacity(0.8);
  }
}

// Brand Details Screen
class BrandDetailsScreen extends StatelessWidget {
  final String brand;
  final List<Sale> sales;
  final String Function(double) formatNumber;

  BrandDetailsScreen({
    required this.brand,
    required this.sales,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    double totalSales = sales.fold(0.0, (sum, sale) => sum + sale.amount);
    
    // Group by category
    Map<String, List<Sale>> categoryGroups = {};
    for (var sale in sales) {
      if (!categoryGroups.containsKey(sale.category)) {
        categoryGroups[sale.category] = [];
      }
      categoryGroups[sale.category]!.add(sale);
    }
    
    // Group by shop
    Map<String, List<Sale>> shopGroups = {};
    for (var sale in sales) {
      if (!shopGroups.containsKey(sale.shopName)) {
        shopGroups[sale.shopName] = [];
      }
      shopGroups[sale.shopName]!.add(sale);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$brand Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            // Brand Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A4D2E), Color(0xFF1A7D4A)],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        brand.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    brand,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBrandStat('Total Sales', '₹${formatNumber(totalSales)}'),
                      SizedBox(width: 20),
                      _buildBrandStat('Transactions', '${sales.length}'),
                      SizedBox(width: 20),
                      _buildBrandStat('Avg Sale', '₹${formatNumber(sales.isNotEmpty ? totalSales / sales.length : 0)}'),
                    ],
                  ),
                ],
              ),
            ),
            
            Container(
              color: Color(0xFF0A4D2E),
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Categories'),
                  Tab(text: 'Shops'),
                ],
              ),
            ),
            
            Expanded(
              child: TabBarView(
                children: [
                  _buildOverviewTab(sales),
                  _buildCategoriesTab(categoryGroups),
                  _buildShopsTab(shopGroups),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(List<Sale> sales) {
    // Group by month for trend analysis
    Map<String, List<Sale>> monthGroups = {};
    for (var sale in sales) {
      String month = DateFormat('MMM yyyy').format(sale.date);
      if (!monthGroups.containsKey(month)) {
        monthGroups[month] = [];
      }
      monthGroups[month]!.add(sale);
    }
    
    List<Map<String, dynamic>> monthData = [];
    monthGroups.forEach((month, sales) {
      double total = sales.fold(0.0, (sum, sale) => sum + sale.amount);
      monthData.add({
        'month': month,
        'total': total,
        'count': sales.length,
      });
    });
    
    // Sort by month
    monthData.sort((a, b) {
      DateTime dateA = DateFormat('MMM yyyy').parse(a['month']);
      DateTime dateB = DateFormat('MMM yyyy').parse(b['month']);
      return dateB.compareTo(dateA);
    });

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Performance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
                SizedBox(height: 12),
                ...monthData.take(6).map((data) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['month'],
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${formatNumber(data['total'])}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A4D2E),
                              ),
                            ),
                            Text(
                              '${data['count']} sales',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
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
        SizedBox(height: 16),
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Sales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
                SizedBox(height: 12),
                ...sales.take(5).map((sale) {
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.shopping_cart, size: 20),
                    title: Text(sale.customerName),
                    subtitle: Text(
                      '${sale.category} • ${DateFormat('dd MMM yyyy').format(sale.date)}',
                    ),
                    trailing: Text(
                      '₹${formatNumber(sale.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab(Map<String, List<Sale>> categoryGroups) {
    List<Map<String, dynamic>> categoryData = [];
    categoryGroups.forEach((category, sales) {
      double total = sales.fold(0.0, (sum, sale) => sum + sale.amount);
      categoryData.add({
        'category': category,
        'total': total,
        'count': sales.length,
        'sales': sales,
      });
    });
    
    // Sort by total
    categoryData.sort((a, b) => b['total'].compareTo(a['total']));

    return ListView.builder(
      itemCount: categoryData.length,
      itemBuilder: (context, index) {
        var data = categoryData[index];
        Color categoryColor = _getCategoryColor(data['category']);
        
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  _getCategoryIcon(data['category']),
                  color: categoryColor,
                  size: 20,
                ),
              ),
            ),
            title: Text(
              data['category'],
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${data['count']} sales'),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${formatNumber(data['total'])}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
                Text(
                  'Avg: ₹${formatNumber(data['total'] / data['count'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...(data['sales'] as List<Sale>).map((sale) {
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.person, size: 20),
                        title: Text(sale.customerName),
                        subtitle: Text(
                          '${sale.shopName} • ${DateFormat('dd MMM yyyy').format(sale.date)}',
                        ),
                        trailing: Text(
                          '₹${formatNumber(sale.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShopsTab(Map<String, List<Sale>> shopGroups) {
    List<Map<String, dynamic>> shopData = [];
    shopGroups.forEach((shopName, sales) {
      double total = sales.fold(0.0, (sum, sale) => sum + sale.amount);
      shopData.add({
        'shopName': shopName,
        'total': total,
        'count': sales.length,
        'sales': sales,
      });
    });
    
    // Sort by total
    shopData.sort((a, b) => b['total'].compareTo(a['total']));

    return ListView.builder(
      itemCount: shopData.length,
      itemBuilder: (context, index) {
        var data = shopData[index];
        
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: Icon(Icons.store, color: Color(0xFF1A7D4A)),
            title: Text(
              data['shopName'],
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${data['count']} sales'),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${formatNumber(data['total'])}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
                Text(
                  'Avg: ₹${formatNumber(data['total'] / data['count'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...(data['sales'] as List<Sale>).map((sale) {
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.shopping_cart, size: 20),
                        title: Text(sale.customerName),
                        subtitle: Text(
                          '${sale.category} • ${DateFormat('dd MMM yyyy').format(sale.date)}',
                        ),
                        trailing: Text(
                          '₹${formatNumber(sale.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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

// Continue with the rest of the screens from the previous code...

// Search Screen for IMEI and Product Name
class SearchInventoryScreen extends StatefulWidget {
  final List<Sale> allSales;
  final List<Map<String, dynamic>> shops;
  final String Function(double) formatNumber;

  SearchInventoryScreen({
    required this.allSales,
    required this.shops,
    required this.formatNumber,
  });

  @override
  _SearchInventoryScreenState createState() => _SearchInventoryScreenState();
}

class _SearchInventoryScreenState extends State<SearchInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _searchType = 'imei'; // 'imei' or 'productName'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_performSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim().toLowerCase();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    // Filter sales based on search type
    List<Sale> filteredSales = [];

    if (_searchType == 'imei') {
      filteredSales = widget.allSales.where((sale) {
        return sale.imei != null && 
               sale.imei!.toLowerCase().contains(query);
      }).toList();
    } else {
      filteredSales = widget.allSales.where((sale) {
        return (sale.itemName?.toLowerCase().contains(query) ?? false) ||
               (sale.model?.toLowerCase().contains(query) ?? false) ||
               (sale.brand?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Convert to result format
    List<Map<String, dynamic>> results = [];
    for (var sale in filteredSales) {
      results.add({
        'sale': sale,
        'type': 'sale',
        'relevance': _calculateRelevance(sale, query),
      });
    }

    // Sort by relevance
    results.sort((a, b) => b['relevance'].compareTo(a['relevance']));

    setState(() {
      _searchResults = results;
    });
  }

  int _calculateRelevance(Sale sale, String query) {
    int relevance = 0;
    
    // Exact match gets highest score
    if (_searchType == 'imei' && sale.imei?.toLowerCase() == query) {
      relevance += 100;
    }
    
    // Starts with query
    if (sale.imei?.toLowerCase().startsWith(query) ?? false) {
      relevance += 50;
    }
    
    // Contains query
    if (sale.imei?.toLowerCase().contains(query) ?? false) {
      relevance += 30;
    }
    
    // For product name search
    if (_searchType == 'productName') {
      if (sale.itemName?.toLowerCase() == query) {
        relevance += 100;
      }
      if (sale.model?.toLowerCase() == query) {
        relevance += 90;
      }
      if (sale.brand?.toLowerCase() == query) {
        relevance += 80;
      }
      if (sale.itemName?.toLowerCase().contains(query) ?? false) {
        relevance += 40;
      }
    }
    
    // Recent sales get slight boost
    if (sale.date.isAfter(DateTime.now().subtract(Duration(days: 30)))) {
      relevance += 5;
    }
    
    return relevance;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults.clear();
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Search Inventory',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16),
            color: Color(0xFFE8F5E9),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            decoration: InputDecoration(
                              hintText: _searchType == 'imei'
                                  ? 'Search by IMEI number...'
                                  : 'Search by product name, model, or brand...',
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear),
                                      onPressed: _clearSearch,
                                    )
                                  : null,
                            ),
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            setState(() {
                              _searchType = value;
                            });
                            _performSearch();
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'imei',
                              child: Row(
                                children: [
                                  Icon(Icons.confirmation_number, size: 18),
                                  SizedBox(width: 8),
                                  Text('Search by IMEI'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'productName',
                              child: Row(
                                children: [
                                  Icon(Icons.phone_iphone, size: 18),
                                  SizedBox(width: 8),
                                  Text('Search by Product'),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF0A4D2E).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _searchType == 'imei'
                                  ? Icons.confirmation_number
                                  : Icons.phone_iphone,
                              color: Color(0xFF0A4D2E),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _searchType == 'imei'
                          ? 'Enter full or partial IMEI number'
                          : 'Search by product name, model, or brand name',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search Results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Search Inventory',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              _searchType == 'imei'
                  ? 'Enter IMEI number to search'
                  : 'Enter product name, model, or brand',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isSearching && _searchResults.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: Color(0xFF0A4D2E)),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Try different search terms',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final sale = result['sale'] as Sale;
        
        return _buildSaleCard(sale);
      },
    );
  }

  Widget _buildSaleCard(Sale sale) {
    return GestureDetector(
      onTap: () {
        _showSaleDetails(context, sale);
      },
      child: Card(
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(sale.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      sale.category,
                      style: TextStyle(
                        color: _getCategoryColor(sale.category),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Product Info
              if (sale.brand != null || sale.model != null)
                Row(
                  children: [
                    Icon(Icons.phone_iphone, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${sale.brand ?? ''} ${sale.model ?? sale.itemName}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              
              SizedBox(height: 4),
              
              // IMEI
              if (sale.imei != null && sale.imei!.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.confirmation_number, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'IMEI: ${sale.imei}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: 'Monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              
              SizedBox(height: 12),
              Divider(height: 1),
              SizedBox(height: 12),
              
              // Sale Details
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
                        'Date & Shop',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yy').format(sale.date),
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      Text(
                        sale.shopName,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Additional Info
              if (sale.customerPhone != null)
                Row(
                  children: [
                    Icon(Icons.phone, size: 12, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      sale.customerPhone!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              
              if (sale.salesPersonEmail != null || sale.salesPersonName != null)
                Text(
                  'Sales Person: ${sale.salesPersonEmail ?? sale.salesPersonName}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaleDetails(BuildContext context, Sale sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sale Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Customer', sale.customerName),
              _buildDetailRow('Category', sale.category),
              _buildDetailRow('Shop', sale.shopName),
              _buildDetailRow('Date', DateFormat('dd MMM yyyy, hh:mm a').format(sale.date)),
              _buildDetailRow('Amount', '₹${widget.formatNumber(sale.amount)}'),
              if (sale.customerPhone != null) 
                _buildDetailRow('Phone', sale.customerPhone!),
              if (sale.brand != null) 
                _buildDetailRow('Brand', sale.brand!),
              if (sale.model != null) 
                _buildDetailRow('Model', sale.model!),
              if (sale.imei != null) 
                _buildDetailRow('IMEI', sale.imei!),
              if (sale.salesPersonName != null) 
                _buildDetailRow('Sales Person', sale.salesPersonName!),
              if (sale.cashAmount != null && sale.cashAmount! > 0)
                _buildDetailRow('Cash', '₹${widget.formatNumber(sale.cashAmount!)}'),
              if (sale.cardAmount != null && sale.cardAmount! > 0)
                _buildDetailRow('Card', '₹${widget.formatNumber(sale.cardAmount!)}'),
              if (sale.gpayAmount != null && sale.gpayAmount! > 0)
                _buildDetailRow('GPay', '₹${widget.formatNumber(sale.gpayAmount!)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
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
}

// Detailed Brand Analysis Screen
class BrandAnalysisDetailsScreen extends StatefulWidget {
  final List<Sale> allSales;
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  BrandAnalysisDetailsScreen({
    required this.allSales,
    required this.formatNumber,
    required this.shops,
  });

  @override
  _BrandAnalysisDetailsScreenState createState() =>
      _BrandAnalysisDetailsScreenState();
}

class _BrandAnalysisDetailsScreenState extends State<BrandAnalysisDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTimePeriod = 'monthly';
  final List<String> _timePeriods = ['daily', 'monthly', 'yearly'];
  String? _selectedBrand;
  List<String> _allBrands = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _extractBrands();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _extractBrands() {
    Set<String> brands = {};
    for (var sale in widget.allSales) {
      if (sale.brand != null && sale.brand!.isNotEmpty) {
        brands.add(sale.brand!);
      }
    }
    _allBrands = brands.toList()..sort();
  }

  List<Sale> _getFilteredSales() {
    DateTime startDate;
    DateTime endDate;
    DateTime now = DateTime.now();

    switch (_selectedTimePeriod) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
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
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1).add(Duration(seconds: -1));
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
    }

    return widget.allSales.where((sale) {
      if (_selectedBrand != null && sale.brand != _selectedBrand) return false;
      return sale.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
    }).toList();
  }

  Map<String, dynamic> _getBrandStatistics() {
    List<Sale> filteredSales = _getFilteredSales();
    Map<String, Map<String, dynamic>> brandData = {};

    for (var sale in filteredSales) {
      String? brand = sale.brand;
      if (brand == null || brand.isEmpty) brand = 'Unknown';

      if (!brandData.containsKey(brand)) {
        brandData[brand] = {
          'totalSales': 0.0,
          'count': 0,
          'categories': <String, double>{},
          'models': <String, int>{},
          'shops': <String, double>{},
          'paymentMethods': {
            'cash': 0.0,
            'card': 0.0,
            'gpay': 0.0,
          },
        };
      }

      brandData[brand]!['totalSales'] += sale.amount;
      brandData[brand]!['count'] += 1;

      // Categories
      String category = sale.category;
      brandData[brand]!['categories'][category] =
          (brandData[brand]!['categories'][category] ?? 0.0) + sale.amount;

      // Models
      String? model = sale.model ?? sale.itemName;
      if (model.isNotEmpty) {
        brandData[brand]!['models'][model] =
            (brandData[brand]!['models'][model] ?? 0) + 1;
      }

      // Shops
      brandData[brand]!['shops'][sale.shopName] =
          (brandData[brand]!['shops'][sale.shopName] ?? 0.0) + sale.amount;

      // Payment Methods
      if (sale.cashAmount != null) brandData[brand]!['paymentMethods']['cash'] += sale.cashAmount!;
      if (sale.cardAmount != null) brandData[brand]!['paymentMethods']['card'] += sale.cardAmount!;
      if (sale.gpayAmount != null) brandData[brand]!['paymentMethods']['gpay'] += sale.gpayAmount!;
    }

    // Calculate totals
    double totalAllSales = 0;
    int totalTransactions = 0;
    brandData.forEach((brand, data) {
      totalAllSales += data['totalSales'];
      totalTransactions += data['count'];
    });

    return {
      'brandData': brandData,
      'totalAllSales': totalAllSales,
      'totalTransactions': totalTransactions,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getBrandStatistics();
    final brandData = stats['brandData'] as Map<String, Map<String, dynamic>>;
    final sortedBrands = brandData.entries.toList()
      ..sort((a, b) => b.value['totalSales'].compareTo(a.value['totalSales']));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Brand Performance Analysis',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Brand Details'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(stats, sortedBrands),
          _buildBrandDetailsTab(sortedBrands),
          _buildTrendsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
      Map<String, dynamic> stats, List<MapEntry<String, Map<String, dynamic>>> sortedBrands) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Filters
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 12),
                    // Time Period
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _timePeriods.map((period) {
                        bool isSelected = _selectedTimePeriod == period;
                        return FilterChip(
                          label: Text(
                            period.toUpperCase(),
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.white : Colors.grey[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedTimePeriod = period;
                            });
                          },
                          backgroundColor: Colors.grey.shade100,
                          selectedColor: Color(0xFF1A7D4A),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 12),
                    // Brand Filter
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBrand,
                          isExpanded: true,
                          hint: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('All Brands'),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('All Brands'),
                              ),
                            ),
                            ..._allBrands.map<DropdownMenuItem<String>>((brand) {
                              return DropdownMenuItem<String>(
                                value: brand,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(brand),
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedBrand = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Summary Cards
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatCard(
                  'Total Brands',
                  '${sortedBrands.length}',
                  Icons.branding_watermark,
                  Color(0xFF2196F3),
                  'Active brands',
                ),
                _buildStatCard(
                  'Total Sales',
                  '₹${widget.formatNumber(stats['totalAllSales'])}',
                  Icons.currency_rupee,
                  Color(0xFF0A4D2E),
                  'All brands combined',
                ),
                _buildStatCard(
                  'Transactions',
                  '${stats['totalTransactions']}',
                  Icons.receipt,
                  Color(0xFF4CAF50),
                  'Total sales count',
                ),
                _buildStatCard(
                  'Avg/Brand',
                  sortedBrands.isNotEmpty
                      ? '₹${widget.formatNumber(stats['totalAllSales'] / sortedBrands.length)}'
                      : '₹0',
                  Icons.trending_up,
                  Color(0xFF9C27B0),
                  'Average per brand',
                ),
              ],
            ),
          ),

          // Top 5 Brands Chart
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top 5 Brands by Sales',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                    SizedBox(height: 16),
                    ...sortedBrands.take(5).asMap().entries.map((entry) {
                      int index = entry.key;
                      var brandEntry = entry.value;
                      String brand = brandEntry.key;
                      var data = brandEntry.value;
                      double totalSales = data['totalSales'];
                      double percentage = stats['totalAllSales'] > 0
                          ? (totalSales / stats['totalAllSales']) * 100
                          : 0;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BrandDetailsScreen(
                                brand: brand,
                                sales: widget.allSales.where((s) => s.brand == brand).toList(),
                                formatNumber: widget.formatNumber,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _getBrandColor(brand),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    (index + 1).toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                        Text(
                                          brand,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '₹${widget.formatNumber(totalSales)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0A4D2E),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _getBrandColor(brand),
                                      ),
                                      minHeight: 6,
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${data['count']} sales',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '${percentage.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandDetailsTab(
      List<MapEntry<String, Map<String, dynamic>>> sortedBrands) {
    return sortedBrands.isEmpty
        ? Center(
            child: Text('No brand data available'),
          )
        : ListView.builder(
            itemCount: sortedBrands.length,
            itemBuilder: (context, index) {
              var brandEntry = sortedBrands[index];
              String brand = brandEntry.key;
              var data = brandEntry.value;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getBrandColor(brand).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        brand.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getBrandColor(brand),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    brand,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${data['count']} sales'),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${widget.formatNumber(data['totalSales'])}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Avg: ₹${widget.formatNumber(data['count'] > 0 ? data['totalSales'] / data['count'] : 0)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Categories
                          if ((data['categories'] as Map<String, double>)
                              .isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sales by Category',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0A4D2E),
                                  ),
                                ),
                                SizedBox(height: 8),
                                ...(data['categories'] as Map<String, double>)
                                    .entries
                                    .map((entry) {
                                  Color categoryColor = _getCategoryColor(entry.key);
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: categoryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(entry.key),
                                        ),
                                        Text(
                                          '₹${widget.formatNumber(entry.value)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),

                          SizedBox(height: 16),

                          // Top Models
                          if ((data['models'] as Map<String, int>).isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Top Models',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0A4D2E),
                                  ),
                                ),
                                SizedBox(height: 8),
                                ...(data['models'] as Map<String, int>)
                                    .entries
                                    .take(3)
                                    .map((entry) {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Icon(Icons.phone_iphone,
                                            size: 14, color: Colors.grey[600]),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            entry.key,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Color(0xFF2196F3)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${entry.value} sales',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF2196F3),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),

                          SizedBox(height: 16),

                          // Top Shops
                          if ((data['shops'] as Map<String, double>).isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Top Performing Shops',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0A4D2E),
                                  ),
                                ),
                                SizedBox(height: 8),
                                ...(data['shops'] as Map<String, double>)
                                    .entries
                                    .toList()
                                  ..sort((a, b) => b.value.compareTo(a.value))
                                  ..take(3)
                                  .map((entry) {
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: [
                                          Icon(Icons.store,
                                              size: 14, color: Colors.grey[600]),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(entry.key),
                                          ),
                                          Text(
                                            '₹${widget.formatNumber(entry.value)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                              ],
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

  Widget _buildTrendsTab() {
    // This would require historical data for trend analysis
    // For now, show a placeholder with explanation
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Trend Analysis',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A4D2E),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Brand performance trends over time will be displayed here.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Features coming soon:',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  _buildFeatureItem('Monthly sales trends'),
                  _buildFeatureItem('Year-over-year comparison'),
                  _buildFeatureItem('Market share analysis'),
                  _buildFeatureItem('Seasonal patterns'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Color(0xFF4CAF50)),
          SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey[600])),
        ],
      );
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
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
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getBrandColor(String brand) {
    int hash = brand.hashCode;
    List<Color> brandColors = [
      Color(0xFF2196F3), // Blue
      Color(0xFF4CAF50), // Green
      Color(0xFF9C27B0), // Purple
      Color(0xFFFF9800), // Orange
      Color(0xFFF44336), // Red
      Color(0xFF00BCD4), // Cyan
      Color(0xFF673AB7), // Deep Purple
      Color(0xFFFF5722), // Deep Orange
    ];
    return brandColors[hash.abs() % brandColors.length];
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
}

// Continue with the rest of the existing screens...

// Inventory Details Screen
class InventoryDetailsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> shops;
  final String Function(double) formatNumber;

  InventoryDetailsScreen({required this.shops, required this.formatNumber});

  @override
  _InventoryDetailsScreenState createState() => _InventoryDetailsScreenState();
}

class _InventoryDetailsScreenState extends State<InventoryDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedShopId;
  String? _selectedStatus = 'available';
  bool _isLoading = true;
  List<Map<String, dynamic>> _allInventory = [];
  List<Map<String, dynamic>> _filteredInventory = [];
  Map<String, dynamic> _inventoryStats = {};
  final Color primaryGreen = Color(0xFF0A4D2E);
  final Color secondaryGreen = Color(0xFF1A7D4A);
  final Color lightGreen = Color(0xFFE8F5E9);

  @override
  void initState() {
    super.initState();
    _loadAllInventory();
  }

  Future<void> _loadAllInventory() async {
    setState(() => _isLoading = true);

    try {
      // Load phone stock
      final phoneStockSnapshot = await _firestore
          .collection('phoneStock')
          .get();

      _allInventory.clear();

      // Convert phone stock data
      for (var doc in phoneStockSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _allInventory.add({
          'id': doc.id,
          'type': 'phone_stock',
          'shopId': data['shopId'] ?? '',
          'shopName': data['shopName'] ?? 'Unknown Shop',
          'productName': data['productName'] ?? 'Unknown',
          'productBrand': data['productBrand'] ?? 'Unknown',
          'productPrice': (data['productPrice'] ?? 0).toDouble(),
          'imei': data['imei'] ?? 'N/A',
          'status': data['status'] ?? 'available',
          'uploadedAt': data['uploadedAt'] is Timestamp
              ? (data['uploadedAt'] as Timestamp).toDate()
              : DateTime.now(),
          'uploadedBy': data['uploadedBy'] ?? 'Unknown',
        });
      }

      // Load returned phones
      final returnedSnapshot = await _firestore
          .collection('phoneReturns')
          .get();

      for (var doc in returnedSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _allInventory.add({
          'id': doc.id,
          'type': 'phone_return',
          'shopId': data['originalShopId'] ?? '',
          'shopName': data['originalShopName'] ?? 'Unknown Shop',
          'productName': data['productName'] ?? 'Unknown',
          'productBrand': data['productBrand'] ?? 'Unknown',
          'productPrice': (data['productPrice'] ?? 0).toDouble(),
          'imei': data['imei'] ?? 'N/A',
          'status': 'returned',
          'returnedAt': data['returnedAt'] is Timestamp
              ? (data['returnedAt'] as Timestamp).toDate()
              : DateTime.now(),
          'returnedBy': data['returnedBy'] ?? 'Unknown',
          'reason': data['reason'] ?? '',
        });
      }

      _calculateStats();
      _applyFilters();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading inventory: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    _inventoryStats = {
      'totalItems': _allInventory.length,
      'available': _allInventory
          .where((item) => item['status'] == 'available')
          .length,
      'sold': _allInventory.where((item) => item['status'] == 'sold').length,
      'returned': _allInventory
          .where((item) => item['status'] == 'returned')
          .length,
      'totalValue': _allInventory.fold(
        0.0,
        (sum, item) => sum + (item['productPrice'] ?? 0),
      ),
      'availableValue': _allInventory
          .where((item) => item['status'] == 'available')
          .fold(0.0, (sum, item) => sum + (item['productPrice'] ?? 0)),
      'soldValue': _allInventory
          .where((item) => item['status'] == 'sold')
          .fold(0.0, (sum, item) => sum + (item['productPrice'] ?? 0)),
    };
  }

  void _applyFilters() {
    setState(() {
      _filteredInventory = _allInventory.where((item) {
        if (_selectedShopId != null && item['shopId'] != _selectedShopId) {
          return false;
        }
        if (_selectedStatus != null && item['status'] != _selectedStatus) {
          return false;
        }
        return true;
      }).toList();

      // Sort by date (newest first)
      _filteredInventory.sort((a, b) {
        final dateA = a['uploadedAt'] ?? a['returnedAt'] ?? DateTime.now();
        final dateB = b['uploadedAt'] ?? b['returnedAt'] ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
    });
  }

  Widget _buildFilterSection() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 12),

              // Shop Filter
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedShopId,
                    isExpanded: true,
                    hint: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('All Shops'),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('All Shops'),
                        ),
                      ),
                      ...widget.shops.map<DropdownMenuItem<String>>((shop) {
                        return DropdownMenuItem<String>(
                          value: shop['id'] as String?,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(shop['name'] as String),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedShopId = value;
                      });
                      _applyFilters();
                    },
                  ),
                ),
              ),

              SizedBox(height: 12),

              // Status Filter
              Row(
                children: [
                  _buildStatusChip('All', null),
                  SizedBox(width: 8),
                  _buildStatusChip('Available', 'available'),
                  SizedBox(width: 8),
                  _buildStatusChip('Sold', 'sold'),
                  SizedBox(width: 8),
                  _buildStatusChip('Returned', 'returned'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String? value) {
    final isSelected = _selectedStatus == value;
    Color chipColor;

    switch (value) {
      case 'available':
        chipColor = Color(0xFF4CAF50);
        break;
      case 'sold':
        chipColor = Color(0xFF2196F3);
        break;
      case 'returned':
        chipColor = Color(0xFFFF9800);
        break;
      default:
        chipColor = primaryGreen;
    }

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = value;
        });
        _applyFilters();
      },
      backgroundColor: chipColor.withOpacity(0.1),
      selectedColor: chipColor,
    );
  }

  Widget _buildStatsCards() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _buildStatCard(
            'Total Items',
            '${_inventoryStats['totalItems']}',
            Icons.inventory,
            primaryGreen,
            'Value: ₹${widget.formatNumber(_inventoryStats['totalValue'] ?? 0)}',
          ),
          _buildStatCard(
            'Available',
            '${_inventoryStats['available']}',
            Icons.check_circle,
            Color(0xFF4CAF50),
            'Value: ₹${widget.formatNumber(_inventoryStats['availableValue'] ?? 0)}',
          ),
          _buildStatCard(
            'Sold',
            '${_inventoryStats['sold']}',
            Icons.shopping_cart,
            Color(0xFF2196F3),
            'Value: ₹${widget.formatNumber(_inventoryStats['soldValue'] ?? 0)}',
          ),
          _buildStatCard(
            'Returned',
            '${_inventoryStats['returned']}',
            Icons.assignment_return,
            Color(0xFFFF9800),
            'Phones returned',
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
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
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
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryList() {
    if (_filteredInventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No inventory items found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Try changing your filters',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _filteredInventory.length,
      itemBuilder: (context, index) {
        final item = _filteredInventory[index];
        return _buildInventoryCard(item);
      },
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    String status = item['status'];
    String type = item['type'];
    DateTime date = item['uploadedAt'] ?? item['returnedAt'] ?? DateTime.now();

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'available':
        statusColor = Color(0xFF4CAF50);
        statusIcon = Icons.check_circle;
        statusText = 'Available';
        break;
      case 'sold':
        statusColor = Color(0xFF2196F3);
        statusIcon = Icons.shopping_cart;
        statusText = 'Sold';
        break;
      case 'returned':
        statusColor = Color(0xFFFF9800);
        statusIcon = Icons.assignment_return;
        statusText = 'Returned';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = status;
    }

    return GestureDetector(
      onTap: () {
        _showItemDetails(context, item);
      },
      child: Card(
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
                      item['productName'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 8),

              Row(
                children: [
                  Icon(
                    Icons.branding_watermark,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 6),
                  Text(
                    item['productBrand'],
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  Spacer(),
                  Icon(Icons.currency_rupee, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 6),
                  Text(
                    '₹${widget.formatNumber(item['productPrice'])}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 6),

              Row(
                children: [
                  Icon(Icons.store, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item['shopName'],
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 6),

              Row(
                children: [
                  Icon(
                    Icons.confirmation_number,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'IMEI: ${item['imei']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'Monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 8),

              Divider(height: 1, color: Colors.grey[300]),

              SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type == 'phone_return' ? 'Returned' : 'Added',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy').format(date),
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        type == 'phone_return' ? 'Returned By' : 'Uploaded By',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        item['returnedBy'] ?? item['uploadedBy'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),

              if (type == 'phone_return' && item['reason'] != null)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Reason: ${item['reason']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetails(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Inventory Item Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Product Name', item['productName']),
              _buildDetailRow('Brand', item['productBrand']),
              _buildDetailRow('Price', '₹${widget.formatNumber(item['productPrice'])}'),
              _buildDetailRow('Shop', item['shopName']),
              _buildDetailRow('Status', item['status'].toString().toUpperCase()),
              _buildDetailRow('IMEI', item['imei']),
              _buildDetailRow('Type', item['type'] == 'phone_stock' ? 'Phone Stock' : 'Phone Return'),
              _buildDetailRow(
                'Date',
                DateFormat('dd MMM yyyy').format(
                  item['uploadedAt'] ?? item['returnedAt'] ?? DateTime.now(),
                ),
              ),
              _buildDetailRow(
                item['type'] == 'phone_return' ? 'Returned By' : 'Uploaded By',
                item['returnedBy'] ?? item['uploadedBy'],
              ),
              if (item['reason'] != null) _buildDetailRow('Return Reason', item['reason']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Inventory Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllInventory,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.bar_chart),
            onPressed: _showInventoryAnalytics,
            tooltip: 'Analytics',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: secondaryGreen))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildFilterSection(),
                  _buildStatsCards(),
                  SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Inventory Items (${_filteredInventory.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primaryGreen,
                          ),
                        ),
                        Text(
                          _selectedShopId != null
                              ? widget.shops.firstWhere(
                                  (shop) => shop['id'] == _selectedShopId,
                                  orElse: () => {'name': 'Selected Shop'},
                                )['name']
                              : 'All Shops',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildInventoryList(),
                  SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  void _showInventoryAnalytics() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Calculate shop distribution
        final shopDistribution = <String, int>{};
        for (final item in _allInventory) {
          final shopName = item['shopName'] as String;
          shopDistribution[shopName] = (shopDistribution[shopName] ?? 0) + 1;
        }

        // Calculate brand distribution
        final brandDistribution = <String, int>{};
        final brandValue = <String, double>{};

        for (final item in _allInventory) {
          final brand = item['productBrand'] as String;
          final price = item['productPrice'] as double;

          brandDistribution[brand] = (brandDistribution[brand] ?? 0) + 1;
          brandValue[brand] = (brandValue[brand] ?? 0) + price;
        }

        // Sort brands by count (highest first)
        final sortedBrands = brandDistribution.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Inventory Analytics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 16),

              // Shop-wise distribution
              Text(
                'Shop Distribution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),

              ...shopDistribution.entries.map((entry) {
                final shopName = entry.key;
                final count = entry.value;
                final percentage = (count / _allInventory.length) * 100;

                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          shopName,
                          style: TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '$count items',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '(${percentage.toStringAsFixed(1)}%)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }).toList(),

              SizedBox(height: 16),

              // Brand distribution
              Text(
                'Brand Distribution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),

              ...sortedBrands.take(5).map((entry) {
                final brand = entry.key;
                final count = entry.value;
                final value = brandValue[brand] ?? 0;

                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          brand,
                          style: TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '₹${widget.formatNumber(value)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }).toList(),

              SizedBox(height: 20),

              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Continue with all the other existing screens (SpecificReportScreen, ShopWiseReportScreen, 
// CategoryDetailsScreen, PhoneSalesDetailsScreen, PhoneSalesReportsScreen, 
// AccessoriesServiceReportScreen) exactly as they were in your original code...

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
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 3,
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
      initialIndex: 0, // Changed to 0 for Monthly as default
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Shop-wise Reports',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          backgroundColor: Color(0xFF0A4D2E),
          foregroundColor: Colors.white,
          elevation: 3,
          centerTitle: true,
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            unselectedLabelColor: Colors.grey,
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
        title: Text(
          '$category Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 3,
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 3,
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
                DropdownMenuItem<String>(
                  value: null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('All $label'),
                  ),
                ),
                ...items.map<DropdownMenuItem<String>>((String item) {
                  return DropdownMenuItem<String>(
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
    'monthly',
    'today',
    'yesterday',
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
      initialIndex: 0,
    ); // Default to monthly (index 0)
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: [
            Tab(text: 'Monthly'),
            Tab(text: 'Today'),
            Tab(text: 'Yesterday'),
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

// Accessories Service Report Screen
class AccessoriesServiceReportScreen extends StatefulWidget {
  final List<Sale> allSales;
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  AccessoriesServiceReportScreen({
    required this.allSales,
    required this.formatNumber,
    required this.shops,
  });

  @override
  _AccessoriesServiceReportScreenState createState() =>
      _AccessoriesServiceReportScreenState();
}

class _AccessoriesServiceReportScreenState
    extends State<AccessoriesServiceReportScreen> {
  String _selectedTimePeriod = 'monthly';
  String? _selectedShop;

  List<Map<String, dynamic>> _timePeriods = [
    {'label': 'Monthly', 'value': 'monthly'},
    {'label': 'Daily', 'value': 'daily'},
    {'label': 'Yesterday', 'value': 'yesterday'},
    {'label': 'Last Month', 'value': 'last_month'},
    {'label': 'Yearly', 'value': 'yearly'},
  ];

  List<Sale> _getFilteredSales() {
    DateTime startDate;
    DateTime endDate;
    DateTime now = DateTime.now();

    switch (_selectedTimePeriod) {
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
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).add(Duration(seconds: -1));
    }

    return widget.allSales.where((sale) {
      if (sale.type != 'accessories_service_sale') return false;
      if (_selectedShop != null && sale.shopName != _selectedShop) return false;
      return sale.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
          sale.date.isBefore(endDate.add(Duration(seconds: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    List<Sale> filteredSales = _getFilteredSales();

    // Calculate totals - now showing serviceAmount and accessoriesAmount separately
    double totalService = filteredSales.fold(
      0.0,
      (sum, sale) => sum + (sale.serviceAmount ?? 0),
    );
    double totalAccessories = filteredSales.fold(
      0.0,
      (sum, sale) => sum + (sale.accessoriesAmount ?? 0),
    );
    double totalCombined = totalService + totalAccessories;

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
        title: Text(
          'Accessories & Service Report',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Filters
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                      SizedBox(height: 12),
                      // Time Period
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _timePeriods.map((period) {
                          bool isSelected =
                              _selectedTimePeriod == period['value'];
                          return FilterChip(
                            label: Text(
                              period['label'],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedTimePeriod = period['value'];
                              });
                            },
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: Color(0xFF1A7D4A),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 12),
                      // Shop Filter
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedShop,
                            isExpanded: true,
                            hint: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('All Shops'),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('All Shops'),
                                ),
                              ),
                              ...widget.shops.map<DropdownMenuItem<String>>((
                                shop,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: shop['name'] as String?,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(shop['name'] as String),
                                  ),
                                );
                              }).toList(),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedShop = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Summary Cards - Now showing separate amounts
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildSummaryCard(
                    'Total Combined',
                    '₹${widget.formatNumber(totalCombined)}',
                    Icons.currency_rupee,
                    Color(0xFF0A4D2E),
                  ),
                  _buildSummaryCard(
                    'Service Amount',
                    '₹${widget.formatNumber(totalService)}',
                    Icons.build,
                    Color(0xFF2196F3),
                  ),
                  _buildSummaryCard(
                    'Accessories Amount',
                    '₹${widget.formatNumber(totalAccessories)}',
                    Icons.shopping_bag,
                    Color(0xFF9C27B0),
                  ),
                ],
              ),
            ),

            // Transaction Count
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
                        'Transactions Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0A4D2E),
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Total Transactions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${filteredSales.length}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A4D2E),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Payment Methods',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Cash/Card/GPay',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A7D4A),
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

            // Shop-wise Breakdown
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Shop-wise Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A4D2E),
                ),
              ),
            ),
            SizedBox(height: 12),

            ...shopGroups.entries.map((entry) {
              String shopName = entry.key;
              List<Sale> shopSales = entry.value;

              double shopService = shopSales.fold(
                0.0,
                (sum, sale) => sum + (sale.serviceAmount ?? 0),
              );
              double shopAccessories = shopSales.fold(
                0.0,
                (sum, sale) => sum + (sale.accessoriesAmount ?? 0),
              );
              double shopCombined = shopService + shopAccessories;

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
                      shopName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${shopSales.length} transactions'),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${widget.formatNumber(shopCombined)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Service vs Accessories
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Service Amount',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '₹${widget.formatNumber(shopService)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Accessories Amount',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '₹${widget.formatNumber(shopAccessories)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF9C27B0),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 12),

                            // Payment Breakdown
                            Text(
                              'Payment Breakdown',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0A4D2E),
                              ),
                            ),
                            SizedBox(height: 8),
                            ...shopSales.map((sale) {
                              return ListTile(
                                dense: true,
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat(
                                        'dd MMM yyyy',
                                      ).format(sale.date),
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Service: ₹${widget.formatNumber(sale.serviceAmount ?? 0)} | Accessories: ₹${widget.formatNumber(sale.accessoriesAmount ?? 0)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cash: ₹${widget.formatNumber(sale.cashAmount ?? 0)}',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    Text(
                                      'Card: ₹${widget.formatNumber(sale.cardAmount ?? 0)}',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    Text(
                                      'GPay: ₹${widget.formatNumber(sale.gpayAmount ?? 0)}',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Total: ₹${widget.formatNumber(sale.amount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0A4D2E),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Combined',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
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

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 110, maxHeight: 110),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}