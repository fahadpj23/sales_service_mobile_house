import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalesHistoryScreen extends StatefulWidget {
  final String shopId;

  const SalesHistoryScreen({super.key, required this.shopId});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
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

    if (widget.shopId.isEmpty) {
      _showError('Shop ID is required to view sales history');
      setState(() => isLoading = false);
    } else {
      fetchSalesData();
    }
  }

  Future<void> fetchSalesData() async {
    setState(() {
      isLoading = true;
      allSales.clear();
      filteredSales.clear();
    });

    // Check if shopId is valid
    if (widget.shopId.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    int totalFetched = 0;

    for (var collection in collectionNames) {
      try {
        final List<Map<String, dynamic>> monthSales =
            await _fetchSalesForCollection(collection);

        for (var sale in monthSales) {
          // Add collection info and formatted data
          sale['collection'] = collection;
          sale['type'] = _getSaleType(collection);
          sale['displayDate'] = _formatDate(sale, collection);
          sale['displayAmount'] = _getAmount(sale, collection);
          sale['customerInfo'] = _getCustomerInfo(sale);
          sale['paymentInfo'] = _getPaymentInfo(sale, collection);
          sale['shopName'] = _getShopName(sale, collection);

          allSales.add(sale);
          totalFetched++;
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
  ) async {
    final List<Map<String, dynamic>> sales = [];

    try {
      // Get all sales for this shop (we'll filter by date in memory)
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where('shopId', isEqualTo: widget.shopId)
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
          return (data['totalSaleAmount'] ?? 0).toDouble();
        case 'phoneSales':
          return (data['effectivePrice'] ?? data['price'] ?? 0).toDouble();
        case 'base_model_sale':
        case 'seconds_phone_sale':
          return (data['price'] ?? data['totalPayment'] ?? 0).toDouble();
        default:
          return 0.0;
      }
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  double _calculateTotalAmount() {
    return filteredSales.fold(
      0.0,
      (sum, sale) => sum + (sale['displayAmount'] as double),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchSalesData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: widget.shopId.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Shop ID Required',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please contact administrator to set up your shop ID',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Month Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.green.shade100),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$currentMonthName $currentYear',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Showing current month sales only',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Shop: ${widget.shopId}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Filter Chips
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filterOptions.map((filter) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: selectedFilter == filter,
                            onSelected: (selected) {
                              setState(() {
                                selectedFilter = filter;
                                _applyFilter();
                              });
                            },
                            backgroundColor: Colors.grey.shade200,
                            selectedColor: Colors.green.shade100,
                            checkmarkColor: Colors.green,
                            labelStyle: TextStyle(
                              color: selectedFilter == filter
                                  ? Colors.green
                                  : Colors.grey.shade700,
                              fontWeight: selectedFilter == filter
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Sales List
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredSales.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 60,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No sales for $currentMonthName $currentYear',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Shop ID: ${widget.shopId}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sales will appear here when recorded',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: fetchSalesData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: fetchSalesData,
                          child: Column(
                            children: [
                              // Summary Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.shade100,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Monthly Sales',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          filteredSales.length.toString(),
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Monthly Amount',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          '₹${_calculateTotalAmount().toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Sales List
                              Expanded(
                                child: ListView.separated(
                                  itemCount: filteredSales.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    color: Colors.grey.shade200,
                                  ),
                                  itemBuilder: (context, index) {
                                    final sale = filteredSales[index];
                                    final type = sale['type'] as String;
                                    final color = _getTypeColor(type);

                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListTile(
                                        leading: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _getTypeIcon(type),
                                            size: 20,
                                            color: color,
                                          ),
                                        ),
                                        title: Text(
                                          sale['customerInfo'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              sale['displayDate'] as String,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${sale['shopName']} • $type',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            _buildPaymentChips(
                                              sale['paymentInfo']
                                                  as Map<String, dynamic>,
                                              sale['collection'] as String,
                                            ),
                                          ],
                                        ),
                                        trailing: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₹${(sale['displayAmount'] as double).toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                type,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: color,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          _showSaleDetails(context, sale);
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
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

    if (paymentInfo['cash'] > 0) {
      chips.add(_buildPaymentChip('Cash', paymentInfo['cash'], Colors.green));
    }
    if (paymentInfo['card'] > 0) {
      chips.add(_buildPaymentChip('Card', paymentInfo['card'], Colors.blue));
    }
    if (paymentInfo['gpay'] > 0) {
      chips.add(_buildPaymentChip('GPay', paymentInfo['gpay'], Colors.purple));
    }
    if (paymentInfo['credit'] > 0) {
      chips.add(
        _buildPaymentChip('Credit', paymentInfo['credit'], Colors.orange),
      );
    }
    if (collection == 'phoneSales' && paymentInfo['downPayment'] > 0) {
      chips.add(
        _buildPaymentChip('Down', paymentInfo['downPayment'], Colors.teal),
      );
    }

    return Wrap(spacing: 4, runSpacing: 4, children: chips);
  }

  Widget _buildPaymentChip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getPaymentIcon(label), size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                  width: 60,
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
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Customer', sale['customerInfo'] as String),
              _buildDetailRow('Shop', sale['shopName'].toString()),
              _buildDetailRow('Date', sale['displayDate'] as String),
              if (sale['collection'] == 'accessories_service_sales') ...[
                if (sale['accessoriesAmount'] != null)
                  _buildDetailRow(
                    'Accessories',
                    sale['accessoriesAmount'].toString(),
                  ),
                if (sale['serviceAmount'] != null)
                  _buildDetailRow('Service', sale['serviceAmount'].toString()),
              ],
              _buildDetailRow(
                'Total Amount',
                '₹${(sale['displayAmount'] as double).toStringAsFixed(0)}',
              ),

              // Collection-specific details
              if (sale['collection'] == 'phoneSales') ...[
                if (sale['productModel'] != null)
                  _buildDetailRow('Product', sale['productModel'].toString()),
                if (sale['brand'] != null)
                  _buildDetailRow('Brand', sale['brand'].toString()),
                if (sale['imei'] != null)
                  _buildDetailRow('IMEI', sale['imei'].toString()),
                if (sale['purchaseMode'] != null)
                  _buildDetailRow(
                    'Purchase Mode',
                    sale['purchaseMode'].toString(),
                  ),
                if (sale['financeType'] != null)
                  _buildDetailRow(
                    'Finance Type',
                    sale['financeType'].toString(),
                  ),
              ],

              // Other collection details
              if (sale['productName'] != null)
                _buildDetailRow('Product', sale['productName'].toString()),

              if (sale['brand'] != null && sale['collection'] != 'phoneSales')
                _buildDetailRow('Brand', sale['brand'].toString()),

              if (sale['imei'] != null && sale['collection'] != 'phoneSales')
                _buildDetailRow('IMEI', sale['imei'].toString()),

              if (sale['notes'] != null && (sale['notes'] as String).isNotEmpty)
                _buildDetailRow('Notes', sale['notes'].toString()),

              const SizedBox(height: 20),
              const Text(
                'Payment Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              ..._buildPaymentDetails(
                sale['paymentInfo'] as Map<String, dynamic>,
                sale['collection'] as String,
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
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
      widgets.add(_buildPaymentDetailRow('Cash', paymentInfo['cash']));
    }
    if (paymentInfo['card'] > 0) {
      widgets.add(_buildPaymentDetailRow('Card', paymentInfo['card']));
    }
    if (paymentInfo['gpay'] > 0) {
      widgets.add(_buildPaymentDetailRow('GPay', paymentInfo['gpay']));
    }
    if (paymentInfo['credit'] > 0) {
      widgets.add(_buildPaymentDetailRow('Credit', paymentInfo['credit']));
    }
    if (collection == 'phoneSales' && paymentInfo['downPayment'] > 0) {
      widgets.add(
        _buildPaymentDetailRow('Down Payment', paymentInfo['downPayment']),
      );
    }

    return widgets;
  }

  Widget _buildPaymentDetailRow(String method, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(method),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
