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

  // Month/Year filter variables
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  List<int> years = [];
  final List<String> months = [
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

  // Debug variables
  String debugInfo = '';

  @override
  void initState() {
    super.initState();
    // Generate years (current year and previous 5 years)
    final currentYear = DateTime.now().year;
    for (int i = currentYear; i >= currentYear - 5; i--) {
      years.add(i);
    }

    // Check if shopId is provided
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
      debugInfo = 'Fetching data for shopId: ${widget.shopId}';
    });
    allSales.clear();

    // Check if shopId is valid
    if (widget.shopId.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    // Calculate start and end dates for the selected month
    final startDate = DateTime(selectedYear, selectedMonth, 1);
    final endDate = DateTime(selectedYear, selectedMonth + 1, 0, 23, 59, 59);

    debugInfo +=
        '\nDate range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}';
    debugInfo += '\nSelected month: ${months[selectedMonth - 1]} $selectedYear';

    int totalFetched = 0;

    for (var collection in collectionNames) {
      try {
        debugInfo += '\n\nFetching from collection: $collection';

        QuerySnapshot snapshot;

        // Different date fields for different collections
        String dateField;
        switch (collection) {
          case 'phoneSales':
            dateField = 'addedAt';
            break;
          default:
            dateField = 'uploadedAt';
            break;
        }

        debugInfo += '\nUsing date field: $dateField';

        // First try: Get all documents for the shop without date filter to debug
        try {
          final testSnapshot = await FirebaseFirestore.instance
              .collection(collection)
              .where('shopId', isEqualTo: widget.shopId)
              .limit(5)
              .get();

          debugInfo +=
              '\nShop has ${testSnapshot.docs.length} documents in $collection (without date filter)';

          if (testSnapshot.docs.isNotEmpty) {
            for (var doc in testSnapshot.docs.take(1)) {
              final data = doc.data() as Map<String, dynamic>;
              debugInfo += '\nSample document fields: ${data.keys.toList()}';
              if (data.containsKey(dateField)) {
                debugInfo += '\n$dateField exists: ${data[dateField]}';
              }
            }
          }
        } catch (e) {
          debugInfo += '\nTest query error: $e';
        }

        // Main query with shopId and date range filtering
        snapshot = await FirebaseFirestore.instance
            .collection(collection)
            .where('shopId', isEqualTo: widget.shopId)
            .where(
              dateField,
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
            )
            .where(dateField, isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .orderBy(dateField, descending: true)
            .get();

        debugInfo +=
            '\nDate-filtered query found ${snapshot.docs.length} documents';

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['collection'] = collection;
          data['type'] = _getSaleType(collection);
          data['displayDate'] = _formatDate(data, collection);
          data['displayAmount'] = _getAmount(data, collection);
          data['customerInfo'] = _getCustomerInfo(data);
          data['paymentInfo'] = _getPaymentInfo(data, collection);
          data['shopName'] = _getShopName(data, collection);

          allSales.add(data);
          totalFetched++;
        }
      } catch (e) {
        debugInfo += '\nError fetching $collection: $e';
        print('Error fetching $collection: $e');
        // Try alternative date fields
        await _fetchWithAlternativeDateField(collection, startDate, endDate);
      }
    }

    debugInfo += '\n\nTotal documents fetched: $totalFetched';
    debugInfo += '\nAll sales count: ${allSales.length}';

    // If no data found with date filter, try without date filter
    if (allSales.isEmpty) {
      debugInfo +=
          '\nNo data found with date filter. Trying without date filter...';
      await fetchAllSalesForShop();
    }

    // Apply type filter
    _applyFilter();

    debugInfo += '\nFiltered sales count: ${filteredSales.length}';

    setState(() => isLoading = false);
  }

  Future<void> fetchAllSalesForShop() async {
    debugInfo += '\n\n=== FETCHING ALL SALES FOR SHOP ===';

    for (var collection in collectionNames) {
      try {
        debugInfo += '\nFetching all from $collection';

        final snapshot = await FirebaseFirestore.instance
            .collection(collection)
            .where('shopId', isEqualTo: widget.shopId)
            .limit(50)
            .get();

        debugInfo += '\nFound ${snapshot.docs.length} documents in $collection';

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['collection'] = collection;
          data['type'] = _getSaleType(collection);
          data['displayDate'] = _formatDate(data, collection);
          data['displayAmount'] = _getAmount(data, collection);
          data['customerInfo'] = _getCustomerInfo(data);
          data['paymentInfo'] = _getPaymentInfo(data, collection);
          data['shopName'] = _getShopName(data, collection);

          allSales.add(data);
        }
      } catch (e) {
        debugInfo += '\nError in all sales fetch for $collection: $e';
        print('Error in all sales fetch for $collection: $e');
      }
    }

    debugInfo += '\nTotal all sales fetched: ${allSales.length}';
  }

  Future<void> _fetchWithAlternativeDateField(
    String collection,
    DateTime startDate,
    DateTime endDate,
  ) async {
    debugInfo += '\nTrying alternative date fields for $collection';

    List<String> dateFields = [];

    switch (collection) {
      case 'phoneSales':
        dateFields = ['createdAt', 'saleDate', 'addedAt', 'timestamp', 'date'];
        break;
      default:
        dateFields = ['uploadedAt', 'timestamp', 'date', 'createdAt'];
        break;
    }

    for (var dateField in dateFields) {
      try {
        debugInfo += '\nTrying date field: $dateField';

        final snapshot = await FirebaseFirestore.instance
            .collection(collection)
            .where('shopId', isEqualTo: widget.shopId)
            .where(
              dateField,
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
            )
            .where(dateField, isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .get();

        debugInfo +=
            '\nAlternative query with $dateField found ${snapshot.docs.length} documents';

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['collection'] = collection;
          data['type'] = _getSaleType(collection);
          data['displayDate'] = _formatDate(data, collection);
          data['displayAmount'] = _getAmount(data, collection);
          data['customerInfo'] = _getCustomerInfo(data);
          data['paymentInfo'] = _getPaymentInfo(data, collection);
          data['shopName'] = _getShopName(data, collection);

          allSales.add(data);
        }

        if (snapshot.docs.isNotEmpty) {
          debugInfo += '\nSuccess with date field: $dateField';
          break;
        }
      } catch (e) {
        debugInfo += '\nError with date field $dateField: $e';
      }
    }
  }

  void _applyFilter() {
    if (selectedFilter == 'All') {
      filteredSales = allSales;
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
      final dateA = _parseDateForSorting(a);
      final dateB = _parseDateForSorting(b);
      return dateB.compareTo(dateA);
    });
  }

  DateTime _parseDateForSorting(Map<String, dynamic> sale) {
    try {
      final collection = sale['collection'] as String;
      final data = sale;

      if (collection == 'phoneSales') {
        if (data['addedAt'] != null && data['addedAt'] is Timestamp) {
          return (data['addedAt'] as Timestamp).toDate();
        } else if (data['createdAt'] != null &&
            data['createdAt'] is Timestamp) {
          return (data['createdAt'] as Timestamp).toDate();
        } else if (data['saleDate'] != null && data['saleDate'] is Timestamp) {
          return (data['saleDate'] as Timestamp).toDate();
        }
      } else if (data['uploadedAt'] != null &&
          data['uploadedAt'] is Timestamp) {
        return (data['uploadedAt'] as Timestamp).toDate();
      } else if (data['timestamp'] != null) {
        if (data['timestamp'] is Timestamp) {
          return (data['timestamp'] as Timestamp).toDate();
        } else if (data['timestamp'] is int) {
          return DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
        }
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
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
      // Try different date fields based on collection type
      if (collection == 'phoneSales') {
        if (data['saleDate'] != null) {
          final timestamp = data['saleDate'] as Timestamp;
          final date = timestamp.toDate();
          return DateFormat('dd MMM yyyy, hh:mm a').format(date);
        } else if (data['saleDate'] != null) {
          final timestamp = data['saleDate'] as Timestamp;
          final date = timestamp.toDate();
          return DateFormat('dd MMM yyyy, hh:mm a').format(date);
        } else if (data['saleDate'] != null) {
          final timestamp = data['saleDate'] as Timestamp;
          final date = timestamp.toDate();
          return DateFormat('dd MMM yyyy, hh:mm a').format(date);
        }
      } else if (data['date'] != null) {
        final timestamp = data['date'] as Timestamp;
        final date = timestamp.toDate();
        return DateFormat('dd MMM yyyy, hh:mm a').format(date);
      } else if (data['timestamp'] != null) {
        final timestamp = data['timestamp'];
        if (timestamp is Timestamp) {
          final date = timestamp.toDate();
          return DateFormat('dd MMM yyyy, hh:mm a').format(date);
        } else if (timestamp is int) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return DateFormat('dd MMM yyyy, hh:mm a').format(date);
        }
      } else if (data['date'] != null) {
        return data['date'].toString();
      }
      return 'Date not available';
    } catch (e) {
      return 'Invalid date';
    }
  }

  double _getAmount(Map<String, dynamic> data, String collection) {
    switch (collection) {
      case 'accessories_service_sales':
        return (data['totalSaleAmount'] ?? 0).toDouble();
      case 'phoneSales':
        return (data['effectivePrice'] ?? data['price'] ?? 0).toDouble();
      case 'base_model_sale':
        return (data['price'] ?? data['totalPayment'] ?? 0).toDouble();
      case 'seconds_phone_sale':
        return (data['price'] ?? data['totalPayment'] ?? 0).toDouble();
      default:
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

  Future<void> _selectMonthYear(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 60,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Select Month & Year',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // Year Selection
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<int>(
                      value: selectedYear,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: years.map((year) {
                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text('Year: $year'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedYear = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Month Selection
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<int>(
                      value: selectedMonth,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: List.generate(12, (index) {
                        return DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text('Month: ${months[index]}'),
                        );
                      }),
                      onChanged: (value) {
                        setState(() {
                          selectedMonth = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            fetchSalesData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
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

  void _showDebugInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Debug Information'),
          content: SingleChildScrollView(child: Text(debugInfo)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
            icon: const Icon(Icons.bug_report),
            onPressed: () => _showDebugInfo(context),
            tooltip: 'Debug Info',
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () => _selectMonthYear(context),
            tooltip: 'Select Month & Year',
          ),
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
                // Shop Info Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.green.shade100),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.store,
                          size: 20,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shop ID: ${widget.shopId}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Viewing: ${months[selectedMonth - 1]} $selectedYear',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (filteredSales.isNotEmpty)
                              Text(
                                '${filteredSales.length} sales found',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${filteredSales.length} sales',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                                'No sales found for ${months[selectedMonth - 1]} $selectedYear',
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
                                'Try selecting a different month or year',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _selectMonthYear(context),
                                icon: const Icon(Icons.calendar_today),
                                label: const Text('Select Different Month'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => _showDebugInfo(context),
                                icon: const Icon(Icons.bug_report),
                                label: const Text('Show Debug Info'),
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
                                          'Total Sales',
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
                                          'Total Amount',
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

  double _calculateTotalAmount() {
    return filteredSales.fold(
      0.0,
      (sum, sale) => sum + (sale['displayAmount'] as double),
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
              _buildDetailRow(
                'Total Amount',
                '₹${(sale['displayAmount'] as double).toStringAsFixed(0)}',
              ),

              // Phone-specific details
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
                if (sale['effectivePrice'] != null)
                  _buildDetailRow(
                    'Effective Price',
                    '₹${sale['effectivePrice']}',
                  ),
                if (sale['discount'] != null && (sale['discount'] as num) > 0)
                  _buildDetailRow('Discount', '₹${sale['discount']}'),
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
