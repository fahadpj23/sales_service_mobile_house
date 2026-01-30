import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sales_stock/screens/user/phone_stock_screen.dart';
import 'package:sales_stock/screens/user/stock_check_screen.dart';
import 'package:sales_stock/screens/user/purchase_history_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'user/accessories_sale_upload.dart';
import 'user/phone_sale_upload.dart';
import 'user/second_phone_sale_upload.dart';
import 'user/base_model_sale_upload.dart';
import 'user/purchase_upload_screen.dart';
import 'user/supplier_list_screen.dart';
import 'user/add_supplier_screen.dart';
import 'user/sales_history.dart'; // Add this import

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<String> collectionNames = [
    'accessories_service_sales',
    'phoneSales',
    'base_model_sale',
    'seconds_phone_sale',
  ];

  List<Map<String, dynamic>> allSales = [];
  List<Map<String, dynamic>> filteredSales = [];
  bool isLoading = true;
  String selectedFilter = 'All';
  final List<String> filterOptions = [
    'All',
    'Accessories',
    'Phones',
    'Second Phones',
    'Base Models',
  ];

  // Sales statistics
  double totalSalesValue = 0.0;
  double accessoriesSalesValue = 0.0;
  double phoneSalesValue = 0.0;
  double secondPhoneSalesValue = 0.0;
  double baseModelSalesValue = 0.0;
  int totalSalesCount = 0;

  // Accessories & Service breakdown
  double totalAccessoriesAmount = 0.0;
  double totalServiceAmount = 0.0;

  // Current month info
  late DateTime currentMonthStart;
  late DateTime currentMonthEnd;
  String currentMonthName = '';
  int currentYear = 0;

  @override
  void initState() {
    super.initState();

    // Initialize current month range
    final now = DateTime.now();
    currentMonthStart = DateTime(now.year, now.month, 1);
    currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    currentMonthName = _getMonthName(now.month);
    currentYear = now.year;

    // Fetch sales data when dashboard loads
    Future.delayed(Duration.zero, () {
      final userData = Provider.of<AuthProvider>(context, listen: false).user;
      if (userData?.shopId != null && userData!.shopId!.isNotEmpty) {
        fetchSalesData(userData.shopId!);
      }
    });
  }

  Future<void> fetchSalesData(String shopId) async {
    setState(() {
      isLoading = true;
      allSales.clear();
      filteredSales.clear();
      // Reset statistics
      totalSalesValue = 0.0;
      accessoriesSalesValue = 0.0;
      phoneSalesValue = 0.0;
      secondPhoneSalesValue = 0.0;
      baseModelSalesValue = 0.0;
      totalSalesCount = 0;
      totalAccessoriesAmount = 0.0;
      totalServiceAmount = 0.0;
    });

    for (var collection in collectionNames) {
      try {
        final List<Map<String, dynamic>> monthSales =
            await _fetchSalesForCollection(collection, shopId);

        for (var sale in monthSales) {
          // Add collection info and formatted data
          sale['collection'] = collection;
          sale['type'] = _getSaleType(collection);
          sale['displayDate'] = _formatDate(sale, collection);
          sale['displayAmount'] = _getAmount(sale, collection);
          sale['customerInfo'] = _getCustomerInfo(sale);
          sale['paymentInfo'] = _getPaymentInfo(sale, collection);
          sale['shopName'] = _getShopName(sale, collection);

          // Get accessories and service amounts
          final accessoriesAmount = _getAccessoriesAmount(sale);
          final serviceAmount = _getServiceAmount(sale);

          // Store these amounts in the sale object for display
          sale['accessoriesAmount'] = accessoriesAmount;
          sale['serviceAmount'] = serviceAmount;

          // Calculate statistics
          final amount = sale['displayAmount'] as double;
          totalSalesValue += amount;
          totalSalesCount++;

          switch (collection) {
            case 'accessories_service_sales':
              accessoriesSalesValue += amount;
              totalAccessoriesAmount += accessoriesAmount;
              totalServiceAmount += serviceAmount;
              break;
            case 'phoneSales':
              phoneSalesValue += amount;
              break;
            case 'seconds_phone_sale':
              secondPhoneSalesValue += amount;
              break;
            case 'base_model_sale':
              baseModelSalesValue += amount;
              break;
          }

          allSales.add(sale);
        }
      } catch (e) {
        print('Error fetching $collection: $e');
      }
    }

    // Apply initial filter
    _applyFilter();

    setState(() => isLoading = false);
  }

  Future<List<Map<String, dynamic>>> _fetchSalesForCollection(
    String collection,
    String shopId,
  ) async {
    final List<Map<String, dynamic>> sales = [];

    try {
      // Get all sales for this shop (we'll filter by date in memory)
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where('shopId', isEqualTo: shopId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Check if sale is in current month
        final saleDate = _getSaleDate(data, collection);
        if (_isDateInCurrentMonth(saleDate)) {
          sales.add(data);
        }
      }
    } catch (e) {
      print('Error in _fetchSalesForCollection for $collection: $e');
    }

    return sales;
  }

  DateTime _getSaleDate(Map<String, dynamic> data, String collection) {
    try {
      // Try different date fields based on collection and data structure
      List<String> dateFields = [];

      switch (collection) {
        case 'accessories_service_sales':
          dateFields = ['date', 'uploadedAt', 'timestamp'];
          break;
        case 'phoneSales':
          dateFields = [
            'saleDate',
            'date',
            'addedAt',
            'createdAt',
            'timestamp',
          ];
          break;
        case 'base_model_sale':
        case 'seconds_phone_sale':
          dateFields = ['date', 'uploadedAt', 'timestamp'];
          break;
        default:
          dateFields = ['date', 'uploadedAt', 'timestamp', 'createdAt'];
      }

      for (var field in dateFields) {
        if (data[field] != null) {
          if (data[field] is Timestamp) {
            return (data[field] as Timestamp).toDate();
          } else if (data[field] is int) {
            return DateTime.fromMillisecondsSinceEpoch(data[field]);
          } else if (data[field] is String) {
            try {
              return DateTime.parse(data[field]);
            } catch (_) {
              // Try custom parsing for date strings
              return _parseDateString(data[field].toString());
            }
          }
        }
      }

      // If no date field found, check for timestamp in milliseconds
      if (data['timestamp'] != null && data['timestamp'] is int) {
        return DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
      }

      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _parseDateString(String dateString) {
    try {
      // Try to parse common date formats
      if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length >= 3) {
          final day = int.tryParse(parts[0]) ?? 1;
          final month = int.tryParse(parts[1]) ?? 1;
          final year = int.tryParse(parts[2]) ?? DateTime.now().year;
          return DateTime(year, month, day);
        }
      }

      // Try ISO format
      return DateTime.parse(dateString);
    } catch (_) {
      return DateTime.now();
    }
  }

  bool _isDateInCurrentMonth(DateTime date) {
    return date.isAfter(
          currentMonthStart.subtract(const Duration(seconds: 1)),
        ) &&
        date.isBefore(currentMonthEnd.add(const Duration(seconds: 1)));
  }

  void _applyFilter() {
    if (selectedFilter == 'All') {
      filteredSales = List.from(allSales);
    } else {
      switch (selectedFilter) {
        case 'Accessories':
          filteredSales = allSales
              .where(
                (sale) => sale['collection'] == 'accessories_service_sales',
              )
              .toList();
          break;
        case 'Phones':
          filteredSales = allSales
              .where((sale) => sale['collection'] == 'phoneSales')
              .toList();
          break;
        case 'Second Phones':
          filteredSales = allSales
              .where((sale) => sale['collection'] == 'seconds_phone_sale')
              .toList();
          break;
        case 'Base Models':
          filteredSales = allSales
              .where((sale) => sale['collection'] == 'base_model_sale')
              .toList();
          break;
        default:
          filteredSales = allSales;
      }
    }

    // Sort by date (newest first)
    filteredSales.sort((a, b) {
      final dateA = _getSaleDate(a, a['collection'] as String);
      final dateB = _getSaleDate(b, b['collection'] as String);
      return dateB.compareTo(dateA);
    });

    // Limit to 10 items for recent sales
    if (filteredSales.length > 10) {
      filteredSales = filteredSales.sublist(0, 10);
    }
  }

  String _getSaleType(String collection) {
    switch (collection) {
      case 'accessories_service_sales':
        return 'Accessories & Service';
      case 'phoneSales':
        return 'New Phone';
      case 'base_model_sale':
        return 'Base Model';
      case 'seconds_phone_sale':
        return 'Second Phone';
      default:
        return 'Sale';
    }
  }

  String _formatDate(Map<String, dynamic> data, String collection) {
    try {
      final date = _getSaleDate(data, collection);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return 'Date not available';
    }
  }

  double _getAmount(Map<String, dynamic> data, String collection) {
    try {
      switch (collection) {
        case 'accessories_service_sales':
          // Check if totalSaleAmount exists, otherwise calculate from accessories + service
          if (data['totalSaleAmount'] != null) {
            return (data['totalSaleAmount'] ?? 0).toDouble();
          } else {
            // Calculate from accessories and service amounts
            final accessories = _getAccessoriesAmount(data);
            final service = _getServiceAmount(data);
            return accessories + service;
          }
        case 'phoneSales':
          return (data['effectivePrice'] ?? data['price'] ?? 0).toDouble();
        case 'base_model_sale':
        case 'seconds_phone_sale':
          return (data['price'] ?? data['totalPayment'] ?? 0).toDouble();
        default:
          return 0.0;
      }
    } catch (e) {
      print('Error getting amount: $e');
      return 0.0;
    }
  }

  double _getAccessoriesAmount(Map<String, dynamic> data) {
    try {
      // Check for accessoriesAmount field
      if (data['accessoriesAmount'] != null) {
        return (data['accessoriesAmount'] ?? 0).toDouble();
      }
      // Check for accessoriesAmount with different capitalization
      if (data['AccessoriesAmount'] != null) {
        return (data['AccessoriesAmount'] ?? 0).toDouble();
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  double _getServiceAmount(Map<String, dynamic> data) {
    try {
      // Check for serviceAmount field
      if (data['serviceAmount'] != null) {
        return (data['serviceAmount'] ?? 0).toDouble();
      }
      // Check for serviceAmount with different capitalization
      if (data['ServiceAmount'] != null) {
        return (data['ServiceAmount'] ?? 0).toDouble();
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  String _getCustomerInfo(Map<String, dynamic> data) {
    if (data['customerName'] != null &&
        data['customerName'].toString().isNotEmpty &&
        data['customerName'].toString().toLowerCase() != 'null') {
      return data['customerName'].toString();
    } else if (data['customerPhone'] != null) {
      return data['customerPhone'].toString();
    }
    return 'Walk-in Customer';
  }

  String _getShopName(Map<String, dynamic> data, String collection) {
    if (data['shopName'] != null && data['shopName'].toString().isNotEmpty) {
      return data['shopName'].toString();
    }
    if (collection == 'phoneSales' && data['shopId'] != null) {
      return data['shopId'].toString();
    }
    return 'Shop not specified';
  }

  Map<String, dynamic> _getPaymentInfo(
    Map<String, dynamic> data,
    String collection,
  ) {
    final paymentInfo = {
      'cash': 0.0,
      'card': 0.0,
      'gpay': 0.0,
      'credit': 0.0,
      'downPayment': 0.0,
    };

    try {
      if (collection == 'accessories_service_sales') {
        paymentInfo['cash'] = (data['cashAmount'] ?? 0).toDouble();
        paymentInfo['card'] = (data['cardAmount'] ?? 0).toDouble();
        paymentInfo['gpay'] = (data['gpayAmount'] ?? 0).toDouble();
        // For accessories sales, you might also have a credit field
        paymentInfo['credit'] = (data['customerCredit'] ?? 0).toDouble();
      } else if (collection == 'phoneSales') {
        final paymentBreakdown = data['paymentBreakdown'] ?? {};
        paymentInfo['cash'] = (paymentBreakdown['cash'] ?? 0).toDouble();
        paymentInfo['card'] = (paymentBreakdown['card'] ?? 0).toDouble();
        paymentInfo['gpay'] = (paymentBreakdown['gpay'] ?? 0).toDouble();
        paymentInfo['credit'] = (data['customerCredit'] ?? 0).toDouble();
        paymentInfo['downPayment'] = (data['downPayment'] ?? 0).toDouble();
      } else if (collection == 'base_model_sale' ||
          collection == 'seconds_phone_sale') {
        paymentInfo['cash'] = (data['cash'] ?? 0).toDouble();
        paymentInfo['card'] = (data['card'] ?? 0).toDouble();
        paymentInfo['gpay'] = (data['gpay'] ?? 0).toDouble();
      }
    } catch (e) {
      print('Error getting payment info: $e');
    }

    return paymentInfo;
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Accessories & Service':
        return Colors.blue;
      case 'New Phone':
        return Colors.green;
      case 'Second Phone':
        return Colors.orange;
      case 'Base Model':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Accessories & Service':
        return Icons.shopping_bag;
      case 'New Phone':
        return Icons.phone_iphone;
      case 'Second Phone':
        return Icons.phone_android;
      case 'Base Model':
        return Icons.devices;
      default:
        return Icons.receipt;
    }
  }

  String _getMonthName(int month) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  void _navigateToScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Widget _buildDashboardHome() {
    final authService = AuthService();
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Sales Dashboard'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (user?.shopId != null && user!.shopId!.isNotEmpty) {
                fetchSalesData(user.shopId!);
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logoutUser(authService);
              } else if (value == 'profile') {
                _showProfileDialog(user);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildDashboardBody(user),
    );
  }

  Widget _buildDashboardBody(dynamic user) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green.shade600, Colors.green.shade400],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome, ${user?.name ?? user?.email ?? 'User'}!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sales Representative',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (user?.shopId != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Shop: ${user!.shopName!}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$currentMonthName $currentYear',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Total Sales Card
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.green.shade100, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Sales',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.refresh,
                          size: 20,
                          color: Colors.green.shade600,
                        ),
                        onPressed: () {
                          final user = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          ).user;
                          if (user?.shopId != null &&
                              user!.shopId!.isNotEmpty) {
                            fetchSalesData(user.shopId!);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [Expanded(child: _buildTotalSalesCard())]),
                  const SizedBox(height: 16),
                  _buildSalesBreakdown(),
                ],
              ),
            ),

            // Recent Sales Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Sales',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      if (filteredSales.isNotEmpty)
                        TextButton.icon(
                          onPressed: _showFilterOptions,
                          icon: Icon(
                            Icons.filter_list,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                          label: Text(
                            selectedFilter,
                            style: TextStyle(color: Colors.green.shade600),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRecentSalesList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSalesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade100, Colors.green.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt,
                  size: 20,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Sales Value',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹${totalSalesValue.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shopping_cart,
                  size: 14,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  '$totalSalesCount Sales',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sales Breakdown',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.5,
          children: [
            _buildCategoryCard(
              'Accessories & Service',
              accessoriesSalesValue,
              Colors.blue,
              Icons.shopping_bag,
            ),
            _buildCategoryCard(
              'Phone Sales',
              phoneSalesValue,
              Colors.green,
              Icons.phone_iphone,
            ),
            _buildCategoryCard(
              'Second Phones',
              secondPhoneSalesValue,
              Colors.orange,
              Icons.phone_android,
            ),
            _buildCategoryCard(
              'Base Models',
              baseModelSalesValue,
              Colors.purple,
              Icons.devices,
            ),
          ],
        ),
        // Accessories & Service breakdown if there are any
        if (accessoriesSalesValue > 0) ...[
          const SizedBox(height: 12),
          const Text(
            'Accessories & Service Breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildBreakdownItem(
                  'Accessories',
                  totalAccessoriesAmount,
                  Colors.blue.shade700,
                  Icons.shopping_basket,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBreakdownItem(
                  'Service',
                  totalServiceAmount,
                  Colors.teal,
                  Icons.build,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBreakdownItem(
    String title,
    double value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '₹${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    String title,
    double value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '₹${value.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
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

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Filter Sales',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select a category to filter sales data',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filterOptions.map((filter) {
                  final isSelected = selectedFilter == filter;
                  final color = _getTypeColor(filter);

                  return ChoiceChip(
                    label: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.white : color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        selectedFilter = filter;
                        _applyFilter();
                      });
                      Navigator.pop(context);
                    },
                    selectedColor: color,
                    backgroundColor: color.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: color.withOpacity(0.3), width: 1),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentSalesList() {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    if (filteredSales.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.receipt, size: 50, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No sales found',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: filteredSales.map((sale) {
        final type = sale['type'] as String;
        final color = _getTypeColor(type);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_getTypeIcon(type), size: 20, color: color),
            ),
            title: Text(
              sale['customerInfo'] as String,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale['displayDate'] as String),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(fontSize: 10, color: color),
                  ),
                ),
                const SizedBox(height: 4),
                _buildPaymentChips(
                  sale['paymentInfo'] as Map<String, dynamic>,
                  sale['collection'] as String,
                ),
              ],
            ),
            trailing: Text(
              '₹${(sale['displayAmount'] as double).toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            onTap: () => _showSaleDetails(context, sale),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDrawer() {
    final user = Provider.of<AuthProvider>(context).user;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green.shade600, Colors.green.shade400],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Drawer Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade700.withOpacity(0.2),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        Text(
                          user?.name ?? user?.email ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (user?.shopId != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Shop: ${user!.shopId!}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8),
                    children: [
                      // Dashboard Section
                      _buildDrawerSection(
                        title: 'DASHBOARD',
                        children: [
                          _buildDrawerTile(
                            icon: Icons.dashboard,
                            title: 'Dashboard',
                            color: Colors.green,
                            isSelected: true,
                            onTap: () {
                              _scaffoldKey.currentState?.closeDrawer();
                            },
                          ),
                        ],
                      ),

                      // Inventory Section
                      _buildDrawerSection(
                        title: 'INVENTORY',
                        children: [
                          _buildDrawerTile(
                            icon: Icons.inventory,
                            title: 'Phone Stock',
                            color: Colors.red,
                            onTap: () {
                              _scaffoldKey.currentState?.closeDrawer();
                              _navigateToScreen(const PhoneStockScreen());
                            },
                          ),
                          _buildDrawerTile(
                            icon: Icons.search,
                            title: 'Stock Check',
                            color: Colors.teal,
                            onTap: () {
                              _scaffoldKey.currentState?.closeDrawer();
                              _navigateToScreen(const StockCheckScreen());
                            },
                          ),
                        ],
                      ),

                      // Sales Upload Section
                      _buildDrawerSection(
                        title: 'SALES UPLOAD',
                        children: [
                          _buildDrawerTile(
                            icon: Icons.shopping_bag,
                            title: 'Accessories & Service',
                            color: Colors.blue,
                            onTap: () {
                              _scaffoldKey.currentState?.closeDrawer();
                              _navigateToScreen(const AccessoriesSaleUpload());
                            },
                          ),
                          _buildDrawerTile(
                            icon: Icons.phone_iphone,
                            title: 'Phone Sales',
                            color: Colors.green,
                            onTap: () {
                              _scaffoldKey.currentState?.closeDrawer();
                              _navigateToScreen(const PhoneSaleUpload());
                            },
                          ),
                          _buildDrawerTile(
                            icon: Icons.phone_android,
                            title: 'Second Phones',
                            color: Colors.orange,
                            onTap: () {
                              _scaffoldKey.currentState?.closeDrawer();
                              _navigateToScreen(const SecondPhoneSaleUpload());
                            },
                          ),
                          _buildDrawerTile(
                            icon: Icons.devices,
                            title: 'Base Models',
                            color: Colors.purple,
                            onTap: () {
                              _scaffoldKey.currentState?.closeDrawer();
                              _navigateToScreen(const BaseModelSaleUpload());
                            },
                          ),
                        ],
                      ),

                      // History Section
                      _buildDrawerSection(
                        title: 'HISTORY',
                        children: [
                          _buildDrawerTile(
                            icon: Icons.history,
                            title: 'Sales History',
                            color: Colors.grey,
                            onTap: () {
                              final user = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              ).user;
                              if (user?.shopId != null &&
                                  user!.shopId!.isNotEmpty) {
                                _scaffoldKey.currentState?.closeDrawer();
                                _navigateToScreen(
                                  SalesHistoryScreen(shopId: user.shopId!),
                                );
                              } else {
                                _scaffoldKey.currentState?.closeDrawer();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Shop ID not found. Please contact administrator.',
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                          ),
                          // _buildDrawerTile(
                          //   icon: Icons.inventory,
                          //   title: 'Purchase History',
                          //   color: Colors.brown,
                          //   onTap: () {
                          //     _scaffoldKey.currentState?.closeDrawer();
                          //     _navigateToScreen(const PurchaseHistoryScreen());
                          //   },
                          // ),
                        ],
                      ),

                      // Spacer
                      const Spacer(),

                      // Logout Button
                      Container(
                        margin: const EdgeInsets.all(16),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await AuthService().signOut();
                            Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            ).clearUser();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required Color color,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(isSelected ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isSelected ? color : color.withOpacity(0.8),
            size: 18,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? color : Colors.grey.shade800,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.chevron_right, color: color)
            : Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _logoutUser(AuthService authService) async {
    await authService.signOut();
    Provider.of<AuthProvider>(context, listen: false).clearUser();
  }

  void _showProfileDialog(dynamic user) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 28,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildProfileInfoRow(
                'Name',
                user?.name ?? 'Not set',
                Icons.person,
                Colors.green,
              ),
              _buildProfileInfoRow(
                'Email',
                user?.email ?? 'Not set',
                Icons.email,
                Colors.blue,
              ),
              _buildProfileInfoRow(
                'Shop ID',
                user?.shopId ?? 'Not assigned',
                Icons.store,
                Colors.orange,
              ),
              _buildProfileInfoRow(
                'Phone',
                user?.phone ?? 'Not set',
                Icons.phone,
                Colors.purple,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfoRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChips(
    Map<String, dynamic> paymentInfo,
    String collection,
  ) {
    final List<Widget> chips = [];
    final List<Map<String, dynamic>> paymentTypes = [
      if (paymentInfo['cash'] > 0)
        {'label': 'Cash', 'amount': paymentInfo['cash'], 'color': Colors.green},
      if (paymentInfo['card'] > 0)
        {'label': 'Card', 'amount': paymentInfo['card'], 'color': Colors.blue},
      if (paymentInfo['gpay'] > 0)
        {
          'label': 'GPay',
          'amount': paymentInfo['gpay'],
          'color': Colors.purple,
        },
      if (paymentInfo['credit'] > 0)
        {
          'label': 'Credit',
          'amount': paymentInfo['credit'],
          'color': Colors.orange,
        },
      if (collection == 'phoneSales' && paymentInfo['downPayment'] > 0)
        {
          'label': 'Down',
          'amount': paymentInfo['downPayment'],
          'color': Colors.teal,
        },
    ];

    if (paymentTypes.isEmpty) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.money, size: 10, color: Colors.grey),
              SizedBox(width: 2),
              Text(
                'Payment Info',
                style: TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    } else {
      chips.addAll(
        paymentTypes.map((type) {
          return Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (type['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (type['color'] as Color).withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getPaymentIcon(type['label'] as String),
                  size: 10,
                  color: type['color'] as Color,
                ),
                const SizedBox(width: 2),
                Text(
                  '₹${(type['amount'] as double).toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 9,
                    color: type['color'] as Color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'gpay':
        return Icons.payment;
      case 'credit':
        return Icons.credit_score;
      case 'down':
        return Icons.payments;
      default:
        return Icons.attach_money;
    }
  }

  void _showSaleDetails(BuildContext context, Map<String, dynamic> sale) {
    // Get the accessories and service amounts that we stored
    final accessoriesAmount = sale['accessoriesAmount'] as double? ?? 0.0;
    final serviceAmount = sale['serviceAmount'] as double? ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sale Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getTypeColor(
                          sale['type'] as String,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        sale['type'] as String,
                        style: TextStyle(
                          color: _getTypeColor(sale['type'] as String),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Customer', sale['customerInfo'] as String),
                _buildDetailRow('Shop', sale['shopName'].toString()),
                _buildDetailRow('Date', sale['displayDate'] as String),

                // Accessories and Service amounts for accessories sales
                if (sale['collection'] == 'accessories_service_sales') ...[
                  if (accessoriesAmount > 0)
                    _buildDetailRow(
                      'Accessories Amount',
                      '₹${accessoriesAmount.toStringAsFixed(0)}',
                      amountColor: Colors.blue,
                    ),
                  if (serviceAmount > 0)
                    _buildDetailRow(
                      'Service Amount',
                      '₹${serviceAmount.toStringAsFixed(0)}',
                      amountColor: Colors.teal,
                    ),
                  // Show breakdown
                  if (accessoriesAmount > 0 || serviceAmount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Sale Amount:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹${(sale['displayAmount'] as double).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                // For non-accessories sales, show total amount
                if (sale['collection'] != 'accessories_service_sales')
                  _buildDetailRow(
                    'Total Amount',
                    '₹${(sale['displayAmount'] as double).toStringAsFixed(0)}',
                    isTotal: true,
                  ),

                // Collection-specific details
                if (sale['collection'] == 'phoneSales') ...[
                  if (sale['productModel'] != null)
                    _buildDetailRow('Product', sale['productModel'].toString()),
                  if (sale['brand'] != null)
                    _buildDetailRow('Brand', sale['brand'].toString()),
                  if (sale['imei'] != null)
                    _buildDetailRow('IMEI', sale['imei'].toString()),
                ],

                // Other collection details
                if (sale['productName'] != null)
                  _buildDetailRow('Product', sale['productName'].toString()),

                if (sale['brand'] != null && sale['collection'] != 'phoneSales')
                  _buildDetailRow('Brand', sale['brand'].toString()),

                if (sale['imei'] != null && sale['collection'] != 'phoneSales')
                  _buildDetailRow('IMEI', sale['imei'].toString()),

                const SizedBox(height: 20),
                const Text(
                  'Payment Breakdown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildPaymentDetails(
                  sale['paymentInfo'] as Map<String, dynamic>,
                  sale['collection'] as String,
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? amountColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTotal
            ? Colors.green.shade50
            : amountColor?.withOpacity(0.05) ?? Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: isTotal
                    ? Colors.green.shade700
                    : amountColor ?? Colors.grey.shade700,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isTotal ? 18 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                color: isTotal
                    ? Colors.green.shade800
                    : amountColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPaymentDetails(
    Map<String, dynamic> paymentInfo,
    String collection,
  ) {
    final List<Widget> widgets = [];

    if (paymentInfo['cash'] > 0) {
      widgets.add(
        _buildPaymentDetailRow('Cash', paymentInfo['cash'], Colors.green),
      );
    }
    if (paymentInfo['card'] > 0) {
      widgets.add(
        _buildPaymentDetailRow('Card', paymentInfo['card'], Colors.blue),
      );
    }
    if (paymentInfo['gpay'] > 0) {
      widgets.add(
        _buildPaymentDetailRow('GPay', paymentInfo['gpay'], Colors.purple),
      );
    }
    if (paymentInfo['credit'] > 0) {
      widgets.add(
        _buildPaymentDetailRow('Credit', paymentInfo['credit'], Colors.orange),
      );
    }
    if (collection == 'phoneSales' && paymentInfo['downPayment'] > 0) {
      widgets.add(
        _buildPaymentDetailRow(
          'Down Payment',
          paymentInfo['downPayment'],
          Colors.teal,
        ),
      );
    }

    return widgets;
  }

  Widget _buildPaymentDetailRow(String method, double amount, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getPaymentIcon(method), size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                method,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildDashboardHome();
  }
}
