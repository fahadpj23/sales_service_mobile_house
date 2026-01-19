// lib/screens/sales/phone_sales_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sale.dart';
import 'phone_sales_reports_screen.dart'; // Import the reports screen

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
  String? _selectedBrand;
  String? _selectedShop;
  String? _selectedFinanceType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _sortAscending = false;
  String _sortColumn = 'date';

  @override
  void initState() {
    super.initState();
    _filterPhoneSales();
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
    return _phoneSales.fold(0.0, (sum, sale) => sum + sale.amount);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Phone Sales Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt),
            color: Colors.white,
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
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
                    phoneSales: _phoneSales,
                    formatNumber: widget.formatNumber,
                  ),
                ),
              );
            },
            tooltip: 'Reports',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Color(0xFFE8F5E9),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Total Sales',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '₹${widget.formatNumber(_calculateTotalAmount())}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Transactions',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${_phoneSales.length}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_selectedBrand != null ||
              _selectedShop != null ||
              _selectedFinanceType != null ||
              _startDate != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedBrand != null)
                    Chip(
                      label: Text('Brand: $_selectedBrand'),
                      onDeleted: () {
                        setState(() {
                          _selectedBrand = null;
                        });
                        _filterPhoneSales();
                      },
                    ),
                  if (_selectedShop != null)
                    Chip(
                      label: Text('Shop: $_selectedShop'),
                      onDeleted: () {
                        setState(() {
                          _selectedShop = null;
                        });
                        _filterPhoneSales();
                      },
                    ),
                  if (_selectedFinanceType != null)
                    Chip(
                      label: Text('Finance: $_selectedFinanceType'),
                      onDeleted: () {
                        setState(() {
                          _selectedFinanceType = null;
                        });
                        _filterPhoneSales();
                      },
                    ),
                  if (_startDate != null)
                    Chip(
                      label: Text(
                        'From: ${DateFormat('dd-MMM-yyyy').format(_startDate!)}',
                      ),
                      onDeleted: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                        _filterPhoneSales();
                      },
                    ),
                ],
              ),
            ),

          Expanded(
            child: _phoneSales.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone_iphone,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No phone sales found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try changing your filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _phoneSales.length,
                    itemBuilder: (context, index) {
                      final sale = _phoneSales[index];
                      return _buildSaleCard(sale);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Sale sale) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A4D2E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(sale.purchaseMode ?? ''),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    sale.purchaseMode ?? 'Unknown',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  sale.customerPhone ?? 'No phone',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.branding_watermark,
                  size: 16,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 8),
                Text(
                  '${sale.brand ?? 'Unknown'} - ${sale.model ?? 'Unknown'}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(height: 1),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sale Amount',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '₹${widget.formatNumber(sale.amount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finance Type',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      sale.financeType ?? 'Cash',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Shop',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      sale.shopName,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Down Payment',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '₹${widget.formatNumber(sale.downPayment ?? 0)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy').format(sale.date),
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            if (sale.imei != null && sale.imei!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IMEI: ${sale.imei}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            SizedBox(height: 4),
            if (sale.addedAt != null)
              Text(
                'Added: ${DateFormat('dd MMM yyyy HH:mm').format(sale.addedAt!)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            SizedBox(height: 2),
            Text(
              'Sales Person: ${sale.salesPersonEmail ?? sale.salesPersonName ?? 'Unknown'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
              title: Text('Filter Phone Sales'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterDropdown('Brand', _selectedBrand, brands, (
                      value,
                    ) {
                      setState(() {
                        _selectedBrand = value;
                      });
                    }),
                    SizedBox(height: 16),
                    _buildFilterDropdown('Shop', _selectedShop, shops, (value) {
                      setState(() {
                        _selectedShop = value;
                      });
                    }),
                    SizedBox(height: 16),
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
                    SizedBox(height: 16),
                    _buildDateRangeFilter(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedBrand = null;
                      _selectedShop = null;
                      _selectedFinanceType = null;
                      _startDate = null;
                      _endDate = null;
                    });
                    _filterPhoneSales();
                    Navigator.pop(context);
                  },
                  child: Text('Clear All'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _filterPhoneSales();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0A4D2E),
                  ),
                  child: Text('Apply Filters'),
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
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              hint: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Select $label'),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('All $label'),
                  ),
                ),
                ...items.map<DropdownMenuItem<String>>((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(item),
                    ),
                  );
                }).toList(),
              ],
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
          'Date Range',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        SizedBox(height: 8),
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
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 8),
                      Text(
                        _startDate == null
                            ? 'Start Date'
                            : DateFormat('dd-MMM-yyyy').format(_startDate!),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: _startDate ?? DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 8),
                      Text(
                        _endDate == null
                            ? 'End Date'
                            : DateFormat('dd-MMM-yyyy').format(_endDate!),
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
