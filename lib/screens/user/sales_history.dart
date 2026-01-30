import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

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

  // Date filter options
  String selectedDateFilter = 'Monthly';
  final List<String> dateFilterOptions = [
    'Today',
    'Yesterday',
    'Weekly',
    'Monthly',
    'Last Month',
    'Yearly',
    'Custom',
  ];

  DateTime? customStartDate;
  DateTime? customEndDate;
  String currentPeriodText = '';

  // Search
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  // Report data
  double totalAmount = 0.0;
  int totalSales = 0;
  Map<String, double> typeTotals = {};

  @override
  void initState() {
    super.initState();
    _initializeDates();
    if (widget.shopId.isEmpty) {
      _showError('Shop ID is required to view sales history');
      setState(() => isLoading = false);
    } else {
      fetchSalesData();
    }
  }

  void _initializeDates() {
    currentPeriodText = _getDateFilterText('Monthly');
  }

  Future<void> fetchSalesData() async {
    setState(() {
      isLoading = true;
      allSales.clear();
      filteredSales.clear();
      totalAmount = 0.0;
      totalSales = 0;
      typeTotals.clear();
    });

    if (widget.shopId.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    int totalFetched = 0;

    for (var collection in collectionNames) {
      try {
        final List<Map<String, dynamic>> periodSales =
            await _fetchSalesForCollection(collection);

        for (var sale in periodSales) {
          // Add collection info and formatted data
          sale['collection'] = collection;
          sale['type'] = _getSaleType(collection);
          sale['displayDate'] = _formatDate(sale, collection);
          sale['displayAmount'] = _getAmount(sale, collection);
          sale['customerInfo'] = _getCustomerInfo(sale);
          sale['paymentInfo'] = _getPaymentInfo(sale, collection);
          sale['shopName'] = _getShopName(sale, collection);

          // Include accessories and service amounts for accessories sales
          if (collection == 'accessories_service_sales') {
            sale['accessoriesAmount'] = (sale['accessoriesAmount'] ?? 0)
                .toDouble();
            sale['serviceAmount'] = (sale['serviceAmount'] ?? 0).toDouble();
          }

          allSales.add(sale);
          totalFetched++;
        }
      } catch (e) {
        print('Error fetching $collection: $e');
      }
    }

    // Calculate report data
    _calculateReportData();

    // Apply initial filter
    _applyFilter();

    setState(() => isLoading = false);
  }

  void _calculateReportData() {
    totalSales = allSales.length;
    totalAmount = 0.0;
    typeTotals.clear();

    for (var sale in allSales) {
      final amount = sale['displayAmount'] as double;
      final type = sale['type'] as String;

      totalAmount += amount;
      typeTotals[type] = (typeTotals[type] ?? 0.0) + amount;
    }
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

      final dateRange = _getDateRangeForFilter(selectedDateFilter);
      final startDate = dateRange['start']!;
      final endDate = dateRange['end']!;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Check if sale is in selected date range
        final saleDate = _getSaleDate(data, collection);
        if (_isDateInRange(saleDate, startDate, endDate)) {
          sales.add(data);
        }
      }
    } catch (e) {
      print('Error in _fetchSalesForCollection for $collection: $e');
    }

    return sales;
  }

  Map<String, DateTime> _getDateRangeForFilter(String filter) {
    final now = DateTime.now();
    DateTime startDate, endDate;

    switch (filter) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'Yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
        );
        break;
      case 'Weekly':
        startDate = now.subtract(const Duration(days: 7));
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'Monthly':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        startDate = lastMonth;
        endDate = DateTime(lastMonth.year, lastMonth.month + 1, 0, 23, 59, 59);
        break;
      case 'Yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'Custom':
        startDate = customStartDate ?? now.subtract(const Duration(days: 30));
        endDate =
            customEndDate ?? DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }

    return {'start': startDate, 'end': endDate};
  }

  String _getDateFilterText(String filter) {
    final range = _getDateRangeForFilter(filter);
    final start = range['start'];
    final end = range['end'];

    switch (filter) {
      case 'Today':
        return DateFormat('dd MMM yyyy').format(start!);
      case 'Yesterday':
        return DateFormat('dd MMM yyyy').format(start!);
      case 'Weekly':
        return '${DateFormat('dd MMM').format(start!)} - ${DateFormat('dd MMM yyyy').format(end!)}';
      case 'Monthly':
        return DateFormat('MMM yyyy').format(start!);
      case 'Last Month':
        return DateFormat('MMM yyyy').format(start!);
      case 'Yearly':
        return DateFormat('yyyy').format(start!);
      case 'Custom':
        if (customStartDate != null && customEndDate != null) {
          return '${DateFormat('dd MMM').format(customStartDate!)} - ${DateFormat('dd MMM yyyy').format(customEndDate!)}';
        }
        return 'Custom Range';
      default:
        return DateFormat('MMM yyyy').format(start!);
    }
  }

  bool _isDateInRange(DateTime date, DateTime start, DateTime end) {
    return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
        date.isBefore(end.add(const Duration(seconds: 1)));
  }

  void _applyFilter() {
    // First filter by type
    List<Map<String, dynamic>> tempSales;
    if (selectedFilter == 'All') {
      tempSales = List.from(allSales);
    } else {
      switch (selectedFilter) {
        case 'Accessories':
          tempSales = allSales
              .where(
                (sale) => sale['collection'] == 'accessories_service_sales',
              )
              .toList();
          break;
        case 'Phones':
          tempSales = allSales
              .where((sale) => sale['collection'] == 'phoneSales')
              .toList();
          break;
        case 'Second Phones':
          tempSales = allSales
              .where((sale) => sale['collection'] == 'seconds_phone_sale')
              .toList();
          break;
        case 'Base Models':
          tempSales = allSales
              .where((sale) => sale['collection'] == 'base_model_sale')
              .toList();
          break;
        default:
          tempSales = allSales;
      }
    }

    // Then filter by search query if any
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      tempSales = tempSales.where((sale) {
        final customer = (sale['customerInfo'] as String).toLowerCase();
        final shopName = (sale['shopName'] as String).toLowerCase();
        final type = (sale['type'] as String).toLowerCase();
        final product = (sale['productName'] ?? '').toString().toLowerCase();
        final brand = (sale['brand'] ?? '').toString().toLowerCase();
        final imei = (sale['imei'] ?? '').toString().toLowerCase();

        return customer.contains(query) ||
            shopName.contains(query) ||
            type.contains(query) ||
            product.contains(query) ||
            brand.contains(query) ||
            imei.contains(query);
      }).toList();
    }

    // Sort by date (newest first)
    tempSales.sort((a, b) {
      final dateA = _getSaleDate(a, a['collection'] as String);
      final dateB = _getSaleDate(b, b['collection'] as String);
      return dateB.compareTo(dateA);
    });

    setState(() {
      filteredSales = tempSales;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    _applyFilter();
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: customStartDate != null && customEndDate != null
          ? DateTimeRange(start: customStartDate!, end: customEndDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
    );

    if (picked != null) {
      setState(() {
        customStartDate = picked.start;
        customEndDate = picked.end;
        selectedDateFilter = 'Custom';
        currentPeriodText = _getDateFilterText('Custom');
      });
      fetchSalesData();
    }
  }

  void _changeDateFilter(String filter) async {
    if (filter == 'Custom') {
      await _selectCustomDateRange(context);
      return;
    }

    setState(() {
      selectedDateFilter = filter;
      currentPeriodText = _getDateFilterText(filter);
    });
    fetchSalesData();
  }

  void _showCustomReport(BuildContext context) {
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
              const Text(
                'Sales Report',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildReportDetailRow('Date Range', currentPeriodText),
              _buildReportDetailRow('Total Sales', totalSales.toString()),
              _buildReportDetailRow(
                'Total Amount',
                '₹${totalAmount.toStringAsFixed(0)}',
              ),

              const SizedBox(height: 16),
              const Text(
                'Sales by Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...typeTotals.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 14,
                              color: _getTypeColor(entry.key),
                            ),
                          ),
                          Text(
                            '₹${entry.value.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _exportReport(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Export Report',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportReport(BuildContext context) async {
    // Create report content
    final reportContent =
        '''
Sales Report
Date Range: $currentPeriodText
Shop ID: ${widget.shopId}
Total Sales: $totalSales
Total Amount: ₹${totalAmount.toStringAsFixed(0)}

Sales by Type:
${typeTotals.entries.map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}').join('\n')}

Detailed Sales:
${filteredSales.map((sale) {
          final date = sale['displayDate'] as String;
          final customer = sale['customerInfo'] as String;
          final amount = (sale['displayAmount'] as double).toStringAsFixed(0);
          final type = sale['type'] as String;
          return '$date - $customer - $type - ₹$amount';
        }).join('\n')}
''';

    // Show share dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Report'),
        content: SingleChildScrollView(
          child: Text(
            'Report generated for $currentPeriodText\n\n'
            'Total Sales: $totalSales\n'
            'Total Amount: ₹${totalAmount.toStringAsFixed(0)}\n\n'
            'You can copy this data to share with your team.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Copy to clipboard
              Clipboard.setData(ClipboardData(text: reportContent));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report copied to clipboard')),
              );
              Navigator.pop(context);
            },
            child: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
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
            final accessories = (data['accessoriesAmount'] ?? 0).toDouble();
            final service = (data['serviceAmount'] ?? 0).toDouble();
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
      // For accessories sales, we need to preserve actual payment amounts
      'actualCash': 0.0,
      'actualCard': 0.0,
      'actualGpay': 0.0,
    };

    try {
      if (collection == 'accessories_service_sales') {
        // For accessories sales, get actual payment amounts
        paymentInfo['actualCash'] = (data['cashAmount'] ?? 0).toDouble();
        paymentInfo['actualCard'] = (data['cardAmount'] ?? 0).toDouble();
        paymentInfo['actualGpay'] = (data['gpayAmount'] ?? 0).toDouble();
        paymentInfo['credit'] = (data['customerCredit'] ?? 0).toDouble();

        // Also store accessories and service amounts separately
        paymentInfo['accessoriesAmount'] = (data['accessoriesAmount'] ?? 0)
            .toDouble();
        paymentInfo['serviceAmount'] = (data['serviceAmount'] ?? 0).toDouble();
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
        title: const Text('Sales History', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment, size: 22),
            onPressed: () => _showCustomReport(context),
            tooltip: 'View Report',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
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
                    size: 50,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Shop ID Required',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Please contact administrator to set up your shop ID',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextField(
                    controller: searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by customer, product, brand, IMEI...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                    ),
                  ),
                ),

                // Date Filter Chips
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 10,
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
                      children: dateFilterOptions.map((filter) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ChoiceChip(
                            label: Text(
                              filter,
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: selectedDateFilter == filter,
                            onSelected: (selected) => _changeDateFilter(filter),
                            backgroundColor: Colors.grey.shade200,
                            selectedColor: Colors.blue.shade100,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              color: selectedDateFilter == filter
                                  ? Colors.blue.shade800
                                  : Colors.grey.shade700,
                              fontWeight: selectedDateFilter == filter
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Period Info
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.blue.shade100),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentPeriodText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Shop: ${widget.shopId}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Type Filter Chips
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 10,
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
                          padding: const EdgeInsets.only(right: 4),
                          child: ChoiceChip(
                            label: Text(
                              filter,
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: selectedFilter == filter,
                            onSelected: (selected) {
                              setState(() {
                                selectedFilter = filter;
                                _applyFilter();
                              });
                            },
                            backgroundColor: Colors.grey.shade200,
                            selectedColor: Colors.green.shade100,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              color: selectedFilter == filter
                                  ? Colors.green.shade800
                                  : Colors.grey.shade700,
                              fontWeight: selectedFilter == filter
                                  ? FontWeight.w600
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
                                size: 50,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No sales found',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              if (searchQuery.isNotEmpty)
                                Text(
                                  'for "$searchQuery"',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                'Shop ID: ${widget.shopId}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Period: $currentPeriodText',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: fetchSalesData,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text(
                                  'Refresh',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
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
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.blue.shade100,
                                    width: 1,
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
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          filteredSales.length.toString(),
                                          style: const TextStyle(
                                            fontSize: 18,
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
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${_calculateTotalAmount().toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 18,
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
                                    height: 0.5,
                                    color: Colors.grey.shade200,
                                  ),
                                  itemBuilder: (context, index) {
                                    final sale = filteredSales[index];
                                    final type = sale['type'] as String;
                                    final color = _getTypeColor(type);

                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      elevation: 0.5,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: Colors.grey.shade200,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                        leading: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _getTypeIcon(type),
                                            size: 16,
                                            color: color,
                                          ),
                                        ),
                                        title: Text(
                                          sale['customerInfo'] as String,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 2),
                                            Text(
                                              sale['displayDate'] as String,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${sale['shopName']} • $type',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                type,
                                                style: TextStyle(
                                                  fontSize: 8,
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
    // For accessories sales, show accessories and service amounts instead of payment methods
    if (collection == 'accessories_service_sales') {
      final accessoriesAmount = paymentInfo['accessoriesAmount'] ?? 0.0;
      final serviceAmount = paymentInfo['serviceAmount'] ?? 0.0;

      final List<Widget> chips = [];

      if (accessoriesAmount > 0) {
        chips.add(
          _buildAmountChip('Accessories', accessoriesAmount, Colors.blue),
        );
      }
      if (serviceAmount > 0) {
        chips.add(_buildAmountChip('Service', serviceAmount, Colors.orange));
      }

      return Wrap(spacing: 3, runSpacing: 2, children: chips);
    }

    // For other sales, show payment methods as before
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

    return Wrap(spacing: 3, runSpacing: 2, children: chips);
  }

  Widget _buildPaymentChip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getPaymentIcon(label), size: 8, color: color),
          const SizedBox(width: 1),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountChip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getAmountIcon(label), size: 8, color: color),
          const SizedBox(width: 1),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.w500,
            ),
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

  IconData _getAmountIcon(String type) {
    switch (type.toLowerCase()) {
      case 'accessories':
        return Icons.shopping_bag;
      case 'service':
        return Icons.build;
      default:
        return Icons.attach_money;
    }
  }

  void _showSaleDetails(BuildContext context, Map<String, dynamic> sale) {
    final isAccessoriesSale = sale['collection'] == 'accessories_service_sales';
    final accessoriesAmount = sale['accessoriesAmount'] as double? ?? 0.0;
    final serviceAmount = sale['serviceAmount'] as double? ?? 0.0;
    final totalAmount = (sale['displayAmount'] as double).toStringAsFixed(0);
    final paymentInfo = sale['paymentInfo'] as Map<String, dynamic>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sale Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(
                        sale['type'] as String,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      sale['type'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getTypeColor(sale['type'] as String),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Customer', sale['customerInfo'] as String),
              _buildDetailRow('Shop', sale['shopName'].toString()),
              _buildDetailRow('Date', sale['displayDate'] as String),

              // For accessories & service sales, show separate amounts
              if (isAccessoriesSale) ...[
                const SizedBox(height: 12),
                const Text(
                  'Amount Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                if (accessoriesAmount > 0)
                  _buildAmountDetailRow(
                    'Accessories Amount',
                    accessoriesAmount,
                  ),
                if (serviceAmount > 0)
                  _buildAmountDetailRow('Service Amount', serviceAmount),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Text(
                        '₹$totalAmount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // For other sales, show just the total amount
                _buildDetailRow('Total Amount', '₹$totalAmount'),
              ],

              // Always show payment breakdown for all sales
              const SizedBox(height: 16),
              const Text(
                'Payment Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (isAccessoriesSale) ...[
                // For accessories sales, show actual payment amounts
                if (paymentInfo['actualCash'] > 0)
                  _buildPaymentDetailRow('Cash', paymentInfo['actualCash']),
                if (paymentInfo['actualCard'] > 0)
                  _buildPaymentDetailRow('Card', paymentInfo['actualCard']),
                if (paymentInfo['actualGpay'] > 0)
                  _buildPaymentDetailRow('GPay', paymentInfo['actualGpay']),
                if (paymentInfo['credit'] > 0)
                  _buildPaymentDetailRow('Credit', paymentInfo['credit']),
              ] else ...[
                // For other sales, show regular payment breakdown
                ..._buildPaymentDetails(
                  paymentInfo,
                  sale['collection'] as String,
                ),
              ],

              // Collection-specific details
              if (sale['collection'] == 'phoneSales') ...[
                const SizedBox(height: 16),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 14)),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDetailRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(method, style: const TextStyle(fontSize: 12)),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
