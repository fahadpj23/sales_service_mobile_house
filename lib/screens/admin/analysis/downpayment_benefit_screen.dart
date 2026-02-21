import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sales_stock/models/sale.dart';

class DownpaymentBenefitScreen extends StatefulWidget {
  final List<Sale> allSales;
  final String Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  const DownpaymentBenefitScreen({
    Key? key,
    required this.allSales,
    required this.formatNumber,
    required this.shops,
  }) : super(key: key);

  @override
  State<DownpaymentBenefitScreen> createState() =>
      _DownpaymentBenefitScreenState();
}

class _DownpaymentBenefitScreenState extends State<DownpaymentBenefitScreen> {
  List<Sale> _filteredSales = [];
  double _totalBenefit = 0.0;
  int _totalBenefitTransactions = 0;
  DateTime _selectedStartDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _selectedEndDate = DateTime.now();

  String _selectedFilter =
      'monthly'; // daily, weekly, monthly, last_month, yearly, custom

  // Colors
  final Color primaryGreen = Color(0xFF0A4D2E);
  final Color secondaryGreen = Color(0xFF1A7D4A);
  final Color accentGreen = Color(0xFF28A745);
  final Color lightGreen = Color(0xFFE8F5E9);
  final Color benefitColor = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _applyFilter('monthly');
  }

  void _applyFilter(String filterType) {
    setState(() {
      _selectedFilter = filterType;

      final now = DateTime.now();
      switch (filterType) {
        case 'daily':
          _selectedStartDate = DateTime(now.year, now.month, now.day);
          _selectedEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'weekly':
          _selectedStartDate = now.subtract(Duration(days: now.weekday - 1));
          _selectedStartDate = DateTime(
            _selectedStartDate.year,
            _selectedStartDate.month,
            _selectedStartDate.day,
          );
          _selectedEndDate = now;
          break;
        case 'monthly':
          _selectedStartDate = DateTime(now.year, now.month, 1);
          _selectedEndDate = now;
          break;
        case 'last_month':
          final lastMonth = now.month == 1
              ? DateTime(now.year - 1, 12, 1)
              : DateTime(now.year, now.month - 1, 1);
          _selectedStartDate = lastMonth;
          _selectedEndDate = DateTime(
            lastMonth.year,
            lastMonth.month + 1,
            0,
            23,
            59,
            59,
          );
          break;
        case 'yearly':
          _selectedStartDate = DateTime(now.year, 1, 1);
          _selectedEndDate = now;
          break;
        case 'custom':
          // Keep existing dates for custom
          break;
      }
    });
    _filterAndCalculateData();
  }

  void _filterAndCalculateData() {
    _filteredSales = [];
    _totalBenefit = 0.0;
    _totalBenefitTransactions = 0;

    // Filter phone sales within date range
    final phoneSales = widget.allSales.where((sale) {
      return sale.type == 'phone_sale' &&
          sale.date.isAfter(_selectedStartDate) &&
          sale.date.isBefore(_selectedEndDate.add(Duration(days: 1)));
    }).toList();

    for (var sale in phoneSales) {
      double benefit = _calculateDownpaymentBenefit(sale);

      if (benefit > 0) {
        _filteredSales.add(sale);
        _totalBenefit += benefit;
        _totalBenefitTransactions++;
      }
    }

    // Sort by addedAt in DESCENDING order (newest first)
    _filteredSales.sort((a, b) {
      // Use addedAt if available, fallback to date if not
      final DateTime aDateTime = a.addedAt ?? a.date;
      final DateTime bDateTime = b.addedAt ?? b.date;
      return bDateTime.compareTo(aDateTime); // DESCENDING order (newest first)
    });

    setState(() {});
  }

  double _calculateDownpaymentBenefit(Sale sale) {
    // Only calculate benefit for EMI purchases
    if (sale.purchaseMode != 'EMI') {
      return 0.0;
    }

    // Check if discount and exchange value are zero
    if ((sale.discount ?? 0) != 0 || (sale.exchangeValue ?? 0) != 0) {
      return 0.0;
    }

    // Extract required values - handle null price
    double price = sale.price ?? sale.amount;
    double downPayment = sale.downPayment ?? 0.0;
    double disbursementAmount = sale.disbursementAmount ?? 0.0;

    // Calculate total payment customer makes
    double totalPayment = downPayment + disbursementAmount;

    // Calculate benefit: totalPayment - price (company earns this extra amount)
    // Customer pays more than actual price in EMI
    if (totalPayment > price) {
      double benefit = totalPayment - price;

      // Only return benefit if it's positive (customer paid more than price)
      return benefit > 0 ? benefit : 0.0;
    } else
      return 0;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _selectedStartDate,
        end: _selectedEndDate,
      ),
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

    if (picked != null) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
        _selectedFilter = 'custom';
      });
      _filterAndCalculateData();
    }
  }

  Widget _buildFilterChips() {
    final filters = [
      {'label': 'Today', 'value': 'daily'},
      {'label': 'This Week', 'value': 'weekly'},
      {'label': 'This Month', 'value': 'monthly'},
      {'label': 'Last Month', 'value': 'last_month'},
      {'label': 'This Year', 'value': 'yearly'},
      {'label': 'Custom', 'value': 'custom'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          bool isSelected = _selectedFilter == filter['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: FilterChip(
              label: Text(
                filter['label']!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              selected: isSelected,
              backgroundColor: Colors.grey[200],
              selectedColor: secondaryGreen.withOpacity(0.2),
              checkmarkColor: secondaryGreen,
              labelStyle: TextStyle(
                color: isSelected ? secondaryGreen : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? secondaryGreen : Colors.grey[300]!,
                  width: isSelected ? 1.2 : 0.8,
                ),
              ),
              onSelected: (selected) {
                if (filter['value'] == 'custom') {
                  _selectDateRange(context);
                } else {
                  _applyFilter(filter['value']!);
                }
              },
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Date Range
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Downpayment Benefit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${DateFormat('dd MMM yyyy').format(_selectedStartDate)} - ${DateFormat('dd MMM yyyy').format(_selectedEndDate)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => _selectDateRange(context),
                  tooltip: 'Select Date Range',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Filter Chips with reduced size
          Container(height: 32, child: _buildFilterChips()),

          SizedBox(height: 20),

          // Stats Cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                'Total Benefit',
                '₹${_totalBenefit.toStringAsFixed(2)}',
                Icons.monetization_on,
              ),
              _buildStatCard(
                'Transactions',
                '$_totalBenefitTransactions',
                Icons.receipt,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      width: 80,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // Helper method to safely get numberOfEmi from sale
  int? _getNumberOfEmi(Sale sale) {
    try {
      final dynamic saleMap = sale as dynamic;
      if (saleMap.numberOfEmi != null) {
        return saleMap.numberOfEmi as int?;
      }
    } catch (e) {
      // Field doesn't exist or can't be accessed
    }
    return null;
  }

  Widget _buildBenefitList() {
    if (_filteredSales.isEmpty) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.money_off, size: 48, color: Colors.grey[400]),
              SizedBox(height: 12),
              Text(
                'No benefit transactions',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                'for the selected period',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    // Sales are sorted in DESCENDING order by addedAt (newest first)

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _filteredSales.length,
      itemBuilder: (context, index) {
        final sale = _filteredSales[index];
        final benefit = _calculateDownpaymentBenefit(sale);
        final price = sale.price ?? sale.amount;
        final downPayment = sale.downPayment ?? 0.0;
        final disbursementAmount = sale.disbursementAmount ?? 0.0;
        final totalReceived = downPayment + disbursementAmount;

        // Get the timestamp to display (addedAt or date)
        final displayDateTime = sale.addedAt ?? sale.date;

        // Safely get numberOfEmi
        final numberOfEmi = _getNumberOfEmi(sale);

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Benefit amount with icon
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: benefitColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.monetization_on,
                        color: benefitColor,
                        size: 20,
                      ),
                      SizedBox(height: 4),
                      Text(
                        '₹${widget.formatNumber(benefit)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: benefitColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Benefit',
                        style: TextStyle(
                          fontSize: 10,
                          color: benefitColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 12),

                // Customer and product info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              sale.customerName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: primaryGreen,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#${index + 1}', // Show sequence number (newest first)
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${sale.brand ?? ''} ${sale.model ?? ''}'.trim(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Date and Time
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 10,
                            color: Colors.grey[500],
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              DateFormat(
                                'dd MMM yyyy hh:mm a',
                              ).format(displayDateTime),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 6),

                      // Price and Disbursement info
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Price: ₹${widget.formatNumber(price)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Disbursement: ₹${widget.formatNumber(disbursementAmount)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 8),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Down: ₹${widget.formatNumber(downPayment)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Total Received: ₹${widget.formatNumber(totalReceived)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 6),

                      // Shop info and EMI details
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: secondaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              sale.shopName,
                              style: TextStyle(
                                fontSize: 10,
                                color: secondaryGreen,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          if (numberOfEmi != null && numberOfEmi > 0)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: benefitColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$numberOfEmi EMI',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: benefitColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        title: Text('Benefit Analysis'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Benefit Transactions (Newest First)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: benefitColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timeline, size: 14, color: benefitColor),
                        SizedBox(width: 4),
                        Text(
                          '${_filteredSales.length} transactions',
                          style: TextStyle(
                            fontSize: 12,
                            color: benefitColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            _buildBenefitList(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
