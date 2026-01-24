import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:sales_stock/screens/login_screen.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/auth_service.dart';
import '../../../models/sale.dart';

// Import all screen files
import 'admin/sales/sales_details_screen.dart.dart';
import 'admin/sales/transactions_details_screen.dart';
import 'admin/sales/brand_analysis_card.dart';
import 'admin/sales/phone_sales_details_screen.dart';
import 'admin/sales/phone_sales_reports_screen.dart';
import 'admin/sales/accessories_service_report_screen.dart';
import 'admin/inventory/inventory_details_screen.dart';
import 'admin/analysis/brand_analysis_details_screen.dart';
import 'admin/analysis/brand_details_screen.dart';
import 'admin/reports/specific_report_screen.dart';
import 'admin/reports/shop_wise_report_screen.dart';
import 'admin/reports/category_details_screen.dart';
import '../../models/sale.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DateTime _selectedDate = DateTime.now();
  String _timePeriod = 'monthly';
  bool _isLoading = true;
  final authService = AuthService();

  // Custom date range variables
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isCustomPeriod = false;

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
                    if (_isCustomPeriod &&
                        _customStartDate != null &&
                        _customEndDate != null)
                      Text(
                        '${DateFormat('dd MMM yyyy').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
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
      {'label': 'Custom Range', 'icon': Icons.date_range, 'value': 'custom'},
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
                  bool isSelected = false;

                  if (period['value'] == 'custom') {
                    isSelected = _isCustomPeriod;
                  } else {
                    isSelected =
                        _timePeriod == period['value'] && !_isCustomPeriod;
                  }

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
                      if (period['value'] == 'custom') {
                        _showCustomDateRangePicker();
                      } else {
                        setState(() {
                          _timePeriod = period['value'];
                          _isCustomPeriod = false;
                          _customStartDate = null;
                          _customEndDate = null;
                        });
                      }
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: secondaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 8),
              // Show custom date range if selected
              if (_isCustomPeriod &&
                  _customStartDate != null &&
                  _customEndDate != null)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: secondaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: secondaryGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, color: secondaryGreen, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Custom Range: ${DateFormat('dd MMM yyyy').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, size: 16, color: secondaryGreen),
                        onPressed: _showCustomDateRangePicker,
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

    // Debug: Print filtered sales count
    print('Filtered Sales Count: ${filteredSales.length}');
    if (_isCustomPeriod && _customStartDate != null && _customEndDate != null) {
      print('Custom Range: ${_customStartDate} to ${_customEndDate}');
    }

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
                                          color: secondaryGreen.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                    allSales: allSales
                        .where((s) => s.type == 'phone_sale')
                        .toList(),
                    formatNumber: _formatNumber,
                    shops: shops,
                  ),
                ),
              );
            },
          ),

          Divider(height: 1),

          // REMOVED CUSTOM REPORTS SECTION FROM SIDEBAR

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

  // Fixed Custom Date Range Picker - SIMPLIFIED VERSION
  Future<void> _showCustomDateRangePicker() async {
    DateTime startDate =
        _customStartDate ?? DateTime.now().subtract(Duration(days: 7));
    DateTime endDate = _customEndDate ?? DateTime.now();

    // First, pick start date
    final DateTime? pickedStartDate = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: endDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: secondaryGreen,
            colorScheme: ColorScheme.light(primary: secondaryGreen),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedStartDate == null) return; // User cancelled

    // Then, pick end date
    final DateTime? pickedEndDate = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: pickedStartDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: secondaryGreen,
            colorScheme: ColorScheme.light(primary: secondaryGreen),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedEndDate == null) return; // User cancelled

    // Update the state with selected dates
    setState(() {
      _customStartDate = DateTime(
        pickedStartDate.year,
        pickedStartDate.month,
        pickedStartDate.day,
        0,
        0,
        0,
        0,
      );
      _customEndDate = DateTime(
        pickedEndDate.year,
        pickedEndDate.month,
        pickedEndDate.day,
        23,
        59,
        59,
        999,
      );
      _isCustomPeriod = true;
      _timePeriod = 'custom';
    });

    print(
      'Custom range set: ${_customStartDate!.toIso8601String()} to ${_customEndDate!.toIso8601String()}',
    );
  }

  // FIXED Date Filtering Method
  List<Sale> _filterSales() {
    DateTime startDate;
    DateTime endDate;

    if (_isCustomPeriod && _customStartDate != null && _customEndDate != null) {
      // For custom range - use the exact dates already set
      startDate = _customStartDate!;
      endDate = _customEndDate!;

      print(
        'Custom range filtering: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
      );
    } else {
      // For predefined periods
      switch (_timePeriod) {
        case 'daily':
          startDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            0,
            0,
            0,
          );
          endDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            23,
            59,
            59,
          );
          break;
        case 'yesterday':
          final yesterday = _selectedDate.subtract(Duration(days: 1));
          startDate = DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
            0,
            0,
            0,
          );
          endDate = DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
            23,
            59,
            59,
          );
          break;
        case 'last_month':
          final firstDayOfLastMonth = DateTime(
            _selectedDate.year,
            _selectedDate.month - 1,
            1,
            0,
            0,
            0,
          );
          startDate = firstDayOfLastMonth;
          endDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            0,
            23,
            59,
            59,
          );
          break;
        case 'monthly':
          startDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            1,
            0,
            0,
            0,
          );
          endDate = DateTime(
            _selectedDate.year,
            _selectedDate.month + 1,
            0,
            23,
            59,
            59,
          );
          break;
        case 'yearly':
          startDate = DateTime(_selectedDate.year, 1, 1, 0, 0, 0);
          endDate = DateTime(_selectedDate.year, 12, 31, 23, 59, 59);
          break;
        default:
          startDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            0,
            0,
            0,
          );
          endDate = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            23,
            59,
            59,
          );
      }
    }

    // Filter sales
    List<Sale> filtered = allSales.where((sale) {
      // Check if sale date is between startDate and endDate (inclusive)
      return (sale.date.isAfter(
                startDate.subtract(Duration(milliseconds: 1)),
              ) ||
              sale.date.isAtSameMomentAs(startDate)) &&
          (sale.date.isBefore(endDate.add(Duration(milliseconds: 1))) ||
              sale.date.isAtSameMomentAs(endDate));
    }).toList();

    return filtered;
  }

  double _calculateTotalSales() {
    return _filterSales().fold(0.0, (sum, sale) => sum + sale.amount);
  }

  String _getPeriodLabel() {
    if (_isCustomPeriod) {
      return 'Custom Period Sale';
    }

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
