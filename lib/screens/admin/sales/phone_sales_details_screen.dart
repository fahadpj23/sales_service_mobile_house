// lib/screens/sales/phone_sales_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';
import 'phone_sales_reports_screen.dart';

class PhoneSalesDetailsScreen extends StatefulWidget {
  final List<Sale> allSales;
  final String Function(double) formatNumber;

  PhoneSalesDetailsScreen({required this.allSales, required this.formatNumber});

  @override
  _PhoneSalesDetailsScreenState createState() =>
      _PhoneSalesDetailsScreenState();
}

class _PhoneSalesDetailsScreenState extends State<PhoneSalesDetailsScreen> {
  List<Sale> _phoneSales = [];
  List<Sale> _filteredSales = [];
  String? _selectedBrand;
  String? _selectedShop;
  String? _selectedFinanceType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _sortAscending = false;
  String _sortColumn = 'date';
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Date range options
  final List<String> _dateRangeOptions = [
    'Today',
    'Yesterday',
    'Monthly',
    'Yearly',
    'Custom Range',
  ];
  String _selectedDateRange = 'Monthly'; // Default selection

  @override
  void initState() {
    super.initState();
    _applyDateRange('Monthly'); // Apply monthly range by default

    // Add listener to search controller
    _searchController.addListener(() {
      _filterBySearch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterBySearch() {
    final searchQuery = _searchController.text.toLowerCase().trim();

    if (searchQuery.isEmpty) {
      setState(() {
        _filteredSales = List.from(_phoneSales);
      });
      return;
    }

    setState(() {
      _filteredSales = _phoneSales.where((sale) {
        // Search in customer name
        if (sale.customerName.toLowerCase().contains(searchQuery)) {
          return true;
        }

        // Search in customer phone
        if (sale.customerPhone != null &&
            sale.customerPhone!.toLowerCase().contains(searchQuery)) {
          return true;
        }

        // Search in brand
        if (sale.brand != null &&
            sale.brand!.toLowerCase().contains(searchQuery)) {
          return true;
        }

        // Search in model
        if (sale.model != null &&
            sale.model!.toLowerCase().contains(searchQuery)) {
          return true;
        }

        // Search in IMEI
        if (sale.imei != null &&
            sale.imei!.toLowerCase().contains(searchQuery)) {
          return true;
        }

        // Search in sales person
        if (sale.salesPersonName != null &&
            sale.salesPersonName!.toLowerCase().contains(searchQuery)) {
          return true;
        }

        // Search in email
        if (sale.salesPersonEmail != null &&
            sale.salesPersonEmail!.toLowerCase().contains(searchQuery)) {
          return true;
        }

        // Search in shop name
        if (sale.shopName.toLowerCase().contains(searchQuery)) {
          return true;
        }

        // Search in finance type
        if (sale.financeType != null &&
            sale.financeType!.toLowerCase().contains(searchQuery)) {
          return true;
        }

        // Search in purchase mode
        if (sale.purchaseMode != null &&
            sale.purchaseMode!.toLowerCase().contains(searchQuery)) {
          return true;
        }

        return false;
      }).toList();
    });
  }

  void _applyDateRange(String range) {
    setState(() {
      _selectedDateRange = range;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      switch (range) {
        case 'Today':
          _startDate = today;
          _endDate = today.add(Duration(days: 1));
          break;
        case 'Yesterday':
          _startDate = today.subtract(Duration(days: 1));
          _endDate = today;
          break;
        case 'Monthly':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'Yearly':
          _startDate = DateTime(now.year, 1, 1);
          _endDate = DateTime(now.year, 12, 31);
          break;
        case 'Custom Range':
          _startDate = null;
          _endDate = null;
          break;
      }

      _filterPhoneSales();
    });
  }

  void _filterPhoneSales() {
    setState(() {
      _phoneSales = widget.allSales
          .where((sale) => sale.type == 'phone_sale')
          .where(
            (sale) => _selectedBrand == null || sale.brand == _selectedBrand,
          )
          .where(
            (sale) => _selectedShop == null || sale.shopName == _selectedShop,
          )
          .where(
            (sale) =>
                _selectedFinanceType == null ||
                sale.financeType == _selectedFinanceType,
          )
          .where((sale) {
            if (_startDate == null && _endDate == null) return true;
            if (_startDate != null && sale.date.isBefore(_startDate!))
              return false;
            if (_endDate != null && sale.date.isAfter(_endDate!)) return false;
            return true;
          })
          .toList();

      // Sort the list
      _phoneSales.sort((a, b) {
        int result;
        switch (_sortColumn) {
          case 'customerName':
            result = a.customerName.compareTo(b.customerName);
            break;
          case 'date':
            result = a.date.compareTo(b.date);
            break;
          case 'amount':
            result = a.amount.compareTo(b.amount);
            break;
          case 'brand':
            result = (a.brand ?? '').compareTo(b.brand ?? '');
            break;
          default:
            result = a.date.compareTo(b.date);
        }
        return _sortAscending ? result : -result;
      });

      // Apply search filter if search is active
      if (_searchController.text.isNotEmpty) {
        _filterBySearch();
      } else {
        _filteredSales = List.from(_phoneSales);
      }
    });
  }

  List<String> _getUniqueBrands() {
    Set<String> brands = {};
    for (var sale in widget.allSales.where((s) => s.type == 'phone_sale')) {
      if (sale.brand != null && sale.brand!.isNotEmpty) {
        brands.add(sale.brand!);
      }
    }
    return brands.toList()..sort();
  }

  List<String> _getUniqueShops() {
    Set<String> shops = {};
    for (var sale in widget.allSales.where((s) => s.type == 'phone_sale')) {
      shops.add(sale.shopName);
    }
    return shops.toList()..sort();
  }

  List<String> _getUniqueFinanceTypes() {
    Set<String> types = {};
    for (var sale in widget.allSales.where((s) => s.type == 'phone_sale')) {
      if (sale.financeType != null && sale.financeType!.isNotEmpty) {
        types.add(sale.financeType!);
      }
    }
    return types.toList()..sort();
  }

  double _calculateTotalAmount() {
    return _filteredSales.fold(0.0, (sum, sale) => sum + sale.amount);
  }

  Color _getStatusColor(String? purchaseMode) {
    switch (purchaseMode?.toLowerCase()) {
      case 'emi':
        return Color(0xFF2196F3);
      case 'cash':
        return Color(0xFF4CAF50);
      case 'card':
        return Color(0xFF9C27B0);
      default:
        return Colors.grey;
    }
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.search,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by customer, phone, brand, IMEI...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        hintStyle: TextStyle(fontSize: 13),
                      ),
                      style: TextStyle(fontSize: 13),
                      onChanged: (_) {
                        setState(() {
                          _isSearching = _searchController.text.isNotEmpty;
                        });
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _isSearching = false;
                          _filteredSales = List.from(_phoneSales);
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
          if (_isSearching)
            Padding(
              padding: EdgeInsets.only(left: 6),
              child: Chip(
                label: Text(
                  '${_filteredSales.length} found',
                  style: TextStyle(fontSize: 11),
                ),
                backgroundColor: Color(0xFF0A4D2E),
                labelStyle: TextStyle(color: Colors.white),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Phone Sales Details',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt),
            color: Colors.white,
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
            iconSize: 22,
          ),
          IconButton(
            icon: Icon(Icons.bar_chart),
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PhoneSalesReportsScreen(
                    allSales: widget.allSales,
                    phoneSales: _filteredSales,
                    formatNumber: widget.formatNumber,
                  ),
                ),
              );
            },
            tooltip: 'Reports',
            iconSize: 22,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),

          // Date Range Selection
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Color(0xFFF5F5F5),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _dateRangeOptions.map((option) {
                  final isSelected = _selectedDateRange == option;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(option, style: TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _applyDateRange(option);
                        }
                      },
                      selectedColor: Color(0xFF0A4D2E),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      labelPadding: EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Filtered Results Summary Card
          Container(
            padding: EdgeInsets.all(12),
            color: Color(0xFFE8F5E9),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '₹${widget.formatNumber(_calculateTotalAmount())}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 30, color: Colors.grey[300]),
                    Column(
                      children: [
                        Text(
                          'Transactions',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '${_filteredSales.length}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 30, color: Colors.grey[300]),
                    Column(
                      children: [
                        Text(
                          'Date Range',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          _getDateRangeDisplay(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0A4D2E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Active Filters Display
          if (_selectedBrand != null ||
              _selectedShop != null ||
              _selectedFinanceType != null ||
              (_startDate != null && _selectedDateRange == 'Custom Range'))
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (_selectedBrand != null)
                    Chip(
                      label: Text(
                        'Brand: $_selectedBrand',
                        style: TextStyle(fontSize: 11),
                      ),
                      onDeleted: () {
                        setState(() {
                          _selectedBrand = null;
                        });
                        _filterPhoneSales();
                      },
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      labelPadding: EdgeInsets.symmetric(horizontal: 4),
                      deleteIcon: Icon(Icons.close, size: 16),
                    ),
                  if (_selectedShop != null)
                    Chip(
                      label: Text(
                        'Shop: $_selectedShop',
                        style: TextStyle(fontSize: 11),
                      ),
                      onDeleted: () {
                        setState(() {
                          _selectedShop = null;
                        });
                        _filterPhoneSales();
                      },
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      labelPadding: EdgeInsets.symmetric(horizontal: 4),
                      deleteIcon: Icon(Icons.close, size: 16),
                    ),
                  if (_selectedFinanceType != null)
                    Chip(
                      label: Text(
                        'Finance: $_selectedFinanceType',
                        style: TextStyle(fontSize: 11),
                      ),
                      onDeleted: () {
                        setState(() {
                          _selectedFinanceType = null;
                        });
                        _filterPhoneSales();
                      },
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      labelPadding: EdgeInsets.symmetric(horizontal: 4),
                      deleteIcon: Icon(Icons.close, size: 16),
                    ),
                  if (_startDate != null &&
                      _selectedDateRange == 'Custom Range')
                    Chip(
                      label: Text(
                        '${DateFormat('dd-MMM-yyyy').format(_startDate!)} to ${_endDate != null ? DateFormat('dd-MMM-yyyy').format(_endDate!) : 'Now'}',
                        style: TextStyle(fontSize: 11),
                      ),
                      onDeleted: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                        _filterPhoneSales();
                      },
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      labelPadding: EdgeInsets.symmetric(horizontal: 4),
                      deleteIcon: Icon(Icons.close, size: 16),
                    ),
                ],
              ),
            ),

          // Sales List
          Expanded(
            child: _filteredSales.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchController.text.isNotEmpty
                              ? Icons.search_off
                              : Icons.phone_iphone,
                          size: 56,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 12),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No results found for "${_searchController.text}"'
                              : 'No phone sales found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 6),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'Try a different search term'
                              : 'Try changing your filters',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredSales.length,
                    itemBuilder: (context, index) {
                      final sale = _filteredSales[index];
                      return _buildSaleCard(sale);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getDateRangeDisplay() {
    switch (_selectedDateRange) {
      case 'Today':
        return 'Today';
      case 'Yesterday':
        return 'Yesterday';
      case 'Monthly':
        final now = DateTime.now();
        return DateFormat('MMM yyyy').format(now);
      case 'Yearly':
        return DateFormat('yyyy').format(DateTime.now());
      case 'Custom Range':
        if (_startDate != null) {
          if (_endDate != null) {
            return '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}';
          } else {
            return 'From ${DateFormat('dd MMM').format(_startDate!)}';
          }
        }
        return 'Custom';
      default:
        return 'All';
    }
  }

  Widget _buildSaleCard(Sale sale) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(12),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0A4D2E),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getStatusColor(sale.purchaseMode ?? ''),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    sale.purchaseMode ?? 'Unknown',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text(
                  sale.customerPhone ?? 'No phone',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  Icons.branding_watermark,
                  size: 14,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${sale.brand ?? 'Unknown'} - ${sale.model ?? 'Unknown'}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Divider(height: 1),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sale Amount',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '₹${widget.formatNumber(sale.amount)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finance Type',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 3),
                    Text(
                      sale.financeType ?? 'Cash',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Shop',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 3),
                    Text(
                      sale.shopName,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Down Payment',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '₹${widget.formatNumber(sale.downPayment ?? 0)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 3),
                    Text(
                      DateFormat('dd MMM yyyy').format(sale.date),
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 6),
            if (sale.imei != null && sale.imei!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IMEI: ${sale.imei}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            SizedBox(height: 3),
            if (sale.addedAt != null)
              Text(
                'Added: ${DateFormat('dd MMM yyyy HH:mm').format(sale.addedAt!)}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            SizedBox(height: 2),
            Text(
              'Sales Person: ${sale.salesPersonEmail ?? sale.salesPersonName ?? 'Unknown'}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    List<String> brands = _getUniqueBrands();
    List<String> shops = _getUniqueShops();
    List<String> financeTypes = _getUniqueFinanceTypes();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filter Phone Sales', style: TextStyle(fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date Range Selection in Filter Dialog
                    _buildFilterDropdown(
                      'Date Range',
                      _selectedDateRange,
                      _dateRangeOptions,
                      (value) {
                        if (value != null) {
                          _applyDateRange(value);
                        }
                      },
                    ),
                    SizedBox(height: 12),
                    _buildFilterDropdown('Brand', _selectedBrand, brands, (
                      value,
                    ) {
                      setState(() {
                        _selectedBrand = value;
                      });
                    }),
                    SizedBox(height: 12),
                    _buildFilterDropdown('Shop', _selectedShop, shops, (value) {
                      setState(() {
                        _selectedShop = value;
                      });
                    }),
                    SizedBox(height: 12),
                    _buildFilterDropdown(
                      'Finance Type',
                      _selectedFinanceType,
                      financeTypes,
                      (value) {
                        setState(() {
                          _selectedFinanceType = value;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    if (_selectedDateRange == 'Custom Range')
                      _buildDateRangeFilter(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel', style: TextStyle(fontSize: 13)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedBrand = null;
                      _selectedShop = null;
                      _selectedFinanceType = null;
                      _startDate = null;
                      _endDate = null;
                      _applyDateRange('Monthly'); // Reset to default monthly
                    });
                    _filterPhoneSales();
                    Navigator.pop(context);
                  },
                  child: Text('Clear All', style: TextStyle(fontSize: 13)),
                ),
                ElevatedButton(
                  onPressed: () {
                    _filterPhoneSales();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0A4D2E),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text('Apply Filters', style: TextStyle(fontSize: 13)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String? currentValue,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              hint: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('Select $label', style: TextStyle(fontSize: 13)),
              ),
              items: items.map<DropdownMenuItem<String>>((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(item, style: TextStyle(fontSize: 13)),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Date Range',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _startDate = date;
                      if (_endDate != null && _endDate!.isBefore(date)) {
                        _endDate = null;
                      }
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 15,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _startDate == null
                              ? 'Start Date'
                              : DateFormat('dd-MMM-yyyy').format(_startDate!),
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 6),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final firstDate = _startDate ?? DateTime(2020);
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: firstDate,
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 15,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _endDate == null
                              ? 'End Date'
                              : DateFormat('dd-MMM-yyyy').format(_endDate!),
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
