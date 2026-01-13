import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sales_stock/screens/login_screen.dart';
import 'package:sales_stock/screens/user_dashboard.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

// Navigation Service for global navigation
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(
      routeName,
      arguments: arguments,
    );
  }

  static void goBack() {
    return navigatorKey.currentState!.pop();
  }

  static Future<dynamic> navigateAndReplace(
    String routeName, {
    Object? arguments,
  }) {
    return navigatorKey.currentState!.pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }

  static Future<dynamic> navigateAndRemoveUntil(String routeName) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: const FinanceDashboardApp(),
    ),
  );
}

class FinanceDashboardApp extends StatelessWidget {
  const FinanceDashboardApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Dashboard',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: Colors.green[900],
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green[900],
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[800],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(fontSize: 12),
          bodySmall: TextStyle(fontSize: 10),
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.user == null) {
            return const LoginScreen();
          }
          // Check user role - if not finance, show user dashboard
          if (authProvider.user?.role != 'finance') {
            return const UserDashboard();
          }
          return const FinanceDashboard();
        },
      ),
    );
  }
}

class FinanceDashboard extends StatefulWidget {
  const FinanceDashboard({Key? key}) : super(key: key);

  @override
  State<FinanceDashboard> createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends State<FinanceDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  bool _isDrawerOpen = false;
  String? _selectedShop;
  final authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _phoneSales = [];
  List<Map<String, dynamic>> _accessoriesServiceSales = [];
  List<Map<String, dynamic>> _baseModelSales = [];
  List<Map<String, dynamic>> _secondsPhoneSales = [];

