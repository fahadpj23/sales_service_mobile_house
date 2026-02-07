import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:sales_stock/screens/admin/analysis/downpayment_benefit_screen.dart';
import 'package:sales_stock/screens/admin/analysis/exchange_analysis_screen.dart';
import 'package:sales_stock/screens/login_screen.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/auth_service.dart';
import '../../../models/sale.dart';
import 'dart:async';

import 'admin/sales/sales_details_screen.dart.dart';
import 'admin/sales/transactions_details_screen.dart';
import 'admin/sales/phone_sales_details_screen.dart';
import 'admin/sales/phone_sales_reports_screen.dart';
import 'admin/sales/accessories_service_report_screen.dart';
import 'admin/inventory/inventory_details_screen.dart';
import 'admin/reports/specific_report_screen.dart';
import 'admin/reports/shop_wise_report_screen.dart';
import 'admin/reports/category_details_screen.dart';
import '../../models/sale.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DateTime _selectedDate = DateTime.now();
  String _timePeriod = 'monthly';
  bool _isLoading = true;
  final authService = AuthService();

  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isCustomPeriod = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  final Color primaryGreen = Color(0xFF0A4D2E);
  final Color secondaryGreen = Color(0xFF1A7D4A);
  final Color accentGreen = Color(0xFF28A745);
  final Color lightGreen = Color(0xFFE8F5E9);
  final Color cardGreen = Color(0xFF2E7D32);
  final Color warningColor = Color(0xFFFFC107);
  final Color dangerColor = Color(0xFFDC3545);

  List<Sale> allSales = [];
  List<Map<String, dynamic>> shops = [];

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
    _startAutoRefreshTimer();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(Duration(hours: 1), (timer) {
      if (mounted) {
        _fetchAllData();
      }
    });
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      allSales.clear();
      shops.clear();

      await Future.wait([
        _fetchAccessoriesServiceSales(),
        _fetchBaseModelSales(),
        _fetchPhoneSales(),
        _fetchSecondsPhoneSales(),
        _fetchShops(),
      ]);

      allSales.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data'),
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
    } catch (e) {}
  }

  Future<void> _fetchBaseModelSales() async {
    try {
      final snapshot = await baseModelSales.get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

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
    } catch (e) {}
  }

  Future<void> _fetchPhoneSales() async {
    try {
      final snapshot = await phoneSales.get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        DateTime saleDate;
        if (data['saleDate'] is Timestamp) {
          saleDate = (data['saleDate'] as Timestamp).toDate();
        } else if (data['createdAt'] is Timestamp) {
          saleDate = (data['createdAt'] as Timestamp).toDate();
        } else {
          saleDate = DateTime.now();
        }

        DateTime? addedAt;
        if (data['addedAt'] is Timestamp) {
          addedAt = (data['addedAt'] as Timestamp).toDate();
        }

        DateTime? createdAt;
        if (data['createdAt'] is Timestamp) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        }

        DateTime? updatedAt;
        if (data['updatedAt'] is Timestamp) {
          updatedAt = (data['updatedAt'] as Timestamp).toDate();
        }

        final effectivePrice = (data['effectivePrice'] ?? 0).toDouble();

        Map<String, dynamic>? paymentBreakdown;
        if (data.containsKey('paymentBreakdown') &&
            data['paymentBreakdown'] is Map) {
          paymentBreakdown = Map<String, dynamic>.from(
            data['paymentBreakdown'],
          );
        }

        Map<String, dynamic>? paymentBreakdownVerified;
        if (data.containsKey('paymentBreakdownVerified') &&
            data['paymentBreakdownVerified'] is Map) {
          paymentBreakdownVerified = Map<String, dynamic>.from(
            data['paymentBreakdownVerified'],
          );
        }

        bool hasDisbursementAmount = data.containsKey('disbursementAmount');
        double disbursementAmountValue = hasDisbursementAmount
            ? (data['disbursementAmount'] ?? 0).toDouble()
            : 0.0;

        Sale sale = Sale(
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
          price: (data['price'] ?? 0).toDouble(),
          disbursementAmount: disbursementAmountValue,
          model: data['productModel'] ?? '',
          cashAmount: paymentBreakdown?['cash'] != null
              ? (paymentBreakdown!['cash']).toDouble()
              : 0.0,
          cardAmount: paymentBreakdown?['card'] != null
              ? (paymentBreakdown!['card']).toDouble()
              : 0.0,
          gpayAmount: paymentBreakdown?['gpay'] != null
              ? (paymentBreakdown!['gpay']).toDouble()
              : 0.0,
          downPayment: data.containsKey('downPayment')
              ? (data['downPayment'] ?? 0).toDouble()
              : 0.0,
          financeType: data['financeType']?.toString(),
          purchaseMode: data['purchaseMode']?.toString(),
          salesPersonEmail: data['userEmail'] ?? 'Unknown',
          customerPhone: data['customerPhone']?.toString() ?? '',
          imei: data['imei']?.toString() ?? '',
          discount: data.containsKey('discount')
              ? (data['discount'] ?? 0).toDouble()
              : 0.0,
          exchangeValue: data.containsKey('exchangeValue')
              ? (data['exchangeValue'] ?? 0).toDouble()
              : 0.0,
          amountToPay: data.containsKey('amountToPay')
              ? (data['amountToPay'] ?? 0).toDouble()
              : 0.0,
          balanceReturnedToCustomer:
              data.containsKey('balanceReturnedToCustomer')
              ? (data['balanceReturnedToCustomer'] ?? 0).toDouble()
              : 0.0,
          customerCredit: data.containsKey('customerCredit')
              ? (data['customerCredit'] ?? 0).toDouble()
              : 0.0,
          addedAt: addedAt,
          userEmail: data['userEmail']?.toString(),
          userId: data['userId']?.toString(),
          updatedAt: updatedAt,
          createdAt: createdAt,
          support: data['support']?.toString(),
          upgrade: data['upgrade']?.toString(),
          paymentBreakdownVerified: paymentBreakdownVerified,
          paymentVerified: data['paymentVerified'] as bool?,
          disbursementReceived: data['disbursementReceived'] as bool?,
          downPaymentReceived: data['downPaymentReceived'] as bool?,
        );

        allSales.add(sale);
      }
    } catch (e) {}
  }

  Future<void> _fetchSecondsPhoneSales() async {
    try {
      final snapshot = await secondsPhoneSales.get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

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
    } catch (e) {}
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

      shops.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );
    } catch (e) {
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
                  _autoRefreshTimer?.cancel();
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
            'Auto-refresh every hour',
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
            SizedBox(height: 12),
            _buildPerformanceInsights(),
            SizedBox(height: 12),
            _buildShopPerformanceSection(),
            SizedBox(height: 16),
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
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '₹${_formatNumber(totalSales)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 4),
                    if (_isCustomPeriod &&
                        _customStartDate != null &&
                        _customEndDate != null)
                      Text(
                        '${DateFormat('dd MMM yyyy').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
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
    final List<String> periodOptions = [
      'Daily',
      'Yesterday',
      'Last Month',
      'Monthly',
      'Yearly',
      'Custom Range',
    ];

    return Container(
      padding: EdgeInsets.all(12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: primaryGreen, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Select Time Period',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButton<String>(
                  value: _isCustomPeriod ? 'Custom Range' : _getPeriodLabel(),
                  isExpanded: true,
                  underline: SizedBox(),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: primaryGreen,
                    size: 20,
                  ),
                  items: periodOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(color: primaryGreen, fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue == 'Custom Range') {
                      _showCustomDateRangePicker();
                    } else {
                      setState(() {
                        _isCustomPeriod = false;
                        switch (newValue) {
                          case 'Daily':
                            _timePeriod = 'daily';
                            break;
                          case 'Yesterday':
                            _timePeriod = 'yesterday';
                            break;
                          case 'Last Month':
                            _timePeriod = 'last_month';
                            break;
                          case 'Monthly':
                            _timePeriod = 'monthly';
                            break;
                          case 'Yearly':
                            _timePeriod = 'yearly';
                            break;
                        }
                      });
                    }
                  },
                ),
              ),
              if (_isCustomPeriod &&
                  _customStartDate != null &&
                  _customEndDate != null)
                Container(
                  margin: EdgeInsets.only(top: 10),
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: secondaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: secondaryGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, color: secondaryGreen, size: 14),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Custom Range: ${DateFormat('dd MMM yyyy').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, size: 14, color: secondaryGreen),
                        onPressed: _showCustomDateRangePicker,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.count(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _buildCompactKPIStatCard(
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
          _buildCompactKPIStatCard(
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

  Widget _buildCompactKPIStatCard(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
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
              SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShopPerformanceSection() {
    List<Sale> filteredSales = _filterSales();

    Map<String, Map<String, double>> shopCategoryData = {};
    Map<String, double> shopTotalSales = {};

    for (var shop in shops) {
      String shopName = shop['name'];
      shopCategoryData[shopName] = {
        'New Phone': 0.0,
        'Base Model': 0.0,
        'Second Phone': 0.0,
        'Service': 0.0,
      };
      shopTotalSales[shopName] = 0.0;
    }

    for (var sale in filteredSales) {
      String shopName = sale.shopName;
      String category = sale.category;
      double amount = sale.amount;

      if (shopCategoryData.containsKey(shopName)) {
        shopCategoryData[shopName]![category] =
            (shopCategoryData[shopName]![category] ?? 0.0) + amount;
        shopTotalSales[shopName] = (shopTotalSales[shopName] ?? 0.0) + amount;
      }
    }

    List<MapEntry<String, double>> sortedShops =
        shopTotalSales.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedShops.isEmpty) {
      return SizedBox();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store, color: primaryGreen, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Shop Performance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ShopWiseReportScreen(
                            allSales: filteredSales,
                            shops: shops,
                            formatNumber: _formatNumber,
                            getCategoryColor: _getCategoryColor,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: secondaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'View All',
                        style: TextStyle(
                          color: secondaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              ...sortedShops.take(3).map((shopEntry) {
                String shopName = shopEntry.key;
                double shopTotal = shopEntry.value;
                Map<String, double>? categoryData = shopCategoryData[shopName];

                return GestureDetector(
                  onTap: () {
                    _showShopCategoryDetails(
                      shopName,
                      categoryData!,
                      shopTotal,
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                shopName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: primaryGreen,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '₹${_formatNumber(shopTotal)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: secondaryGreen,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCompactCategoryTile(
                              'New Phone',
                              categoryData?['New Phone'] ?? 0.0,
                            ),
                            SizedBox(width: 4),
                            _buildCompactCategoryTile(
                              'Base Model',
                              categoryData?['Base Model'] ?? 0.0,
                            ),
                            SizedBox(width: 4),
                            _buildCompactCategoryTile(
                              'Second Phone',
                              categoryData?['Second Phone'] ?? 0.0,
                            ),
                            SizedBox(width: 4),
                            _buildCompactCategoryTile(
                              'Service',
                              categoryData?['Service'] ?? 0.0,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

              if (sortedShops.length > 3)
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ShopWiseReportScreen(
                            allSales: filteredSales,
                            shops: shops,
                            formatNumber: _formatNumber,
                            getCategoryColor: _getCategoryColor,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      '+ ${sortedShops.length - 3} more shops',
                      style: TextStyle(
                        color: secondaryGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCategoryTile(String category, double amount) {
    if (amount == 0) return SizedBox(width: 0);

    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _getCategoryColor(category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getCategoryIcon(category),
              size: 12,
              color: _getCategoryColor(category),
            ),
          ),
          SizedBox(height: 2),
          Text(
            '₹${_formatNumber(amount)}',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: _getCategoryColor(category),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showShopCategoryDetails(
    String shopName,
    Map<String, double> categoryData,
    double total,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$shopName - Category Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Sales: ₹${_formatNumber(total)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                SizedBox(height: 16),

                ...categoryData.entries.map((entry) {
                  String category = entry.key;
                  double amount = entry.value;
                  double percentage = total > 0 ? (amount / total * 100) : 0;

                  if (amount == 0) return SizedBox();

                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(category).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getCategoryIcon(category),
                            size: 16,
                            color: _getCategoryColor(category),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: 2),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '₹${_formatNumber(amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: primaryGreen,
                                    ),
                                  ),
                                  Text(
                                    '${percentage.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondaryGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: secondaryGreen)),
            ),
          ],
        );
      },
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
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                SizedBox(height: 12),
                Text(
                  'No sales data',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Try selecting a different time period',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
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

    double totalSales = _calculateTotalSales();

    var sortedCategories = categoryPerformance.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: EdgeInsets.all(12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: primaryGreen, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Category Performance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryGreen.withOpacity(0.1)),
                ),
                padding: EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Total Sales',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '₹${_formatNumber(totalSales)}',
                          style: TextStyle(
                            fontSize: 14,
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
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${sortedCategories.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: secondaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              ...sortedCategories.map((entry) {
                String category = entry.key;
                double amount = entry.value;
                int count = categoryCount[category] ?? 0;
                double percentage = totalSales > 0
                    ? (amount / totalSales * 100)
                    : 0;

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
                    margin: EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(
                                  category,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Icon(
                                  _getCategoryIcon(category),
                                  color: _getCategoryColor(category),
                                  size: 18,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
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
                                            fontSize: 14,
                                            color: Colors.grey[800],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: secondaryGreen.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '$count sales',
                                          style: TextStyle(
                                            fontSize: 11,
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
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            '${percentage.toStringAsFixed(1)}% of total',
                                            style: TextStyle(
                                              fontSize: 11,
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
              }),
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
            height: 140,
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
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 32,
                    color: primaryGreen,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'MobileHouse Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Dashboard',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
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

          Padding(
            padding: EdgeInsets.only(left: 16, top: 12, bottom: 6),
            child: Text(
              'INVENTORY MANAGEMENT',
              style: TextStyle(
                fontSize: 9,
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
            padding: EdgeInsets.only(left: 16, top: 12, bottom: 6),
            child: Text(
              'CATEGORY REPORTS',
              style: TextStyle(
                fontSize: 9,
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
            padding: EdgeInsets.only(left: 16, top: 12, bottom: 6),
            child: Text(
              'SHOP REPORTS',
              style: TextStyle(
                fontSize: 9,
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

          Padding(
            padding: EdgeInsets.only(left: 16, top: 12, bottom: 6),
            child: Text(
              'DETAILED REPORTS',
              style: TextStyle(
                fontSize: 9,
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
            padding: EdgeInsets.only(left: 16, top: 12, bottom: 6),
            child: Text(
              'PAYMENT ANALYSIS',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildDrawerItem(
            Icons.swap_horiz,
            'Exchange Analysis',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExchangeAnalysisScreen(
                    allSales: allSales,
                    formatNumber: _formatNumber,
                    shops: shops,
                  ),
                ),
              );
            },
          ),
          _buildDrawerItem(
            Icons.monetization_on,
            'Downpayment Benefit',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DownpaymentBenefitScreen(
                    allSales: allSales,
                    formatNumber: _formatNumber,
                    shops: shops,
                  ),
                ),
              );
            },
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.only(left: 16, top: 12, bottom: 6),
            child: Text(
              'SPECIFIC REPORTS',
              style: TextStyle(
                fontSize: 9,
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
        size: 18,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? secondaryGreen : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      tileColor: isSelected ? secondaryGreen.withOpacity(0.1) : null,
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 3),
    );
  }

  Future<void> _refreshData() async {
    await _fetchAllData();
  }

  Future<void> _showCustomDateRangePicker() async {
    DateTime startDate =
        _customStartDate ?? DateTime.now().subtract(Duration(days: 7));
    DateTime endDate = _customEndDate ?? DateTime.now();

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

    if (pickedStartDate == null) return;

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

    if (pickedEndDate == null) return;

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
  }

  List<Sale> _filterSales() {
    DateTime startDate;
    DateTime endDate;

    if (_isCustomPeriod && _customStartDate != null && _customEndDate != null) {
      startDate = _customStartDate!;
      endDate = _customEndDate!;
    } else {
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

    List<Sale> filtered = allSales.where((sale) {
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
      return 'Custom Range';
    }

    switch (_timePeriod) {
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
        return 'Monthly';
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
