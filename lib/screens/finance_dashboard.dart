import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sales_stock/screens/finance_dashboard_tabs//finance_dashboard_sidebar.dart';
import 'package:sales_stock/screens/finance_dashboard_tabs/dialogs/emi_payment_dialog.dart';
import 'package:sales_stock/screens/finance_dashboard_tabs/dialogs/non_emi_payment_dialog.dart';
import 'package:sales_stock/screens/finance_dashboard_tabs/phone_sales_verification.dart';
import 'package:sales_stock/screens/finance_dashboard_tabs/seconds_phone_verification.dart';
import 'package:sales_stock/screens/finance_dashboard_tabs/base_model_verification.dart';
import 'package:sales_stock/screens/finance_dashboard_tabs/accessories_service_verification.dart';
import 'package:sales_stock/screens/finance_dashboard_tabs/overdue_verification.dart';

import 'package:sales_stock/screens/finance_dashboard_tabs/dialogs/generic_payment_dialog.dart';
import 'package:sales_stock/screens/login_screen.dart'; // Add this import
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

// Define the primary color constant
final Color primaryGreen = Color(0xFF0A4D2E);

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
      showDialog(
        context: context,
        builder: (context) => EMIPaymentDialog(
          sale: sale,
          collection: collection,
          docId: docId,
          getShopName: _getShopName,
          getTotalAmount: _getTotalAmount,
          extractAmount: _extractAmount,
          formatNumber: _formatNumber,
          parseDate: _parseDate,
          onUpdate: _updatePaymentVerification,
          onSuccess: () {
            final index = _phoneSales.indexWhere((s) => s['id'] == docId);
            if (index != -1) {
              setState(() {});
            }
          },
        ),
      );
    } else if (transaction['category'] == 'phone') {
      showDialog(
        context: context,
        builder: (context) => NonEMIPaymentDialog(
          sale: sale,
          collection: collection,
          docId: docId,
          getShopName: _getShopName,
          getTotalAmount: _getTotalAmount,
          extractAmount: _extractAmount,
          formatNumber: _formatNumber,
          convertToBool: _convertToBool,
          onUpdate: _updatePaymentVerification,
          onSuccess: () {
            final index = _phoneSales.indexWhere((s) => s['id'] == docId);
            if (index != -1) {
              setState(() {});
            }
          },
        ),
      );
    } else {
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
      final hasMultiplePayments =
          (paymentAmounts['cash']! > 0 && paymentAmounts['card']! > 0) ||
          (paymentAmounts['cash']! > 0 && paymentAmounts['gpay']! > 0) ||
          (paymentAmounts['card']! > 0 && paymentAmounts['gpay']! > 0);

      final isAccessories = collection == 'accessories_service_sales';
      final useSwitches = isAccessories && hasMultiplePayments;

      showDialog(
        context: context,
        builder: (context) => GenericPaymentDialog(
          sale: sale,
          collection: collection,
          docId: docId,
          shopName: _getShopName(sale),
          totalAmount: _getTotalAmount(sale),
          cashAmount: paymentAmounts['cash']!,
          cardAmount: paymentAmounts['card']!,
          gpayAmount: paymentAmounts['gpay']!,
          initialCashVerified: initialCashVerified,
          initialCardVerified: initialCardVerified,
          initialGpayVerified: initialGpayVerified,
          useSwitches: useSwitches,
          formatNumber: _formatNumber,
          onUpdate: (newPaymentBreakdown, isVerified) async {
            try {
              final updates = <String, dynamic>{
                'paymentBreakdownVerified': newPaymentBreakdown,
                'paymentVerified': isVerified,
              };

              await _updatePaymentVerification(collection, docId, updates);

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
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = _getFilteredDataForCurrentTab();
    final allData = _getAllDataForCurrentTab();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment Verification',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryGreen, // Use the primaryGreen color
        foregroundColor: Colors.white, // Make icons white
        leading: IconButton(
          icon: const Icon(
            Icons.menu,
            color: Colors.white, // Explicitly set icon color to white
          ),
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
                  // Clear data before logout

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
                  color: primaryGreen, // Use primaryGreen for sidebar
                  child: FinanceDashboardSidebar(
                    selectedIndex: _selectedIndex,
                    phoneSales: _phoneSales,
                    secondsPhoneSales: _secondsPhoneSales,
                    baseModelSales: _baseModelSales,
                    accessoriesServiceSales: _accessoriesServiceSales,
                    selectedShop: _selectedShop,
                    getShopName: _getShopName,
                    onIndexChanged: (index) {
                      setState(() {
                        _selectedIndex = index;
                        _isDrawerOpen = false;
                      });
                    },
                  ),
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

  Widget _buildCurrentTab(
    List<Map<String, dynamic>> filteredData,
    List<Map<String, dynamic>> allData,
  ) {
    switch (_selectedIndex) {
      case 0:
        return PhoneSalesVerificationTab(
          filteredData: filteredData,
          allData: allData,
          selectedShop: _selectedShop,
          availableShops: _availableShops,
          onShopChanged: (shop) {
            setState(() {
              _selectedShop = shop == 'All Shops' ? null : shop;
            });
          },
          onVerifyPayment: _verifyPayment,
          getShopName: _getShopName,
          getTotalAmount: _getTotalAmount,
          formatNumber: _formatNumber,
          formatDate: _formatDate,
          getPaymentModeColor: _getPaymentModeColor,
          getPaymentModeBorderColor: _getPaymentModeBorderColor,
          getPaymentModeTextColor: _getPaymentModeTextColor,
          convertToBool: _convertToBool,
          createTransaction: _createTransactionFromPhoneSale,
        );
      case 1:
        return SecondsPhoneVerificationTab(
          filteredData: filteredData,
          allData: allData,
          selectedShop: _selectedShop,
          availableShops: _availableShops,
          onShopChanged: (shop) {
            setState(() {
              _selectedShop = shop == 'All Shops' ? null : shop;
            });
          },
          onVerifyPayment: _verifyPayment,
          getShopName: _getShopName,
          getTotalAmount: _getTotalAmount,
          formatNumber: _formatNumber,
          formatDate: _formatDate,
          convertToBool: _convertToBool,
          createTransaction: (sale) =>
              _createTransactionFromGenericSale('seconds_phone_sale', sale),
        );
      case 2:
        return BaseModelVerificationTab(
          filteredData: filteredData,
          allData: allData,
          selectedShop: _selectedShop,
          availableShops: _availableShops,
          onShopChanged: (shop) {
            setState(() {
              _selectedShop = shop == 'All Shops' ? null : shop;
            });
          },
          onVerifyPayment: _verifyPayment,
          getShopName: _getShopName,
          getTotalAmount: _getTotalAmount,
          formatNumber: _formatNumber,
          formatDate: _formatDate,
          convertToBool: _convertToBool,
          createTransaction: (sale) =>
              _createTransactionFromGenericSale('base_model_sale', sale),
        );
      case 3:
        return AccessoriesServiceVerificationTab(
          filteredData: filteredData,
          allData: allData,
          selectedShop: _selectedShop,
          availableShops: _availableShops,
          onShopChanged: (shop) {
            setState(() {
              _selectedShop = shop == 'All Shops' ? null : shop;
            });
          },
          onVerifyPayment: _verifyPayment,
          getShopName: _getShopName,
          getTotalAmount: _getTotalAmount,
          formatNumber: _formatNumber,
          formatDate: _formatDate,
          convertToBool: _convertToBool,
          createTransaction: (sale) => _createTransactionFromGenericSale(
            'accessories_service_sales',
            sale,
          ),
        );
      case 4:
        return OverdueVerificationTab(
          filteredData: filteredData,
          allData: allData,
          selectedShop: _selectedShop,
          availableShops: _availableShops,
          onShopChanged: (shop) {
            setState(() {
              _selectedShop = shop == 'All Shops' ? null : shop;
            });
          },
          onVerifyPayment: _verifyPayment,
          getShopName: _getShopName,
          getTotalAmount: _getTotalAmount,
          formatNumber: _formatNumber,
          formatDate: _formatDate,
          parseDate: _parseDate,
          createTransaction: (sale) {
            if (sale.containsKey('purchaseMode')) {
              return _createTransactionFromPhoneSale(sale);
            } else if (sale.containsKey('productName') &&
                !sale.containsKey('modelName')) {
              return _createTransactionFromGenericSale(
                'seconds_phone_sale',
                sale,
              );
            } else if (sale.containsKey('modelName')) {
              return _createTransactionFromGenericSale('base_model_sale', sale);
            } else if (sale.containsKey('totalSaleAmount')) {
              return _createTransactionFromGenericSale(
                'accessories_service_sales',
                sale,
              );
            }
            return _createTransactionFromPhoneSale(sale);
          },
        );
      default:
        return PhoneSalesVerificationTab(
          filteredData: filteredData,
          allData: allData,
          selectedShop: _selectedShop,
          availableShops: _availableShops,
          onShopChanged: (shop) {
            setState(() {
              _selectedShop = shop == 'All Shops' ? null : shop;
            });
          },
          onVerifyPayment: _verifyPayment,
          getShopName: _getShopName,
          getTotalAmount: _getTotalAmount,
          formatNumber: _formatNumber,
          formatDate: _formatDate,
          getPaymentModeColor: _getPaymentModeColor,
          getPaymentModeBorderColor: _getPaymentModeBorderColor,
          getPaymentModeTextColor: _getPaymentModeTextColor,
          convertToBool: _convertToBool,
          createTransaction: _createTransactionFromPhoneSale,
        );
    }
  }
}
