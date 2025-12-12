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
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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

class _FinanceDashboardState extends State<FinanceDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;
  bool _isLoading = false;

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
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedIndex = _tabController.index;
      });
    });

    // Load initial data
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

        // Ensure payment verification fields exist
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

        // Ensure payment verification fields exist
        data['paymentVerified'] = data['paymentVerified'] ?? false;

        // FIXED: Properly convert LinkedHashMap to Map<String, bool>
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

        // Ensure payment verification fields exist
        data['paymentVerified'] = data['paymentVerified'] ?? false;

        // FIXED: Properly convert LinkedHashMap to Map<String, bool>
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

        // Ensure payment verification fields exist
        data['paymentVerified'] = data['paymentVerified'] ?? false;

        // FIXED: Properly convert LinkedHashMap to Map<String, bool>
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

        return data;
      }).toList();
    } catch (e) {
      print('Error fetching seconds_phone_sale: $e');
      rethrow;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating: $e'),
          backgroundColor: Colors.red,
        ),
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Verification'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: 20,
              color: _isLoading ? Colors.grey : Colors.white,
            ),
            onPressed: _isLoading ? null : _loadAllData,
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.blue[900],
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.phone_iphone, size: 18), text: 'Phones'),
                Tab(
                  icon: Icon(Icons.phone_android, size: 18),
                  text: '2nd Hand',
                ),
                Tab(icon: Icon(Icons.phone, size: 18), text: 'Base Models'),
                Tab(
                  icon: Icon(Icons.shopping_cart, size: 18),
                  text: 'Accessories',
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPhoneSalesVerificationTab(),
                _buildSecondsPhoneVerificationTab(),
                _buildBaseModelVerificationTab(),
                _buildAccessoriesServiceVerificationTab(),
              ],
            ),
    );
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

    // Safely extract boolean values from paymentBreakdownVerified
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
    if (number >= 10000000) {
      return '${(number / 10000000).toStringAsFixed(1)}Cr';
    } else if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(1)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
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
        if (date.contains('UTC')) {
          return date.split(' at ').first;
        } else if (date.contains('/')) {
          return date;
        }
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

  // Payment verification methods
  void _verifyPayment(Map<String, dynamic> transaction) async {
    final Map<String, dynamic> sale = transaction['data'];
    final String collection = transaction['collection'];
    final String docId = transaction['docId'];

    // Safely extract payment breakdown data
    Map<String, bool> paymentBreakdownVerified = {
      'cash': false,
      'card': false,
      'gpay': false,
    };

    final breakdown = sale['paymentBreakdownVerified'];
    if (breakdown is Map) {
      paymentBreakdownVerified = {
        'cash': _convertToBool(breakdown['cash']),
        'card': _convertToBool(breakdown['card']),
        'gpay': _convertToBool(breakdown['gpay']),
      };
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Payment', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer: ${transaction['customer']}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Amount: ₹${_formatNumber(transaction['amount'])}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Type: ${transaction['type']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              if (transaction['category'] == 'phone' &&
                  (sale['purchaseMode'] ?? '') == 'EMI')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EMI Payment Breakdown:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMobilePaymentVerificationRow(
                      'Down Payment',
                      sale['downPayment'],
                      sale['downPaymentReceived'] ?? false,
                      () => _toggleDownPayment(sale, collection, docId),
                    ),
                    const SizedBox(height: 8),
                    _buildMobilePaymentVerificationRow(
                      'Disbursement',
                      sale['disbursementAmount'],
                      sale['disbursementReceived'] ?? false,
                      () => _toggleDisbursement(sale, collection, docId),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Methods:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (((sale['cashAmount'] ?? sale['cash'] ?? 0) as num)
                            .toDouble() >
                        0)
                      _buildMobilePaymentMethodRow(
                        'Cash',
                        sale['cashAmount'] ?? sale['cash'],
                        paymentBreakdownVerified['cash'] ?? false,
                        () => _togglePaymentMethod(
                          sale,
                          collection,
                          docId,
                          'cash',
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (((sale['cardAmount'] ?? sale['card'] ?? 0) as num)
                            .toDouble() >
                        0)
                      _buildMobilePaymentMethodRow(
                        'Card',
                        sale['cardAmount'] ?? sale['card'],
                        paymentBreakdownVerified['card'] ?? false,
                        () => _togglePaymentMethod(
                          sale,
                          collection,
                          docId,
                          'card',
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (((sale['gpayAmount'] ?? sale['gpay'] ?? 0) as num)
                            .toDouble() >
                        0)
                      _buildMobilePaymentMethodRow(
                        'GPay',
                        sale['gpayAmount'] ?? sale['gpay'],
                        paymentBreakdownVerified['gpay'] ?? false,
                        () => _togglePaymentMethod(
                          sale,
                          collection,
                          docId,
                          'gpay',
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                if (transaction['category'] == 'phone' &&
                    (sale['purchaseMode'] ?? '') == 'EMI') {
                  await _updatePaymentVerification(collection, docId, {
                    'downPaymentReceived': true,
                    'disbursementReceived': true,
                    'paymentVerified': true,
                  });
                } else {
                  await _updatePaymentVerification(collection, docId, {
                    'paymentBreakdownVerified': {
                      'cash': true,
                      'card': true,
                      'gpay': true,
                    },
                    'paymentVerified': true,
                  });
                }

                // Reload data to reflect changes
                await _loadAllData();
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment marked as verified'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Verify All', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePaymentVerificationRow(
    String label,
    dynamic amount,
    bool verified,
    VoidCallback onToggle,
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
                '₹${_formatNumber((amount as num?)?.toDouble() ?? 0)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        Switch(
          value: verified,
          onChanged: (value) => onToggle(),
          activeColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildMobilePaymentMethodRow(
    String method,
    dynamic amount,
    bool verified,
    VoidCallback onToggle,
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
                '₹${_formatNumber((amount as num?)?.toDouble() ?? 0)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        Switch(
          value: verified,
          onChanged: (value) => onToggle(),
          activeColor: Colors.green,
        ),
      ],
    );
  }

  Future<void> _toggleDownPayment(
    Map<String, dynamic> sale,
    String collection,
    String docId,
  ) async {
    bool newValue = !(sale['downPaymentReceived'] ?? false);

    try {
      await _updatePaymentVerification(collection, docId, {
        'downPaymentReceived': newValue,
        'paymentVerified': newValue && (sale['disbursementReceived'] ?? false),
      });

      // Reload data
      await _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleDisbursement(
    Map<String, dynamic> sale,
    String collection,
    String docId,
  ) async {
    bool newValue = !(sale['disbursementReceived'] ?? false);

    try {
      await _updatePaymentVerification(collection, docId, {
        'disbursementReceived': newValue,
        'paymentVerified': newValue && (sale['downPaymentReceived'] ?? false),
      });

      // Reload data
      await _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _togglePaymentMethod(
    Map<String, dynamic> sale,
    String collection,
    String docId,
    String method,
  ) async {
    // Safely extract and update payment breakdown
    final breakdownData = sale['paymentBreakdownVerified'];
    Map<String, dynamic> currentBreakdown = {
      'cash': false,
      'card': false,
      'gpay': false,
    };

    if (breakdownData is Map) {
      currentBreakdown = {
        'cash': _convertToBool(breakdownData['cash']),
        'card': _convertToBool(breakdownData['card']),
        'gpay': _convertToBool(breakdownData['gpay']),
      };
    }

    // Toggle the specific method
    currentBreakdown[method] = !(_convertToBool(currentBreakdown[method]));

    try {
      double totalAmount =
          ((sale['cashAmount'] ?? sale['cash'] ?? 0) as num).toDouble() +
          ((sale['cardAmount'] ?? sale['card'] ?? 0) as num).toDouble() +
          ((sale['gpayAmount'] ?? sale['gpay'] ?? 0) as num).toDouble();

      double verifiedAmount = 0;
      if (((sale['cashAmount'] ?? sale['cash'] ?? 0) as num).toDouble() > 0 &&
          _convertToBool(currentBreakdown['cash'])) {
        verifiedAmount += ((sale['cashAmount'] ?? sale['cash'] ?? 0) as num)
            .toDouble();
      }
      if (((sale['cardAmount'] ?? sale['card'] ?? 0) as num).toDouble() > 0 &&
          _convertToBool(currentBreakdown['card'])) {
        verifiedAmount += ((sale['cardAmount'] ?? sale['card'] ?? 0) as num)
            .toDouble();
      }
      if (((sale['gpayAmount'] ?? sale['gpay'] ?? 0) as num).toDouble() > 0 &&
          _convertToBool(currentBreakdown['gpay'])) {
        verifiedAmount += ((sale['gpayAmount'] ?? sale['gpay'] ?? 0) as num)
            .toDouble();
      }

      bool allVerified = verifiedAmount >= totalAmount;

      await _updatePaymentVerification(collection, docId, {
        'paymentBreakdownVerified': currentBreakdown,
        'paymentVerified': allVerified,
      });

      // Reload data
      await _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
