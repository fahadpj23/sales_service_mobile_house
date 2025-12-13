import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FinanceDashboardApp());
}

class FinanceDashboardApp extends StatelessWidget {
  const FinanceDashboardApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Colors.blue[900],
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[900],
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
            backgroundColor: Colors.blue[800],
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
      home: const FinanceDashboard(),
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

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Data lists
  List<Map<String, dynamic>> _phoneSales = [];
  List<Map<String, dynamic>> _accessoriesServiceSales = [];
  List<Map<String, dynamic>> _baseModelSales = [];
  List<Map<String, dynamic>> _secondsPhoneSales = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // Method to load all data from Firestore
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

      print('Data loaded successfully:');
      print('Phone Sales: ${_phoneSales.length}');
      print('Accessories: ${_accessoriesServiceSales.length}');
      print('Base Models: ${_baseModelSales.length}');
      print('Seconds: ${_secondsPhoneSales.length}');
    } catch (e) {
      print('Error loading data: $e');
      _showSnackBar('Error loading data: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetch PhoneSales collection
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
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching PhoneSales: $e');
      rethrow;
    }
  }

  // Fetch accessories_service_sales collection
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
        _processPaymentBreakdown(data);
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching accessories_service_sales: $e');
      rethrow;
    }
  }

  // Fetch base_model_sale collection
  Future<void> _fetchBaseModelSales() async {
    try {
      final querySnapshot = await _firestore
          .collection('base_model_sale')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      _baseModelSales = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['paymentVerified'] = data['paymentVerified'] ?? false;
        _processPaymentBreakdown(data);
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching base_model_sale: $e');
      rethrow;
    }
  }

  // Fetch seconds_phone_sale collection
  Future<void> _fetchSecondsPhoneSales() async {
    try {
      final querySnapshot = await _firestore
          .collection('seconds_phone_sale')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      _secondsPhoneSales = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['paymentVerified'] = data['paymentVerified'] ?? false;
        _processPaymentBreakdown(data);
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching seconds_phone_sale: $e');
      rethrow;
    }
  }

  void _processPaymentBreakdown(Map<String, dynamic> data) {
    final paymentBreakdown = data['paymentBreakdownVerified'];
    if (paymentBreakdown is Map) {
      data['paymentBreakdownVerified'] = {
        'cash': _convertToBool(paymentBreakdown['cash']),
        'card': _convertToBool(paymentBreakdown['card']),
        'gpay': _convertToBool(paymentBreakdown['gpay']),
      };
    } else {
      data['paymentBreakdownVerified'] = {
        'cash': false,
        'card': false,
        'gpay': false,
      };
    }
  }

  // Helper method to convert dynamic to bool
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

  // Helper method to extract amount from sale with multiple possible field names
  double _extractAmount(Map<String, dynamic> sale, List<String> fieldNames) {
    for (String fieldName in fieldNames) {
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

  // Helper method to get total amount from sale
  double _getTotalAmount(Map<String, dynamic> sale) {
    // Try different possible field names for total amount
    final possibleFields = [
      'totalSaleAmount',
      'price',
      'amountToPay',
      'totalAmount',
      'saleAmount',
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

  // Helper method to parse date to DateTime
  DateTime? _parseDate(dynamic date) {
    try {
      if (date == null) return null;
      if (date is Timestamp) {
        return date.toDate();
      } else if (date is DateTime) {
        return date;
      } else if (date is String) {
        // Try to parse from common formats
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

  // Get overdue sales (more than 7 days without verification)
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

  // Update payment verification in Firestore
  Future<void> _updatePaymentVerification(
    String collection,
    String docId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection(collection).doc(docId).update(updates);
      print('Payment verification updated successfully');
    } catch (e) {
      print('Error updating payment verification: $e');
      _showSnackBar('Error updating: $e', Colors.red);
      rethrow;
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: _isLoading ? Colors.grey : Colors.white,
            ),
            onPressed: _isLoading ? null : _loadAllData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar Drawer
          _isDrawerOpen
              ? Container(
                  width: 250,
                  color: Colors.blue[900],
                  child: _buildSidebar(),
                )
              : const SizedBox.shrink(),
          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCurrentTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final overdueCount = _getOverdueSales().length;

    return Container(
      color: Colors.blue[900],
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
                    count: _phoneSales.length,
                    verifiedCount: _phoneSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                  ),
                  _buildSidebarItem(
                    icon: Icons.phone_android,
                    label: '2nd Hand',
                    index: 1,
                    count: _secondsPhoneSales.length,
                    verifiedCount: _secondsPhoneSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                  ),
                  _buildSidebarItem(
                    icon: Icons.phone,
                    label: 'Base Models',
                    index: 2,
                    count: _baseModelSales.length,
                    verifiedCount: _baseModelSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                  ),
                  _buildSidebarItem(
                    icon: Icons.shopping_cart,
                    label: 'Accessories',
                    index: 3,
                    count: _accessoriesServiceSales.length,
                    verifiedCount: _accessoriesServiceSales
                        .where((s) => s['paymentVerified'] == true)
                        .length,
                  ),
                  _buildSidebarItem(
                    icon: Icons.warning,
                    label: 'Overdue',
                    index: 4,
                    count: overdueCount,
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
    required int verifiedCount,
    bool isOverdue = false,
  }) {
    bool isSelected = _selectedIndex == index;
    double verifiedPercentage = count > 0 ? (verifiedCount / count * 100) : 0;

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
            isOverdue ? '$count' : '$verifiedCount/$count',
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
        subtitle: !isOverdue && count > 0
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

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return _buildPhoneSalesVerificationTab();
      case 1:
        return _buildSecondsPhoneVerificationTab();
      case 2:
        return _buildBaseModelVerificationTab();
      case 3:
        return _buildAccessoriesServiceVerificationTab();
      case 4:
        return _buildOverdueVerificationTab();
      default:
        return _buildPhoneSalesVerificationTab();
    }
  }

  Widget _buildPhoneSalesVerificationTab() {
    return _buildMobileListView(
      title: 'Phone Sales',
      data: _phoneSales,
      buildItem: (sale) => _buildPhoneSaleCard(sale),
      emptyMessage: 'No phone sales found',
    );
  }

  Widget _buildSecondsPhoneVerificationTab() {
    return _buildMobileListView(
      title: '2nd Hand Phones',
      data: _secondsPhoneSales,
      buildItem: (sale) => _buildGenericSaleCard(
        sale,
        'seconds_phone_sale',
        _getSecondsPhoneDisplayData,
      ),
      emptyMessage: 'No 2nd hand phone sales found',
    );
  }

  Widget _buildBaseModelVerificationTab() {
    return _buildMobileListView(
      title: 'Base Models',
      data: _baseModelSales,
      buildItem: (sale) => _buildGenericSaleCard(
        sale,
        'base_model_sale',
        _getBaseModelDisplayData,
      ),
      emptyMessage: 'No base model sales found',
    );
  }

  Widget _buildAccessoriesServiceVerificationTab() {
    return _buildMobileListView(
      title: 'Accessories & Services',
      data: _accessoriesServiceSales,
      buildItem: (sale) => _buildGenericSaleCard(
        sale,
        'accessories_service_sales',
        _getAccessoriesServiceDisplayData,
      ),
      emptyMessage: 'No accessories or service sales found',
    );
  }

  Widget _buildOverdueVerificationTab() {
    final overdueSales = _getOverdueSales();

    return _buildMobileListView(
      title: 'Overdue Payments (>7 days)',
      data: overdueSales,
      buildItem: (sale) => _buildOverdueSaleCard(sale),
      emptyMessage: 'No overdue payments found',
    );
  }

  Widget _buildMobileListView({
    required String title,
    required List<Map<String, dynamic>> data,
    required Widget Function(Map<String, dynamic>) buildItem,
    required String emptyMessage,
  }) {
    return Column(
      children: [
        _buildVerificationSummary(title, data),
        const SizedBox(height: 8),
        Expanded(
          child: data.isEmpty
              ? Center(
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12.0),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: buildItem(data[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVerificationSummary(
    String title,
    List<Map<String, dynamic>> data,
  ) {
    int total = data.length;
    int verified = data.where((sale) => sale['paymentVerified'] == true).length;
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
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMobileSummaryItem(
                  'Total',
                  total.toString(),
                  Icons.list,
                  Colors.blue,
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
    String purchaseMode = sale['purchaseMode'] ?? '';
    bool isEMI = purchaseMode == 'EMI';
    double downPayment = (sale['downPayment'] as num?)?.toDouble() ?? 0;
    double disbursement = (sale['disbursementAmount'] as num?)?.toDouble() ?? 0;
    bool downPaymentReceived = sale['downPaymentReceived'] ?? false;
    bool disbursementReceived = sale['disbursementReceived'] ?? false;
    bool paymentVerified = sale['paymentVerified'] ?? false;
    double amount = (sale['amountToPay'] as num?)?.toDouble() ?? 0;

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
                    color: Colors.blue[800],
                    size: 20,
                  ),
                  onPressed: () =>
                      _verifyPayment(_createTransactionFromPhoneSale(sale)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey[300], height: 1),
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
                          color: Colors.grey[600],
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
                        'Amount',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
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
                        'Mode',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
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
                          color: isEMI
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isEMI ? Colors.orange : Colors.green,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          purchaseMode.isEmpty ? 'Cash' : purchaseMode,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isEMI ? Colors.orange : Colors.green,
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
                        'Payment',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
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
            if (isEMI) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey[300], height: 1),
              const SizedBox(height: 8),
              Text(
                'EMI Details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
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
                            color: Colors.grey[600],
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
                            color: Colors.grey[600],
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
            const SizedBox(height: 8),
            Text(
              'Date: ${_formatDate(sale['saleDate'])}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
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

    final paymentBreakdown = sale['paymentBreakdownVerified'];
    bool cashVerified = false;
    bool cardVerified = false;
    bool gpayVerified = false;

    if (paymentBreakdown is Map<String, dynamic>) {
      cashVerified = _convertToBool(paymentBreakdown['cash']);
      cardVerified = _convertToBool(paymentBreakdown['card']);
      gpayVerified = _convertToBool(paymentBreakdown['gpay']);
    }

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
                    color: Colors.blue[800],
                    size: 20,
                  ),
                  onPressed: () => _verifyPayment(
                    _createTransactionFromGenericSale(collection, sale),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey[300], height: 1),
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
                          color: Colors.grey[600],
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
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
            const SizedBox(height: 12),
            Text(
              'Payment Methods',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPaymentMethodIndicator('Cash', cashVerified),
                _buildPaymentMethodIndicator('Card', cardVerified),
                _buildPaymentMethodIndicator('GPay', gpayVerified),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${_formatDate(displayData['date'])}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueSaleCard(Map<String, dynamic> sale) {
    // Determine sale type
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

    // Calculate days overdue
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

    // Get amount
    double amount = _getTotalAmount(sale);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.withOpacity(0.5), width: 2),
      ),
      color: Colors.red[50],
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
            Divider(color: Colors.red[300], height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Days Overdue',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
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
                        'Sale Date',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Type',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
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
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue, width: 1),
                        ),
                        child: Text(
                          saleType,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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

  // Helper methods
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
      'amount': sale['amountToPay'] ?? 0,
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
      amount = (sale['price'] as num?)?.toDouble() ?? 0;
      date = sale['date'] ?? sale['timestamp'];
    } else if (collection == 'base_model_sale') {
      type = 'Base Model';
      description = sale['modelName'] ?? '';
      amount = (sale['price'] as num?)?.toDouble() ?? 0;
      date = sale['date'] ?? sale['timestamp'];
    } else if (collection == 'accessories_service_sales') {
      type = 'Accessory/Service';
      description = 'Accessories & Services';
      amount = (sale['totalSaleAmount'] as num?)?.toDouble() ?? 0;
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

  // Payment verification methods - FIXED VERSION
  void _verifyPayment(Map<String, dynamic> transaction) async {
    final Map<String, dynamic> sale = transaction['data'];
    final String collection = transaction['collection'];
    final String docId = transaction['docId'];

    // For Phone Sales with EMI
    bool isPhoneEMI =
        transaction['category'] == 'phone' &&
        (sale['purchaseMode'] ?? '') == 'EMI';

    if (isPhoneEMI) {
      // For EMI Phone Sales
      _showEMIVerificationDialog(sale, collection, docId);
    } else {
      // For other sales with payment breakdown
      _showPaymentBreakdownDialog(sale, collection, docId);
    }
  }

  void _showEMIVerificationDialog(
    Map<String, dynamic> sale,
    String collection,
    String docId,
  ) {
    bool downPaymentReceived = sale['downPaymentReceived'] ?? false;
    bool disbursementReceived = sale['disbursementReceived'] ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Verify EMI Payment'),
              content: SizedBox(
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
                      'Amount: ₹${_formatNumber((sale['amountToPay'] as num?)?.toDouble() ?? 0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildEMIPaymentRow(
                      'Down Payment',
                      (sale['downPayment'] as num?)?.toDouble() ?? 0,
                      downPaymentReceived,
                      (value) {
                        setStateDialog(() {
                          downPaymentReceived = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildEMIPaymentRow(
                      'Disbursement',
                      (sale['disbursementAmount'] as num?)?.toDouble() ?? 0,
                      disbursementReceived,
                      (value) {
                        setStateDialog(() {
                          disbursementReceived = value;
                        });
                      },
                    ),
                  ],
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
                      await _updatePaymentVerification(collection, docId, {
                        'downPaymentReceived': downPaymentReceived,
                        'disbursementReceived': disbursementReceived,
                        'paymentVerified':
                            downPaymentReceived && disbursementReceived,
                      });

                      // Update local state immediately
                      sale['downPaymentReceived'] = downPaymentReceived;
                      sale['disbursementReceived'] = disbursementReceived;
                      sale['paymentVerified'] =
                          downPaymentReceived && disbursementReceived;

                      setState(() {
                        // Trigger UI update
                      });

                      Navigator.pop(context);
                      _showSnackBar(
                        'Payment verified successfully',
                        Colors.green,
                      );
                    } catch (e) {
                      _showSnackBar('Error: $e', Colors.red);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPaymentBreakdownDialog(
    Map<String, dynamic> sale,
    String collection,
    String docId,
  ) {
    // Extract current payment breakdown
    final paymentBreakdown = sale['paymentBreakdownVerified'];
    bool cashVerified = _convertToBool(paymentBreakdown['cash']);
    bool cardVerified = _convertToBool(paymentBreakdown['card']);
    bool gpayVerified = _convertToBool(paymentBreakdown['gpay']);

    // Extract amounts - FIXED: Properly handle the extraction
    double cashAmount = _extractAmount(sale, ['cashAmount', 'cash']);
    double cardAmount = _extractAmount(sale, ['cardAmount', 'card']);
    double gpayAmount = _extractAmount(sale, ['gpayAmount', 'gpay']);

    // Get total amount
    double totalAmount = _getTotalAmount(sale);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Verify Payment Methods'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer: ${sale['customerName'] ?? 'Walk-in'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Total: ₹${_formatNumber(totalAmount)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (cashAmount > 0)
                      _buildPaymentMethodRow('Cash', cashAmount, cashVerified, (
                        value,
                      ) {
                        setStateDialog(() {
                          cashVerified = value;
                        });
                      }),
                    if (cardAmount > 0) ...[
                      const SizedBox(height: 12),
                      _buildPaymentMethodRow('Card', cardAmount, cardVerified, (
                        value,
                      ) {
                        setStateDialog(() {
                          cardVerified = value;
                        });
                      }),
                    ],
                    if (gpayAmount > 0) ...[
                      const SizedBox(height: 12),
                      _buildPaymentMethodRow('GPay', gpayAmount, gpayVerified, (
                        value,
                      ) {
                        setStateDialog(() {
                          gpayVerified = value;
                        });
                      }),
                    ],
                  ],
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
                        'cash': cashVerified,
                        'card': cardVerified,
                        'gpay': gpayVerified,
                      };

                      // Check if all payment methods are verified
                      double verifiedAmount = 0;
                      if (cashAmount > 0 && cashVerified)
                        verifiedAmount += cashAmount;
                      if (cardAmount > 0 && cardVerified)
                        verifiedAmount += cardAmount;
                      if (gpayAmount > 0 && gpayVerified)
                        verifiedAmount += gpayAmount;

                      bool allVerified = verifiedAmount >= totalAmount;

                      await _updatePaymentVerification(collection, docId, {
                        'paymentBreakdownVerified': newPaymentBreakdown,
                        'paymentVerified': allVerified,
                      });

                      // Update local state immediately
                      sale['paymentBreakdownVerified'] = newPaymentBreakdown;
                      sale['paymentVerified'] = allVerified;

                      setState(() {
                        // Trigger UI update
                      });

                      Navigator.pop(context);
                      _showSnackBar(
                        'Payment verified successfully',
                        Colors.green,
                      );
                    } catch (e) {
                      _showSnackBar('Error: $e', Colors.red);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEMIPaymentRow(
    String label,
    double amount,
    bool verified,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              Text(
                '₹${_formatNumber(amount)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        Switch(
          value: verified,
          onChanged: onChanged,
          activeColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodRow(
    String method,
    double amount,
    bool verified,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(method, style: const TextStyle(fontSize: 14)),
              Text(
                '₹${_formatNumber(amount)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        Switch(
          value: verified,
          onChanged: onChanged,
          activeColor: Colors.green,
        ),
      ],
    );
  }
}
