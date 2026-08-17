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

class _DownpaymentBenefitScreenState extends State<DownpaymentBenefitScreen>
    with SingleTickerProviderStateMixin {
  List<Sale> _filteredSales = [];
  List<Sale> _withoutExchangeSales = [];
  List<Sale> _withExchangeSales = [];
  double _totalBenefit = 0.0;
  double _withoutExchangeBenefit = 0.0;
  double _withExchangeBenefit = 0.0;
  int _totalBenefitTransactions = 0;
  int _withoutExchangeTransactions = 0;
  int _withExchangeTransactions = 0;
  DateTime _selectedStartDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _selectedEndDate = DateTime.now();

  String _selectedFilter = 'monthly';
  int _selectedTabIndex = 0;

  final Color primaryGreen = Color(0xFF0A4D2E);
  final Color secondaryGreen = Color(0xFF1A7D4A);
  final Color accentGreen = Color(0xFF28A745);
  final Color lightGreen = Color(0xFFE8F5E9);
  final Color benefitColor = Color(0xFF4CAF50);
  final Color exchangeColor = Color(0xFFFF6B35);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    _applyFilter('monthly');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          break;
      }
    });
    _filterAndCalculateData();
  }

  void _filterAndCalculateData() {
    _filteredSales = [];
    _withoutExchangeSales = [];
    _withExchangeSales = [];
    _totalBenefit = 0.0;
    _withoutExchangeBenefit = 0.0;
    _withExchangeBenefit = 0.0;
    _totalBenefitTransactions = 0;
    _withoutExchangeTransactions = 0;
    _withExchangeTransactions = 0;

    final phoneSales = widget.allSales.where((sale) {
      return sale.type == 'phone_sale' &&
          sale.date.isAfter(_selectedStartDate) &&
          sale.date.isBefore(_selectedEndDate.add(Duration(days: 1)));
    }).toList();

    for (var sale in phoneSales) {
      bool hasExchange = (sale.exchangeValue ?? 0) != 0;
      bool hasDiscount = (sale.discount ?? 0) != 0;

      if (hasDiscount) {
        continue;
      }

      double benefit = _calculateDownpaymentBenefit(sale);

      if (benefit > 0) {
        _filteredSales.add(sale);
        _totalBenefit += benefit;
        _totalBenefitTransactions++;

        if (hasExchange) {
          _withExchangeSales.add(sale);
          _withExchangeBenefit += benefit;
          _withExchangeTransactions++;
        } else {
          _withoutExchangeSales.add(sale);
          _withoutExchangeBenefit += benefit;
          _withoutExchangeTransactions++;
        }
      }
    }

    _filteredSales.sort((a, b) {
      final DateTime aDateTime = a.addedAt ?? a.date;
      final DateTime bDateTime = b.addedAt ?? b.date;
      return bDateTime.compareTo(aDateTime);
    });

    _withoutExchangeSales.sort((a, b) {
      final DateTime aDateTime = a.addedAt ?? a.date;
      final DateTime bDateTime = b.addedAt ?? b.date;
      return bDateTime.compareTo(aDateTime);
    });

    _withExchangeSales.sort((a, b) {
      final DateTime aDateTime = a.addedAt ?? a.date;
      final DateTime bDateTime = b.addedAt ?? b.date;
      return bDateTime.compareTo(aDateTime);
    });

    setState(() {});
  }

  double _calculateDownpaymentBenefit(Sale sale) {
    if (sale.purchaseMode != 'EMI') {
      return 0.0;
    }

    double price = sale.price ?? sale.amount;
    double downPayment = sale.downPayment ?? 0.0;
    double disbursementAmount = sale.disbursementAmount ?? 0.0;
    double totalPayment = downPayment + disbursementAmount;

    if (totalPayment > price) {
      double benefit = totalPayment - price;
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
      {'label': 'Week', 'value': 'weekly'},
      {'label': 'Month', 'value': 'monthly'},
      {'label': 'Last Month', 'value': 'last_month'},
      {'label': 'Year', 'value': 'yearly'},
      {'label': 'Custom', 'value': 'custom'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          bool isSelected = _selectedFilter == filter['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: FilterChip(
              label: Text(
                filter['label']!,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
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
                borderRadius: BorderRadius.circular(14),
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
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeader() {
    double totalBenefitDisplay = _selectedTabIndex == 0
        ? _withoutExchangeBenefit
        : _withExchangeBenefit;
    int totalTransactionsDisplay = _selectedTabIndex == 0
        ? _withoutExchangeTransactions
        : _withExchangeTransactions;

    String tabTitle = _selectedTabIndex == 0 ? 'No Exchange' : 'With Exchange';
    Color tabColor = _selectedTabIndex == 0 ? benefitColor : exchangeColor;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        '${DateFormat('dd MMM yyyy').format(_selectedStartDate)} - ${DateFormat('dd MMM yyyy').format(_selectedEndDate)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 16,
                  ),
                  onPressed: () => _selectDateRange(context),
                  tooltip: 'Select Date Range',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),

          SizedBox(height: 10),

          Container(height: 28, child: _buildFilterChips()),

          SizedBox(height: 12),

          Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.3),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 10,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.money_off, size: 13),
                      SizedBox(width: 4),
                      Text('No Exchange'),
                      SizedBox(width: 3),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: benefitColor.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_withoutExchangeTransactions',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swap_horiz, size: 13),
                      SizedBox(width: 4),
                      Text('With Exchange'),
                      SizedBox(width: 3),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: exchangeColor.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_withExchangeTransactions',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                tabTitle,
                '₹${totalBenefitDisplay.toStringAsFixed(2)}',
                _selectedTabIndex == 0 ? Icons.money_off : Icons.swap_horiz,
                tabColor,
              ),
              _buildStatCard(
                'Txn',
                '$totalTransactionsDisplay',
                Icons.receipt,
                tabColor,
              ),
              _buildStatCard(
                'Total',
                '₹${_totalBenefit.toStringAsFixed(2)}',
                Icons.monetization_on,
                benefitColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 70,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 1),
          Text(
            title,
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 9),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

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
    List<Sale> salesList = _selectedTabIndex == 0
        ? _withoutExchangeSales
        : _withExchangeSales;

    String emptyMessage = _selectedTabIndex == 0
        ? 'No benefit transactions without exchange'
        : 'No benefit transactions with exchange';

    Color tabColor = _selectedTabIndex == 0 ? benefitColor : exchangeColor;

    if (salesList.isEmpty) {
      return Container(
        height: 150,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedTabIndex == 0 ? Icons.money_off : Icons.swap_horiz,
                size: 36,
                color: Colors.grey[400],
              ),
              SizedBox(height: 8),
              Text(
                emptyMessage,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                'for the selected period',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: salesList.length,
      itemBuilder: (context, index) {
        final sale = salesList[index];
        final benefit = _calculateDownpaymentBenefit(sale);
        final price = sale.price ?? sale.amount;
        final downPayment = sale.downPayment ?? 0.0;
        final disbursementAmount = sale.disbursementAmount ?? 0.0;
        final totalReceived = downPayment + disbursementAmount;
        final exchangeValue = sale.exchangeValue ?? 0.0;

        final displayDateTime = sale.addedAt ?? sale.date;
        final numberOfEmi = _getNumberOfEmi(sale);
        bool hasExchange = (sale.exchangeValue ?? 0) != 0;

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tabColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasExchange ? Icons.swap_horiz : Icons.money_off,
                        color: tabColor,
                        size: 16,
                      ),
                      SizedBox(height: 2),
                      Text(
                        '₹${widget.formatNumber(benefit)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: tabColor,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        hasExchange ? 'Exchange' : 'No Exch',
                        style: TextStyle(
                          fontSize: 8,
                          color: tabColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 10),

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
                                fontSize: 12,
                                color: primaryGreen,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${sale.brand ?? ''} ${sale.model ?? ''}'.trim(),
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 9,
                            color: Colors.grey[500],
                          ),
                          SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              DateFormat(
                                'dd MMM yyyy hh:mm a',
                              ).format(displayDateTime),
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 4),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Price: ₹${widget.formatNumber(price)}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Disb: ₹${widget.formatNumber(disbursementAmount)}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 6),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Down: ₹${widget.formatNumber(downPayment)}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Recv: ₹${widget.formatNumber(totalReceived)}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (hasExchange) ...[
                        SizedBox(height: 3),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: exchangeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Exchange: ₹${widget.formatNumber(exchangeValue)}',
                            style: TextStyle(
                              fontSize: 9,
                              color: exchangeColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],

                      SizedBox(height: 3),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: secondaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              sale.shopName,
                              style: TextStyle(
                                fontSize: 8,
                                color: secondaryGreen,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          if (numberOfEmi != null && numberOfEmi > 0)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: tabColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '$numberOfEmi EMI',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: tabColor,
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
        title: Text('Benefit Analysis', style: TextStyle(fontSize: 16)),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedTabIndex == 0
                        ? 'No Exchange Transactions'
                        : 'With Exchange Transactions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          (_selectedTabIndex == 0
                                  ? benefitColor
                                  : exchangeColor)
                              .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedTabIndex == 0
                              ? Icons.timeline
                              : Icons.swap_horiz,
                          size: 12,
                          color: _selectedTabIndex == 0
                              ? benefitColor
                              : exchangeColor,
                        ),
                        SizedBox(width: 3),
                        Text(
                          '${_selectedTabIndex == 0 ? _withoutExchangeSales.length : _withExchangeSales.length}',
                          style: TextStyle(
                            fontSize: 10,
                            color: _selectedTabIndex == 0
                                ? benefitColor
                                : exchangeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 6),
            _buildBenefitList(),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