  List<String> _allShops = ['All Shops'];
  List<String> _availableShops = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _fetchPhoneSales(),
        _fetchAccessoriesServiceSales(),
        _fetchBaseModelSales(),
        _fetchSecondsPhoneSales(),
      ]);

      _extractShopsFromData();

      print('Data loaded successfully');
    } catch (e) {
      print('Error loading data: $e');
      _showSnackBar('Error loading data: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _extractShopsFromData() {
    final Set<String> shops = {'All Shops'};

    for (var sale in _phoneSales) {
      final shop = _getShopName(sale);
      if (shop.isNotEmpty && shop != 'Main Store') {
        shops.add(shop);
      }
    }

    for (var sale in _accessoriesServiceSales) {
      final shop = _getShopName(sale);
      if (shop.isNotEmpty && shop != 'Main Store') {
        shops.add(shop);
      }
    }

    for (var sale in _baseModelSales) {
      final shop = _getShopName(sale);
      if (shop.isNotEmpty && shop != 'Main Store') {
        shops.add(shop);
      }
    }

    for (var sale in _secondsPhoneSales) {
      final shop = _getShopName(sale);
      if (shop.isNotEmpty && shop != 'Main Store') {
        shops.add(shop);
      }
    }

    setState(() {
      _availableShops = shops.toList();
      _allShops = shops.toList();
    });
  }

  Future<void> _fetchPhoneSales() async {
    try {
      final querySnapshot = await _firestore
          .collection('phoneSales')
          .orderBy('saleDate', descending: true)
          .limit(100)
          .get();

      _phoneSales = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['downPaymentReceived'] = data['downPaymentReceived'] ?? false;
        data['disbursementReceived'] = data['disbursementReceived'] ?? false;
        data['paymentVerified'] = data['paymentVerified'] ?? false;

        _initializePhoneSalePaymentData(data);

        return data;
      }).toList();
    } catch (e) {
      print('Error fetching PhoneSales: $e');
      rethrow;
    }
  }

  void _initializePhoneSalePaymentData(Map<String, dynamic> data) {
    String purchaseMode = (data['purchaseMode'] ?? '').toString().toLowerCase();

    if (purchaseMode == 'emi') {
      data['paymentBreakdownVerified'] = {
        'cash': data['downPaymentReceived'] ?? false,
        'card': false,
        'gpay': false,
      };
    } else {
      final existingBreakdown = data['paymentBreakdownVerified'];
      if (existingBreakdown is Map) {
        data['paymentBreakdownVerified'] = {
          'cash': _convertToBool(existingBreakdown['cash']),
          'card': _convertToBool(existingBreakdown['card']),
          'gpay': _convertToBool(existingBreakdown['gpay']),
        };
      } else {
        bool isCash = purchaseMode.contains('cash') || purchaseMode.isEmpty;
        bool isCard = purchaseMode.contains('card');
        bool isUPI =
            purchaseMode.contains('upi') ||
            purchaseMode.contains('gpay') ||
            purchaseMode.contains('phonepe') ||
            purchaseMode.contains('paytm');

        data['paymentBreakdownVerified'] = {
          'cash': (data['paymentVerified'] ?? false) && isCash,
          'card': (data['paymentVerified'] ?? false) && isCard,
          'gpay': (data['paymentVerified'] ?? false) && isUPI,
        };
      }
    }
  }

  Future<void> _fetchAccessoriesServiceSales() async {
    try {
      final querySnapshot = await _firestore
          .collection('accessories_service_sales')
          .orderBy('date', descending: true)
          .limit(100)
          .get();

      _accessoriesServiceSales = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['paymentVerified'] = data['paymentVerified'] ?? false;
        _initializeGenericPaymentData(data);
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching accessories_service_sales: $e');
      rethrow;
    }
  }

  Future<void> _fetchBaseModelSales() async {
    try {
      final querySnapshot = await _firestore
          .collection('base_model_sale')
          .orderBy('date', descending: true)
          .limit(100)
          .get();

      _baseModelSales = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['paymentVerified'] = data['paymentVerified'] ?? false;
        _initializeGenericPaymentData(data);
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching base_model_sale: $e');
      rethrow;
    }
  }

  Future<void> _fetchSecondsPhoneSales() async {
    try {
      final querySnapshot = await _firestore
          .collection('seconds_phone_sale')
          .orderBy('date', descending: true)
          .limit(100)
          .get();

      _secondsPhoneSales = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['paymentVerified'] = data['paymentVerified'] ?? false;
        _initializeGenericPaymentData(data);
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching seconds_phone_sale: $e');
      rethrow;
    }
  }

  void _initializeGenericPaymentData(Map<String, dynamic> data) {
    final paymentBreakdown = data['paymentBreakdownVerified'];

    if (paymentBreakdown == null || paymentBreakdown is! Map) {
      data['paymentBreakdownVerified'] = {
        'cash': false,
        'card': false,
        'gpay': false,
      };
    } else {
      data['paymentBreakdownVerified'] = {
        'cash': _convertToBool(paymentBreakdown['cash']),
        'card': _convertToBool(paymentBreakdown['card']),
        'gpay': _convertToBool(paymentBreakdown['gpay']),
      };
    }
  }

  bool _convertToBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is num) {
      return value == 1;
    }
    return false;
  }

  double _extractAmount(dynamic data, List<String> fieldNames) {
    // Handle Map<String, dynamic>
    if (data is Map<String, dynamic>) {
      for (String fieldName in fieldNames) {
        final value = data[fieldName];
        if (value != null) {
          if (value is num) {
            return value.toDouble();
          } else if (value is String) {
            final parsed = double.tryParse(value);
            if (parsed != null) return parsed;
          }
        }
      }
    }
    // Handle Map<dynamic, dynamic>
    else if (data is Map) {
      for (String fieldName in fieldNames) {
        final value = data[fieldName];
        if (value != null) {
          if (value is num) {
            return value.toDouble();
          } else if (value is String) {
            final parsed = double.tryParse(value);
            if (parsed != null) return parsed;
          }
        }
      }
    }
    return 0.0;
  }

  Map<String, double> _getPaymentAmounts(
    String collection,
    Map<String, dynamic> sale,
  ) {
    double cashAmount = 0;
    double cardAmount = 0;
    double gpayAmount = 0;

    if (collection == 'accessories_service_sales') {
      // For accessories: cashAmount, cardAmount, gpayAmount fields
      cashAmount = _extractAmount(sale, [
        'cashAmount',
        'cashPayment',
        'cashPaid',
        'cash',
      ]);
      cardAmount = _extractAmount(sale, [
        'cardAmount',
        'cardPayment',
        'cardPaid',
        'card',
      ]);
      gpayAmount = _extractAmount(sale, [
        'gpayAmount',
        'upiAmount',
        'gpayPayment',
        'upiPayment',
        'gpay',
        'upi',
      ]);
    } else if (collection == 'base_model_sale' ||
        collection == 'seconds_phone_sale') {
      // For base models and seconds phones: cash, card, gpay fields
      cashAmount = _extractAmount(sale, ['cash', 'cashAmount', 'cashPayment']);
      cardAmount = _extractAmount(sale, ['card', 'cardAmount', 'cardPayment']);
      gpayAmount = _extractAmount(sale, [
        'gpay',
        'gpayAmount',
        'upiAmount',
        'upi',
      ]);
    }

    return {'cash': cashAmount, 'card': cardAmount, 'gpay': gpayAmount};
  }

  double _getTotalAmount(Map<String, dynamic> sale) {
    final possibleFields = [
      'totalSaleAmount',
      'price',
      'amountToPay',
      'totalAmount',
      'saleAmount',
      'amount',
      'totalPayment',
      'effectivePrice',
    ];

    for (String fieldName in possibleFields) {
      final value = sale[fieldName];
      if (value != null) {
        if (value is num) {
          return value.toDouble();
        } else if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
    }
    return 0.0;
  }

  DateTime? _parseDate(dynamic date) {
    try {
      if (date == null) return null;
      if (date is Timestamp) {
        return date.toDate();
      } else if (date is DateTime) {
        return date;
      } else if (date is String) {
        if (date.contains('-')) {
          return DateTime.parse(date);
        } else if (date.contains('/')) {
          final parts = date.split('/');
          if (parts.length >= 3) {
            return DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        }
      }
      return null;
    } catch (e) {
      print('Error parsing date: $e');
      return null;
    }
  }

  String _getShopName(Map<String, dynamic> sale) {
    final shopName =
        sale['shopName'] ??
        sale['storeName'] ??
        sale['branchName'] ??
        sale['shop'] ??
        'Main Store';
    return shopName.toString().isEmpty ? 'Main Store' : shopName.toString();
  }

  List<Map<String, dynamic>> _filterByShop(List<Map<String, dynamic>> sales) {
    if (_selectedShop == null || _selectedShop == 'All Shops') {
      return sales;
    }
    return sales.where((sale) => _getShopName(sale) == _selectedShop).toList();
  }

  List<Map<String, dynamic>> _getFilteredDataForCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return _filterByShop(_phoneSales);
      case 1:
        return _filterByShop(_secondsPhoneSales);
      case 2:
        return _filterByShop(_baseModelSales);
      case 3:
        return _filterByShop(_accessoriesServiceSales);
      case 4:
        return _getOverdueSales();
      default:
        return _filterByShop(_phoneSales);
    }
  }

  List<Map<String, dynamic>> _getAllDataForCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return _phoneSales;
      case 1:
        return _secondsPhoneSales;
      case 2:
        return _baseModelSales;
      case 3:
        return _accessoriesServiceSales;
      case 4:
        return _getOverdueSales();
      default:
        return _phoneSales;
    }
  }

  List<Map<String, dynamic>> _getOverdueSales() {
    List<Map<String, dynamic>> allSales = [];
    allSales.addAll(_phoneSales);
    allSales.addAll(_secondsPhoneSales);
    allSales.addAll(_baseModelSales);
    allSales.addAll(_accessoriesServiceSales);

    final now = DateTime.now();
    return allSales.where((sale) {
      if (sale['paymentVerified'] == true) return false;

      DateTime? saleDate;
      if (sale.containsKey('saleDate')) {
        saleDate = _parseDate(sale['saleDate']);
      } else if (sale.containsKey('date')) {
        saleDate = _parseDate(sale['date']);
      } else if (sale.containsKey('timestamp')) {
        saleDate = _parseDate(sale['timestamp']);
      }

      if (saleDate == null) return false;

      final difference = now.difference(saleDate);
      return difference.inDays > 7;
    }).toList();
  }

  Future<void> _updatePaymentVerification(
    String collection,
    String docId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection(collection).doc(docId).update(updates);
      print('✅ Payment verification updated successfully for $docId');
      print('📝 Updates: $updates');
      _showSnackBar('Updated successfully!', Colors.green);

      // Refresh data immediately after update
      await _refreshUpdatedData(collection, docId, updates);
    } catch (e) {
      print('❌ Error updating payment verification: $e');
      _showSnackBar('Error updating: $e', Colors.red);
      rethrow;
    }
  }

  Future<void> _refreshUpdatedData(
    String collection,
    String docId,
    Map<String, dynamic> updates,
  ) async {
    // Update the local data immediately without reloading everything
    switch (collection) {
      case 'phoneSales':
        final index = _phoneSales.indexWhere((sale) => sale['id'] == docId);
        if (index != -1) {
          setState(() {
            _phoneSales[index].addAll(updates);
          });
        }
        break;
      case 'accessories_service_sales':
        final index = _accessoriesServiceSales.indexWhere(
          (sale) => sale['id'] == docId,
        );
        if (index != -1) {
          setState(() {
            _accessoriesServiceSales[index].addAll(updates);
          });
        }
        break;
      case 'base_model_sale':
        final index = _baseModelSales.indexWhere((sale) => sale['id'] == docId);
        if (index != -1) {
          setState(() {
            _baseModelSales[index].addAll(updates);
          });
        }
        break;
      case 'seconds_phone_sale':
        final index = _secondsPhoneSales.indexWhere(
          (sale) => sale['id'] == docId,
        );
        if (index != -1) {
          setState(() {
            _secondsPhoneSales[index].addAll(updates);
          });
        }
        break;
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = _getFilteredDataForCurrentTab();
    final allData = _getAllDataForCurrentTab();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Verification'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            setState(() {
              _isDrawerOpen = !_isDrawerOpen;
            });
          },
        ),
        actions: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: _isLoading ? Colors.grey : Colors.white,
                ),
                onPressed: _isLoading ? null : _loadAllData,
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
      body: Row(
        children: [
          _isDrawerOpen
              ? Container(
                  width: 250,
                  color: Colors.green[900],
                  child: _buildSidebar(),
                )
              : const SizedBox.shrink(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCurrentTab(filteredData, allData),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final overdueCount = _getOverdueSales().length;

    return Container(
      color: Colors.green[900],
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Payment Verification',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSidebarItem(
                    icon: Icons.phone_iphone,
                    label: 'Phones',
                    index: 0,
                    count: _filterByShop(_phoneSales).length,
                    totalCount: _phoneSales.length,
                    verifiedCount: _phoneSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                  ),
                  _buildSidebarItem(
                    icon: Icons.phone_android,
                    label: '2nd Hand',
                    index: 1,
                    count: _filterByShop(_secondsPhoneSales).length,
                    totalCount: _secondsPhoneSales.length,
                    verifiedCount: _secondsPhoneSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                  ),
                  _buildSidebarItem(
                    icon: Icons.phone,
                    label: 'Base Models',
                    index: 2,
                    count: _filterByShop(_baseModelSales).length,
                    totalCount: _baseModelSales.length,
                    verifiedCount: _baseModelSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                  ),
                  _buildSidebarItem(
                    icon: Icons.shopping_cart,
                    label: 'Accessories',
                    index: 3,
                    count: _filterByShop(_accessoriesServiceSales).length,
                    totalCount: _accessoriesServiceSales.length,
                    verifiedCount: _accessoriesServiceSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                  ),
                  _buildSidebarItem(
                    icon: Icons.warning,
                    label: 'Overdue',
                    index: 4,
                    count: _selectedShop != null
                        ? _getOverdueSales()
                              .where(
                                (sale) => _getShopName(sale) == _selectedShop,
                              )
                              .length
                        : overdueCount,
                    totalCount: overdueCount,
                    verifiedCount: 0,
                    isOverdue: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required int index,
    required int count,
    required int totalCount,
    required int verifiedCount,
    bool isOverdue = false,
  }) {
    bool isSelected = _selectedIndex == index;
    double verifiedPercentage = totalCount > 0
        ? (verifiedCount / totalCount * 100)
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? (isOverdue
                  ? Colors.red.withOpacity(0.3)
                  : Colors.white.withOpacity(0.2))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: isOverdue ? Colors.red[300] : Colors.white),
        title: Text(
          label,
          style: TextStyle(
            color: isOverdue ? Colors.red[300] : Colors.white,
            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isOverdue
                ? Colors.red.withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOverdue ? Colors.red : Colors.white,
              width: 1,
            ),
          ),
          child: Text(
            _selectedShop != null && !isOverdue
                ? '$count'
                : '$verifiedCount/$totalCount',
            style: TextStyle(
              color: isOverdue ? Colors.red[300] : Colors.white,
              fontSize: 12,
              fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _isDrawerOpen = false;
          });
        },
        subtitle: !isOverdue && totalCount > 0
            ? Text(
                '${verifiedPercentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildCurrentTab(
    List<Map<String, dynamic>> filteredData,
    List<Map<String, dynamic>> allData,
  ) {
    switch (_selectedIndex) {
      case 0:
        return _buildPhoneSalesVerificationTab(filteredData, allData);
      case 1:
        return _buildSecondsPhoneVerificationTab(filteredData, allData);
      case 2:
        return _buildBaseModelVerificationTab(filteredData, allData);
      case 3:
        return _buildAccessoriesServiceVerificationTab(filteredData, allData);
      case 4:
        return _buildOverdueVerificationTab(filteredData, allData);
      default:
        return _buildPhoneSalesVerificationTab(filteredData, allData);
    }
  }

  Widget _buildPhoneSalesVerificationTab(
    List<Map<String, dynamic>> filteredData,
    List<Map<String, dynamic>> allData,
  ) {
    return _buildMobileListView(
      title: 'Phone Sales',
      filteredData: filteredData,
      allData: allData,
      buildItem: (sale) => _buildPhoneSaleCard(sale),
      emptyMessage: 'No phone sales found',
    );
  }

  Widget _buildSecondsPhoneVerificationTab(
    List<Map<String, dynamic>> filteredData,
    List<Map<String, dynamic>> allData,
  ) {
    return _buildMobileListView(
      title: '2nd Hand Phones',
      filteredData: filteredData,
      allData: allData,
      buildItem: (sale) => _buildGenericSaleCard(
        sale,
        'seconds_phone_sale',
        _getSecondsPhoneDisplayData,
      ),
      emptyMessage: 'No 2nd hand phone sales found',
    );
  }

  Widget _buildBaseModelVerificationTab(
    List<Map<String, dynamic>> filteredData,
    List<Map<String, dynamic>> allData,
  ) {
    return _buildMobileListView(
      title: 'Base Models',
      filteredData: filteredData,
      allData: allData,
      buildItem: (sale) => _buildGenericSaleCard(
        sale,
        'base_model_sale',
        _getBaseModelDisplayData,
      ),
      emptyMessage: 'No base model sales found',
    );
  }

  Widget _buildAccessoriesServiceVerificationTab(
    List<Map<String, dynamic>> filteredData,
    List<Map<String, dynamic>> allData,
  ) {
    return _buildMobileListView(
      title: 'Accessories & Services',
      filteredData: filteredData,
      allData: allData,
      buildItem: (sale) => _buildGenericSaleCard(
        sale,
        'accessories_service_sales',
        _getAccessoriesServiceDisplayData,
      ),
      emptyMessage: 'No accessories or service sales found',
    );
  }

  Widget _buildOverdueVerificationTab(
    List<Map<String, dynamic>> filteredData,
    List<Map<String, dynamic>> allData,
  ) {
    return _buildMobileListView(
      title: 'Overdue Payments (>7 days)',
      filteredData: filteredData,
      allData: allData,
      buildItem: (sale) => _buildOverdueSaleCard(sale),
      emptyMessage: 'No overdue payments found',
    );
  }

  Widget _buildMobileListView({
    required String title,
    required List<Map<String, dynamic>> filteredData,
    required List<Map<String, dynamic>> allData,
    required Widget Function(Map<String, dynamic>) buildItem,
    required String emptyMessage,
  }) {
    return Column(
      children: [
        _buildVerificationSummary(title, filteredData, allData),
        const SizedBox(height: 8),
        _buildShopFilter(),
        const SizedBox(height: 8),
        Expanded(
          child: filteredData.isEmpty
              ? Center(
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12.0),
                  itemCount: filteredData.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: buildItem(filteredData[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildShopFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter by Shop',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[900],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedShop ?? 'All Shops',
                            icon: const Icon(Icons.arrow_drop_down),
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedShop = newValue == 'All Shops'
                                    ? null
                                    : newValue;
                              });
                            },
                            items: _availableShops
                                .map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_selectedShop != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        setState(() {
                          _selectedShop = null;
                        });
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationSummary(
    String title,
    List<Map<String, dynamic>> filteredData,
    List<Map<String, dynamic>> allData,
  ) {
    int total = filteredData.length;
    int verified = filteredData
        .where((sale) => sale['paymentVerified'] == true)
        .length;
    int pending = total - verified;
    double verifiedPercentage = total > 0 ? (verified / total * 100) : 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[900],
                  ),
                ),
                if (_selectedShop != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.store, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          _selectedShop!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMobileSummaryItem(
                  'Total',
                  total.toString(),
                  Icons.list,
                  Colors.green,
                ),
                _buildMobileSummaryItem(
                  'Verified',
                  verified.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildMobileSummaryItem(
                  'Pending',
                  pending.toString(),
                  Icons.pending,
                  Colors.orange,
                ),
                _buildMobileSummaryItem(
                  '%',
                  '${verifiedPercentage.toStringAsFixed(0)}',
                  Icons.percent,
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPhoneSaleCard(Map<String, dynamic> sale) {
    String purchaseMode = (sale['purchaseMode'] ?? '').toString();
    String mode = purchaseMode.toLowerCase();
    bool isEMI = mode == 'emi';
    bool isCash = mode.contains('cash') || mode.isEmpty;
    bool isCard = mode.contains('card');
    bool isUPI =
        mode.contains('upi') ||
        mode.contains('gpay') ||
        mode.contains('phonepe') ||
        mode.contains('paytm');

    double downPayment = (sale['downPayment'] as num?)?.toDouble() ?? 0;
    double disbursement = (sale['disbursementAmount'] as num?)?.toDouble() ?? 0;
    bool downPaymentReceived = sale['downPaymentReceived'] ?? false;
    bool disbursementReceived = sale['disbursementReceived'] ?? false;
    bool paymentVerified = sale['paymentVerified'] ?? false;
    double amount = _getTotalAmount(sale);

    final paymentBreakdown =
        sale['paymentBreakdownVerified'] ??
        {'cash': false, 'card': false, 'gpay': false};

    bool cashVerified = _convertToBool(paymentBreakdown['cash']);
    bool cardVerified = _convertToBool(paymentBreakdown['card']);
    bool gpayVerified = _convertToBool(paymentBreakdown['gpay']);

    String shopName = _getShopName(sale);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
                        sale['customerName'] ?? 'Unknown Customer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sale['customerPhone'] ?? 'No Phone',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_red_eye,
                    color: Colors.green[800],
                    size: 20,
                  ),
                  onPressed: () =>
                      _verifyPayment(_createTransactionFromPhoneSale(sale)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade300, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shop',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${_formatNumber(amount)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sale['brand'] ?? ''} ${sale['productModel'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _buildMobileVerificationChip(paymentVerified),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getPaymentModeColor(purchaseMode),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getPaymentModeBorderColor(purchaseMode),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          purchaseMode.isEmpty ? 'Cash' : purchaseMode,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _getPaymentModeTextColor(purchaseMode),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(sale['saleDate']),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isEMI) ...[
              const SizedBox(height: 8),
              Text(
                'Payment Methods',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[900],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPaymentMethodIndicator('Cash', cashVerified && isCash),
                  _buildPaymentMethodIndicator('Card', cardVerified && isCard),
                  _buildPaymentMethodIndicator('UPI', gpayVerified && isUPI),
                ],
              ),
            ],
            if (isEMI) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade300, height: 1),
              const SizedBox(height: 8),
              Text(
                'EMI Details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[900],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Down Payment',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${_formatNumber(downPayment)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildMobileStatusChip('DP', downPaymentReceived),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disbursement',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${_formatNumber(disbursement)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildMobileStatusChip('DIS', disbursementReceived),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGenericSaleCard(
    Map<String, dynamic> sale,
    String collection,
    Map<String, dynamic> Function(Map<String, dynamic>) getDisplayData,
  ) {
    Map<String, dynamic> displayData = getDisplayData(sale);
    bool paymentVerified = sale['paymentVerified'] ?? false;

    final paymentBreakdown =
        sale['paymentBreakdownVerified'] ??
        {'cash': false, 'card': false, 'gpay': false};

    bool cashVerified = _convertToBool(paymentBreakdown['cash']);
    bool cardVerified = _convertToBool(paymentBreakdown['card']);
    bool gpayVerified = _convertToBool(paymentBreakdown['gpay']);

    String shopName = _getShopName(sale);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
                        displayData['customer']?.isNotEmpty == true
                            ? displayData['customer']
                            : 'Walk-in Customer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayData['description'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_red_eye,
                    color: Colors.green[800],
                    size: 20,
                  ),
                  onPressed: () => _verifyPayment(
                    _createTransactionFromGenericSale(collection, sale),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade300, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shop',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${_formatNumber(displayData['amount'] ?? 0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _buildMobileVerificationChip(paymentVerified),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(displayData['date']),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Payment Methods',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green[900],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPaymentMethodIndicator('Cash', cashVerified),
                _buildPaymentMethodIndicator('Card', cardVerified),
                _buildPaymentMethodIndicator('UPI', gpayVerified),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueSaleCard(Map<String, dynamic> sale) {
    String saleType = '';
    String collection = '';

    if (sale.containsKey('purchaseMode')) {
      saleType = 'Phone Sale';
      collection = 'phoneSales';
    } else if (sale.containsKey('productName') &&
        !sale.containsKey('modelName')) {
      saleType = '2nd Hand Phone';
      collection = 'seconds_phone_sale';
    } else if (sale.containsKey('modelName')) {
      saleType = 'Base Model';
      collection = 'base_model_sale';
    } else if (sale.containsKey('totalSaleAmount')) {
      saleType = 'Accessory/Service';
      collection = 'accessories_service_sales';
    }

    DateTime? saleDate;
    if (sale.containsKey('saleDate')) {
      saleDate = _parseDate(sale['saleDate']);
    } else if (sale.containsKey('date')) {
      saleDate = _parseDate(sale['date']);
    } else if (sale.containsKey('timestamp')) {
      saleDate = _parseDate(sale['timestamp']);
    }

    int daysOverdue = 0;
    if (saleDate != null) {
      final now = DateTime.now();
      daysOverdue = now.difference(saleDate).inDays;
    }

    double amount = _getTotalAmount(sale);
    String shopName = _getShopName(sale);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.withOpacity(0.5), width: 2),
      ),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red[700], size: 18),
                          const SizedBox(width: 8),
                          Text(
                            saleType,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sale['customerName'] ?? 'Walk-in Customer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (sale['customerPhone'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sale['customerPhone'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_red_eye,
                    color: Colors.red[700],
                    size: 20,
                  ),
                  onPressed: () {
                    if (saleType == 'Phone Sale') {
                      _verifyPayment(_createTransactionFromPhoneSale(sale));
                    } else {
                      _verifyPayment(
                        _createTransactionFromGenericSale(collection, sale),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.red.shade300, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shop',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Days Overdue',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red, width: 1),
                        ),
                        child: Text(
                          '$daysOverdue days',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${_formatNumber(amount)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(saleDate),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (sale.containsKey('purchaseMode')) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Mode',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green, width: 1),
                          ),
                          child: Text(
                            sale['purchaseMode'] ?? 'Cash',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                if (saleType == 'Phone Sale') {
                  _verifyPayment(_createTransactionFromPhoneSale(sale));
                } else {
                  _verifyPayment(
                    _createTransactionFromGenericSale(collection, sale),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 36),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user, size: 16),
                  SizedBox(width: 8),
                  Text('Verify Payment Now'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileVerificationChip(bool verified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: verified
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: verified ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.check_circle : Icons.pending,
            size: 12,
            color: verified ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Verified' : 'Pending',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: verified ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStatusChip(String label, bool verified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: verified
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: verified ? Colors.green : Colors.orange,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.check : Icons.close,
            size: 10,
            color: verified ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: verified ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodIndicator(String method, bool verified) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: verified
                ? Colors.green.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: verified ? Colors.green : Colors.grey,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Icon(
              verified ? Icons.check : Icons.close,
              size: 16,
              color: verified ? Colors.green : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          method,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: verified ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getSecondsPhoneDisplayData(Map<String, dynamic> sale) {
    return {
      'customer': sale['customerName'] ?? '',
      'description': sale['productName'] ?? '',
      'amount': (sale['price'] as num?)?.toDouble() ?? 0,
      'date': sale['date'] ?? sale['timestamp'],
    };
  }

  Map<String, dynamic> _getBaseModelDisplayData(Map<String, dynamic> sale) {
    return {
      'customer': sale['customerName'] ?? '',
      'description': sale['modelName'] ?? '',
      'amount': (sale['price'] as num?)?.toDouble() ?? 0,
      'date': sale['date'] ?? sale['timestamp'],
    };
  }

  Map<String, dynamic> _getAccessoriesServiceDisplayData(
    Map<String, dynamic> sale,
  ) {
    return {
      'customer': '',
      'description': 'Accessories & Services',
      'amount': (sale['totalSaleAmount'] as num?)?.toDouble() ?? 0,
      'date': sale['date'] ?? '',
    };
  }

  String _formatNumber(double number) {
    return NumberFormat('#,##0').format(number);
  }

  String _formatDate(dynamic date) {
    try {
      if (date == null) return 'Unknown';

      if (date is Timestamp) {
        return DateFormat('dd/MM/yyyy').format(date.toDate());
      } else if (date is DateTime) {
        return DateFormat('dd/MM/yyyy').format(date);
      } else if (date is String) {
        return date.length > 20 ? date.substring(0, 20) : date;
      } else {
        return date.toString();
      }
    } catch (e) {
      print('Error formatting date: $e');
      return 'Invalid Date';
    }
  }

  Map<String, dynamic> _createTransactionFromPhoneSale(
    Map<String, dynamic> sale,
  ) {
    return {
      'type': 'Phone Sale',
      'description': '${sale['brand'] ?? ''} ${sale['productModel'] ?? ''}',
      'customer': sale['customerName'] ?? '',
      'amount': _getTotalAmount(sale),
      'time': sale['saleDate'],
      'status': 'Completed',
      'paymentVerified': sale['paymentVerified'] ?? false,
      'data': sale,
      'category': 'phone',
      'collection': 'phoneSales',
      'docId': sale['id'],
    };
  }

  Map<String, dynamic> _createTransactionFromGenericSale(
    String collection,
    Map<String, dynamic> sale,
  ) {
    String type = '';
    String description = '';
    double amount = 0;
    dynamic date;

    if (collection == 'seconds_phone_sale') {
      type = '2nd Hand Phone';
      description = sale['productName'] ?? '';
      amount = _getTotalAmount(sale);
      date = sale['date'] ?? sale['timestamp'];
    } else if (collection == 'base_model_sale') {
      type = 'Base Model';
      description = sale['modelName'] ?? '';
      amount = _getTotalAmount(sale);
      date = sale['date'] ?? sale['timestamp'];
    } else if (collection == 'accessories_service_sales') {
      type = 'Accessory/Service';
      description = 'Accessories & Services';
      amount = _getTotalAmount(sale);
      date = sale['date'] ?? '';
    }

    return {
      'type': type,
      'description': description,
      'customer': sale['customerName'] ?? '',
      'amount': amount,
      'time': date,
      'status': 'Completed',
      'paymentVerified': sale['paymentVerified'] ?? false,
      'data': sale,
      'category': collection == 'seconds_phone_sale'
          ? 'seconds'
          : collection == 'base_model_sale'
          ? 'base_model'
          : 'accessories',
      'collection': collection,
      'docId': sale['id'],
    };
  }

  Color _getPaymentModeColor(String purchaseMode) {
    String mode = purchaseMode.toLowerCase();
    switch (mode) {
      case 'emi':
        return Colors.orange.withOpacity(0.1);
      case 'cash':
        return Colors.green.withOpacity(0.1);
      case 'card':
        return Colors.green.withOpacity(0.1);
      case 'upi':
      case 'gpay':
      case 'phonepe':
      case 'paytm':
        return Colors.purple.withOpacity(0.1);
      default:
        return Colors.green.withOpacity(0.1);
    }
  }

  Color _getPaymentModeBorderColor(String purchaseMode) {
    String mode = purchaseMode.toLowerCase();
    switch (mode) {
      case 'emi':
        return Colors.orange;
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.green;
      case 'upi':
      case 'gpay':
      case 'phonepe':
      case 'paytm':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  Color _getPaymentModeTextColor(String purchaseMode) {
    String mode = purchaseMode.toLowerCase();
    switch (mode) {
      case 'emi':
        return Colors.orange;
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.green;
      case 'upi':
      case 'gpay':
      case 'phonepe':
      case 'paytm':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  void _verifyPayment(Map<String, dynamic> transaction) async {
    final Map<String, dynamic> sale = transaction['data'];
    final String collection = transaction['collection'];
    final String docId = transaction['docId'];

    String purchaseMode = (sale['purchaseMode'] ?? 'Cash').toString();
    String mode = purchaseMode.toLowerCase();
    bool isEMI = mode == 'emi';

    if (isEMI) {
      _showEMIVerificationDialog(sale, collection, docId);
    } else if (transaction['category'] == 'phone') {
      _showNonEMIPhoneVerificationDialog(sale, collection, docId, purchaseMode);
    } else {
      // For accessories, base models, and seconds phones
      _showGenericPaymentVerificationDialog(sale, collection, docId);
    }
  }

  void _showEMIVerificationDialog(
    Map<String, dynamic> sale,
    String collection,
    String docId,
  ) {
    double downPayment = (sale['downPayment'] as num?)?.toDouble() ?? 0;
    double disbursement = (sale['disbursementAmount'] as num?)?.toDouble() ?? 0;
    double discount = (sale['discount'] as num?)?.toDouble() ?? 0;
    double exchangeValue = (sale['exchangeValue'] as num?)?.toDouble() ?? 0;
    double price = (sale['price'] as num?)?.toDouble() ?? 0;
    double effectivePrice = (sale['effectivePrice'] as num?)?.toDouble() ?? 0;
    double amountToPay = (sale['amountToPay'] as num?)?.toDouble() ?? 0;
    double balanceReturned =
        (sale['balanceReturnedToCustomer'] as num?)?.toDouble() ?? 0;
    double customerCredit = (sale['customerCredit'] as num?)?.toDouble() ?? 0;

    bool downPaymentReceived = sale['downPaymentReceived'] ?? false;
    bool disbursementReceived = sale['disbursementReceived'] ?? false;
    String shopName = _getShopName(sale);

    final paymentBreakdown =
        sale['paymentBreakdown'] ??
        {'cash': 0, 'card': 0, 'credit': 0, 'gpay': 0};
    final paymentBreakdownVerified =
        sale['paymentBreakdownVerified'] ??
        {'cash': false, 'card': false, 'gpay': false};

    double cashAmount = _extractAmount(paymentBreakdown, ['cash']);
    double cardAmount = _extractAmount(paymentBreakdown, ['card']);
    double creditAmount = _extractAmount(paymentBreakdown, ['credit']);
    double gpayAmount = _extractAmount(paymentBreakdown, ['gpay']);

    bool cashVerified = _convertToBool(paymentBreakdownVerified['cash']);
    bool cardVerified = _convertToBool(paymentBreakdownVerified['card']);
    bool gpayVerified = _convertToBool(paymentBreakdownVerified['gpay']);

    DateTime? addedAt;
    if (sale['addedAt'] != null) {
      addedAt = _parseDate(sale['addedAt']);
    } else if (sale['createdAt'] != null) {
      addedAt = _parseDate(sale['createdAt']);
    } else if (sale['saleDate'] != null) {
      addedAt = _parseDate(sale['saleDate']);
    }

    showDialog(
      context: context,
      builder: (context) {
        bool localDownPaymentReceived = downPaymentReceived;
        bool localDisbursementReceived = disbursementReceived;
        bool localCashVerified = cashVerified;
        bool localCardVerified = cardVerified;
        bool localGpayVerified = gpayVerified;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Verify EMI Payment'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer: ${sale['customerName'] ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Shop: $shopName',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Product: ${sale['brand'] ?? ''} ${sale['productModel'] ?? ''}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'finance: ${sale['financeType'] ?? ''} ',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price Breakdown',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[900],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Original Price:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  '₹${_formatNumber(price)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (discount > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Discount:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  Text(
                                    '-₹${_formatNumber(discount)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (exchangeValue > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Exchange Value:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                  Text(
                                    '-₹${_formatNumber(exchangeValue)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (customerCredit > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Customer Credit:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple.shade700,
                                    ),
                                  ),
                                  Text(
                                    '-₹${_formatNumber(customerCredit)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.purple.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Divider(color: Colors.grey.shade300, height: 1),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Effective Price:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[900],
                                  ),
                                ),
                                Text(
                                  '₹${_formatNumber(effectivePrice)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[900],
                                  ),
                                ),
                              ],
                            ),
                            if (balanceReturned > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Balance Returned:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  Text(
                                    '₹${_formatNumber(balanceReturned)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Amount to Pay:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[900],
                                  ),
                                ),
                                Text(
                                  '₹${_formatNumber(amountToPay)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[900],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Down Payment',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[900],
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Amount:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  '₹${_formatNumber(downPayment)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: localDownPaymentReceived,
                            onChanged: (value) {
                              setState(() {
                                localDownPaymentReceived = value;
                              });
                            },
                            activeColor: Colors.green,
                          ),
                        ],
                      ),

                      if (downPayment > 0 && localDownPaymentReceived) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Down Payment Breakdown',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (cashAmount > 0)
                          _buildEMIPaymentBreakdownRow(
                            'Cash',
                            cashAmount,
                            localCashVerified,
                            (value) {
                              setState(() {
                                localCashVerified = value;
                              });
                            },
                          ),

                        if (cardAmount > 0)
                          _buildEMIPaymentBreakdownRow(
                            'Card',
                            cardAmount,
                            localCardVerified,
                            (value) {
                              setState(() {
                                localCardVerified = value;
                              });
                            },
                          ),

                        if (gpayAmount > 0)
                          _buildEMIPaymentBreakdownRow(
                            'UPI',
                            gpayAmount,
                            localGpayVerified,
                            (value) {
                              setState(() {
                                localGpayVerified = value;
                              });
                            },
                          ),

                        if (creditAmount > 0)
                          _buildEMICreditPaymentRow(creditAmount),
                      ],

                      const SizedBox(height: 16),

                      Text(
                        'Disbursement',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[900],
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Amount:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  '₹${_formatNumber(disbursement)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: localDisbursementReceived,
                            onChanged: (value) {
                              setState(() {
                                localDisbursementReceived = value;
                              });
                            },
                            activeColor: Colors.green,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Transaction Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[900],
                        ),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (addedAt != null) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Added At:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat(
                                  'dd MMMM yyyy, HH:mm:ss',
                                ).format(addedAt!),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],

                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Added By:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sale['userEmail'] ?? 'Unknown',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              (localDownPaymentReceived &&
                                  localDisbursementReceived)
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                (localDownPaymentReceived &&
                                    localDisbursementReceived)
                                ? Colors.green
                                : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (localDownPaymentReceived &&
                                      localDisbursementReceived)
                                  ? Icons.check_circle
                                  : Icons.info,
                              color:
                                  (localDownPaymentReceived &&
                                      localDisbursementReceived)
                                  ? Colors.green
                                  : Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (localDownPaymentReceived &&
                                            localDisbursementReceived)
                                        ? 'Fully Verified'
                                        : 'Partial Verification',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          (localDownPaymentReceived &&
                                              localDisbursementReceived)
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Down Payment: ${localDownPaymentReceived ? '✓' : '✗'} | '
                                    'Disbursement: ${localDisbursementReceived ? '✓' : '✗'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final updates = <String, dynamic>{
                        'downPaymentReceived': localDownPaymentReceived,
                        'disbursementReceived': localDisbursementReceived,
                        'paymentVerified':
                            localDownPaymentReceived &&
                            localDisbursementReceived,
                      };

                      if (localDownPaymentReceived) {
                        updates['paymentBreakdownVerified'] = {
                          'cash': localCashVerified,
                          'card': localCardVerified,
                          'gpay': localGpayVerified,
                        };
                      }

                      await _updatePaymentVerification(
                        collection,
                        docId,
                        updates,
                      );

                      // Update local state immediately
                      final index = _phoneSales.indexWhere(
                        (s) => s['id'] == docId,
                      );
                      if (index != -1) {
                        setState(() {
                          _phoneSales[index].addAll(updates);
                        });
                      }

                      Navigator.pop(context);
                      _showSnackBar(
                        'EMI payment verified successfully',
                        Colors.green,
                      );
                    } catch (e) {
                      _showSnackBar('Error: $e', Colors.red);
                    }
                  },
                  child: const Text('Save & Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNonEMIPhoneVerificationDialog(
    Map<String, dynamic> sale,
    String collection,
    String docId,
    String purchaseMode,
  ) {
    final paymentBreakdown =
        sale['paymentBreakdown'] ??
        {'cash': 0, 'card': 0, 'credit': 0, 'gpay': 0};

    final paymentBreakdownVerified =
        sale['paymentBreakdownVerified'] ??
        {'cash': false, 'card': false, 'gpay': false};

    bool cashVerified = _convertToBool(paymentBreakdownVerified['cash']);
    bool cardVerified = _convertToBool(paymentBreakdownVerified['card']);
    bool gpayVerified = _convertToBool(paymentBreakdownVerified['gpay']);

    String shopName = _getShopName(sale);
    String mode = purchaseMode.toLowerCase();

    double exchangeValue = (sale['exchangeValue'] as num?)?.toDouble() ?? 0;
    double discount = (sale['discount'] as num?)?.toDouble() ?? 0;
    double totalAmount = _getTotalAmount(sale);
    double price = (sale['price'] as num?)?.toDouble() ?? 0;
    double effectivePrice = (sale['effectivePrice'] as num?)?.toDouble() ?? 0;
    double amountToPay = (sale['amountToPay'] as num?)?.toDouble() ?? 0;

    double cashAmount = _extractAmount(sale, ['cashAmount', 'cash']);
    double cardAmount = _extractAmount(sale, ['cardAmount', 'card']);
    double gpayAmount = _extractAmount(sale, [
      'gpayAmount',
      'upiAmount',
      'gpay',
      'upi',
    ]);
    double creditAmount = _extractAmount(sale, ['creditAmount', 'credit']);

    if (paymentBreakdown is Map) {
      Map<String, dynamic> stringKeyMap = {};
      paymentBreakdown.forEach((key, value) {
        stringKeyMap[key.toString()] = value;
      });

      cashAmount = _extractAmount(stringKeyMap, ['cash']);
      cardAmount = _extractAmount(stringKeyMap, ['card']);
      gpayAmount = _extractAmount(stringKeyMap, ['gpay']);
      creditAmount = _extractAmount(stringKeyMap, ['credit']);
    }

    showDialog(
      context: context,
      builder: (context) {
        bool localCashVerified = cashVerified;
        bool localCardVerified = cardVerified;
        bool localGpayVerified = gpayVerified;

        return StatefulBuilder(
          builder: (context, setState) {
            double verifiedAmount = 0;
            if (localCashVerified) verifiedAmount += cashAmount;
            if (localCardVerified) verifiedAmount += cardAmount;
            if (localGpayVerified) verifiedAmount += gpayAmount;

            double expectedAmount = amountToPay > 0
                ? amountToPay
                : effectivePrice;
            if (expectedAmount <= 0) expectedAmount = totalAmount;

            bool isFullyVerified =
                (verifiedAmount - expectedAmount).abs() < 0.01;

            return AlertDialog(
              title: const Text('Verify Phone Sale Payment'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer: ${sale['customerName'] ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Shop: $shopName',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Product: ${sale['brand'] ?? ''} ${sale['productModel'] ?? ''}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Phone: ${sale['customerPhone'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price Details',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[900],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Original Price:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  '₹${_formatNumber(price)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (discount > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Discount:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  Text(
                                    '-₹${_formatNumber(discount)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (exchangeValue > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Exchange Value:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                  Text(
                                    '-₹${_formatNumber(exchangeValue)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Divider(color: Colors.grey.shade300, height: 1),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Amount to Pay:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[900],
                                  ),
                                ),
                                Text(
                                  '₹${_formatNumber(expectedAmount)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[900],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Payment Breakdown',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[900],
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (cashAmount > 0) ...[
                        _buildPaymentMethodRowWithAmount(
                          'Cash',
                          cashAmount,
                          localCashVerified,
                          (value) {
                            setState(() {
                              localCashVerified = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (cardAmount > 0) ...[
                        _buildPaymentMethodRowWithAmount(
                          'Card',
                          cardAmount,
                          localCardVerified,
                          (value) {
                            setState(() {
                              localCardVerified = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (gpayAmount > 0) ...[
                        _buildPaymentMethodRowWithAmount(
                          'UPI',
                          gpayAmount,
                          localGpayVerified,
                          (value) {
                            setState(() {
                              localGpayVerified = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (creditAmount > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Credit',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    '₹${_formatNumber(creditAmount)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Pending',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isFullyVerified
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isFullyVerified
                                ? Colors.green
                                : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isFullyVerified ? Icons.check_circle : Icons.info,
                              color: isFullyVerified
                                  ? Colors.green
                                  : Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isFullyVerified
                                        ? 'Fully Verified'
                                        : 'Partial Verification',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isFullyVerified
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Verified: ₹${_formatNumber(verifiedAmount)} / ₹${_formatNumber(expectedAmount)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final newPaymentBreakdown = {
                        'cash': localCashVerified,
                        'card': localCardVerified,
                        'gpay': localGpayVerified,
                      };

                      bool isVerified = isFullyVerified;

                      final updates = <String, dynamic>{
                        'paymentBreakdownVerified': newPaymentBreakdown,
                        'paymentVerified': isVerified,
                      };

                      await _updatePaymentVerification(
                        collection,
                        docId,
                        updates,
                      );

                      // Update local state immediately
                      final index = _phoneSales.indexWhere(
                        (s) => s['id'] == docId,
                      );
                      if (index != -1) {
                        setState(() {
                          _phoneSales[index].addAll(updates);
                        });
                      }

                      Navigator.pop(context);
                      _showSnackBar(
                        isVerified
                            ? 'Payment fully verified successfully!'
                            : 'Payment partially verified',
                        isVerified ? Colors.green : Colors.orange,
                      );
                    } catch (e) {
                      _showSnackBar('Error: $e', Colors.red);
                    }
                  },
                  child: const Text('Save & Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGenericPaymentVerificationDialog(
    Map<String, dynamic> sale,
    String collection,
    String docId,
  ) {
    final paymentBreakdown = sale['paymentBreakdownVerified'];

    bool initialCashVerified = false;
    bool initialCardVerified = false;
    bool initialGpayVerified = false;

    if (paymentBreakdown is Map) {
      initialCashVerified = _convertToBool(paymentBreakdown['cash']);
      initialCardVerified = _convertToBool(paymentBreakdown['card']);
      initialGpayVerified = _convertToBool(paymentBreakdown['gpay']);
    }

    final paymentAmounts = _getPaymentAmounts(collection, sale);
    final cashAmount = paymentAmounts['cash']!;
    final cardAmount = paymentAmounts['card']!;
    final gpayAmount = paymentAmounts['gpay']!;

    final totalAmount = _getTotalAmount(sale);
    final shopName = _getShopName(sale);

    final hasMultiplePayments =
        (cashAmount > 0 && cardAmount > 0) ||
        (cashAmount > 0 && gpayAmount > 0) ||
        (cardAmount > 0 && gpayAmount > 0);

    final isAccessories = collection == 'accessories_service_sales';
    final useSwitches = isAccessories && hasMultiplePayments;

    showDialog(
      context: context,
      builder: (context) {
        return _GenericPaymentVerificationDialog(
          sale: sale,
          collection: collection,
          docId: docId,
          shopName: shopName,
          totalAmount: totalAmount,
          cashAmount: cashAmount,
          cardAmount: cardAmount,
          gpayAmount: gpayAmount,
          initialCashVerified: initialCashVerified,
          initialCardVerified: initialCardVerified,
          initialGpayVerified: initialGpayVerified,
          useSwitches: useSwitches,
          onUpdate: (newPaymentBreakdown, isVerified) async {
            try {
              final updates = <String, dynamic>{
                'paymentBreakdownVerified': newPaymentBreakdown,
                'paymentVerified': isVerified,
              };

              await _updatePaymentVerification(collection, docId, updates);

              // Update local state immediately
              List<Map<String, dynamic>> targetList;
              switch (collection) {
                case 'accessories_service_sales':
                  targetList = _accessoriesServiceSales;
                  break;
                case 'base_model_sale':
                  targetList = _baseModelSales;
                  break;
                case 'seconds_phone_sale':
                  targetList = _secondsPhoneSales;
                  break;
                default:
                  targetList = _phoneSales;
              }

              final index = targetList.indexWhere(
                (item) => item['id'] == docId,
              );
              if (index != -1) {
                setState(() {
                  targetList[index].addAll(updates);
                });
              }

              return true;
            } catch (e) {
              print('Error updating: $e');
              return false;
            }
          },
        );
      },
    );
  }

  Widget _buildPaymentMethodRowWithAmount(
    String method,
    double amount,
    bool verified,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: verified ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: verified ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$method Payment',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: verified ? Colors.green : Colors.black,
                  ),
                ),
                Text(
                  '₹${_formatNumber(amount)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: verified ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: verified,
            onChanged: onChanged,
            activeColor: Colors.green,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildEMIPaymentBreakdownRow(
    String method,
    double amount,
    bool verified,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: verified ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: verified ? Colors.green : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: verified ? Colors.green : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${_formatNumber(amount)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: verified ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: verified,
            onChanged: onChanged,
            activeColor: Colors.green,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.shade300,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildEMICreditPaymentRow(double amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${_formatNumber(amount)}',
                  style: TextStyle(fontSize: 11, color: Colors.green),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Pending',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenericPaymentVerificationDialog extends StatefulWidget {
  final Map<String, dynamic> sale;
  final String collection;
  final String docId;
  final String shopName;
  final double totalAmount;
  final double cashAmount;
  final double cardAmount;
  final double gpayAmount;
  final bool initialCashVerified;
  final bool initialCardVerified;
  final bool initialGpayVerified;
  final bool useSwitches;
  final Future<bool> Function(Map<String, dynamic>, bool) onUpdate;

  const _GenericPaymentVerificationDialog({
    required this.sale,
    required this.collection,
    required this.docId,
    required this.shopName,
    required this.totalAmount,
    required this.cashAmount,
    required this.cardAmount,
    required this.gpayAmount,
    required this.initialCashVerified,
    required this.initialCardVerified,
    required this.initialGpayVerified,
    required this.useSwitches,
    required this.onUpdate,
  });

  @override
  __GenericPaymentVerificationDialogState createState() =>
      __GenericPaymentVerificationDialogState();
}

class __GenericPaymentVerificationDialogState
    extends State<_GenericPaymentVerificationDialog> {
  late bool _cashVerified;
  late bool _cardVerified;
  late bool _gpayVerified;

  @override
  void initState() {
    super.initState();
    _cashVerified = widget.initialCashVerified;
    _cardVerified = widget.initialCardVerified;
    _gpayVerified = widget.initialGpayVerified;
  }

  double _calculateVerifiedAmount() {
    double verified = 0;
    if (_cashVerified) verified += widget.cashAmount;
    if (_cardVerified) verified += widget.cardAmount;
    if (_gpayVerified) verified += widget.gpayAmount;
    return verified;
  }

  bool _isFullyVerified() {
    final verifiedAmount = _calculateVerifiedAmount();
    return (verifiedAmount - widget.totalAmount).abs() < 0.01;
  }

  String _formatNumber(double number) {
    return NumberFormat('#,##0').format(number);
  }

  @override
  Widget build(BuildContext context) {
    final verifiedAmount = _calculateVerifiedAmount();
    final isFullyVerified = _isFullyVerified();

    return AlertDialog(
      title: const Text('Verify Payment'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer: ${widget.sale['customerName'] ?? 'Walk-in'}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Shop: ${widget.shopName}',
                style: const TextStyle(fontSize: 14),
              ),
              if (widget.sale.containsKey('modelName')) ...[
                Text(
                  'Model: ${widget.sale['modelName']}',
                  style: const TextStyle(fontSize: 14),
                ),
              ] else if (widget.sale.containsKey('productName')) ...[
                Text(
                  'Product: ${widget.sale['productName']}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              Text(
                'Total: ₹${_formatNumber(widget.totalAmount)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              if (widget.cashAmount > 0) ...[
                if (widget.useSwitches)
                  _buildSwitchPaymentRow(
                    'Cash',
                    widget.cashAmount,
                    _cashVerified,
                    (value) {
                      setState(() {
                        _cashVerified = value;
                      });
                    },
                  )
                else
                  _buildRadioPaymentRow(
                    'Cash',
                    widget.cashAmount,
                    _cashVerified,
                    (value) {
                      setState(() {
                        _cashVerified = value;
                        if (value) {
                          _cardVerified = false;
                          _gpayVerified = false;
                        }
                      });
                    },
                  ),
                const SizedBox(height: 12),
              ],

              if (widget.cardAmount > 0) ...[
                if (widget.useSwitches)
                  _buildSwitchPaymentRow(
                    'Card',
                    widget.cardAmount,
                    _cardVerified,
                    (value) {
                      setState(() {
                        _cardVerified = value;
                      });
                    },
                  )
                else
                  _buildRadioPaymentRow(
                    'Card',
                    widget.cardAmount,
                    _cardVerified,
                    (value) {
                      setState(() {
                        _cardVerified = value;
                        if (value) {
                          _cashVerified = false;
                          _gpayVerified = false;
                        }
                      });
                    },
                  ),
                const SizedBox(height: 12),
              ],

              if (widget.gpayAmount > 0) ...[
                if (widget.useSwitches)
                  _buildSwitchPaymentRow(
                    'UPI',
                    widget.gpayAmount,
                    _gpayVerified,
                    (value) {
                      setState(() {
                        _gpayVerified = value;
                      });
                    },
                  )
                else
                  _buildRadioPaymentRow(
                    'UPI',
                    widget.gpayAmount,
                    _gpayVerified,
                    (value) {
                      setState(() {
                        _gpayVerified = value;
                        if (value) {
                          _cashVerified = false;
                          _cardVerified = false;
                        }
                      });
                    },
                  ),
              ],

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFullyVerified
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFullyVerified ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFullyVerified ? Icons.check_circle : Icons.info,
                      color: isFullyVerified ? Colors.green : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFullyVerified
                                ? 'Fully Verified'
                                : 'Partial Verification',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isFullyVerified
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verified: ₹${_formatNumber(verifiedAmount)} / ₹${_formatNumber(widget.totalAmount)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final newPaymentBreakdown = {
              'cash': _cashVerified,
              'card': _cardVerified,
              'gpay': _gpayVerified,
            };

            final isVerified = _isFullyVerified();

            final success = await widget.onUpdate(
              newPaymentBreakdown,
              isVerified,
            );

            if (success) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isVerified
                        ? 'Payment fully verified successfully!'
                        : 'Payment partially verified',
                  ),
                  backgroundColor: isVerified ? Colors.green : Colors.orange,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to update payment verification'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Save & Update'),
        ),
      ],
    );
  }

  Widget _buildSwitchPaymentRow(
    String method,
    double amount,
    bool verified,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: verified ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: verified ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$method Payment',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: verified ? Colors.green : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_formatNumber(amount)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: verified ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: verified,
            onChanged: onChanged,
            activeColor: Colors.green,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildRadioPaymentRow(
    String method,
    double amount,
    bool selected,
    ValueChanged<bool> onChanged,
  ) {
    return InkWell(
      onTap: () {
        onChanged(!selected);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? Colors.green.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.green : Colors.grey,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: selected,
              onChanged: (value) {
                onChanged(value ?? false);
              },
              activeColor: Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.green : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_formatNumber(amount)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.green : Colors.grey,
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
}

// Add the UserDashboard class at the end of the file
