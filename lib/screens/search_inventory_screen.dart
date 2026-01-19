import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';

class SearchInventoryScreen extends StatefulWidget {
  final List<Sale> allSales;
  final List<Map<String, dynamic>> shops;
  final String Function(double) formatNumber;

  SearchInventoryScreen({
    required this.allSales,
    required this.shops,
    required this.formatNumber,
  });

  @override
  _SearchInventoryScreenState createState() => _SearchInventoryScreenState();
}

class _SearchInventoryScreenState extends State<SearchInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _searchType = 'imei';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_performSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    List<Sale> filteredSales = [];

    if (_searchType == 'imei') {
      filteredSales = widget.allSales.where((sale) {
        return sale.imei != null && sale.imei!.toLowerCase().contains(query);
      }).toList();
    } else {
      filteredSales = widget.allSales.where((sale) {
        return (sale.itemName?.toLowerCase().contains(query) ?? false) ||
            (sale.model?.toLowerCase().contains(query) ?? false) ||
            (sale.brand?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    List<Map<String, dynamic>> results = [];
    for (var sale in filteredSales) {
      results.add({
        'sale': sale,
        'type': 'sale',
        'relevance': _calculateRelevance(sale, query),
      });
    }

    results.sort((a, b) => b['relevance'].compareTo(a['relevance']));

    setState(() {
      _searchResults = results;
    });
  }

  int _calculateRelevance(Sale sale, String query) {
    int relevance = 0;

    if (_searchType == 'imei' && sale.imei?.toLowerCase() == query) {
      relevance += 100;
    }

    if (sale.imei?.toLowerCase().startsWith(query) ?? false) {
      relevance += 50;
    }

    if (sale.imei?.toLowerCase().contains(query) ?? false) {
      relevance += 30;
    }

    if (_searchType == 'productName') {
      if (sale.itemName?.toLowerCase() == query) {
        relevance += 100;
      }
      if (sale.model?.toLowerCase() == query) {
        relevance += 90;
      }
      if (sale.brand?.toLowerCase() == query) {
        relevance += 80;
      }
      if (sale.itemName?.toLowerCase().contains(query) ?? false) {
        relevance += 40;
      }
    }

    if (sale.date.isAfter(DateTime.now().subtract(Duration(days: 30)))) {
      relevance += 5;
    }

    return relevance;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults.clear();
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Search Inventory',
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
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            decoration: InputDecoration(
                              hintText: _searchType == 'imei'
                                  ? 'Search by IMEI number...'
                                  : 'Search by product name, model, or brand...',
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear),
                                      onPressed: _clearSearch,
                                    )
                                  : null,
                            ),
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            setState(() {
                              _searchType = value;
                            });
                            _performSearch();
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'imei',
                              child: Row(
                                children: [
                                  Icon(Icons.confirmation_number, size: 18),
                                  SizedBox(width: 8),
                                  Text('Search by IMEI'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'productName',
                              child: Row(
                                children: [
                                  Icon(Icons.phone_iphone, size: 18),
                                  SizedBox(width: 8),
                                  Text('Search by Product'),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF0A4D2E).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _searchType == 'imei'
                                  ? Icons.confirmation_number
                                  : Icons.phone_iphone,
                              color: Color(0xFF0A4D2E),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _searchType == 'imei'
                          ? 'Enter full or partial IMEI number'
                          : 'Search by product name, model, or brand name',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Search Inventory',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              _searchType == 'imei'
                  ? 'Enter IMEI number to search'
                  : 'Enter product name, model, or brand',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isSearching && _searchResults.isEmpty) {
      return Center(child: CircularProgressIndicator(color: Color(0xFF0A4D2E)));
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Try different search terms',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final sale = result['sale'] as Sale;

        return _buildSaleCard(sale);
      },
    );
  }

  Widget _buildSaleCard(Sale sale) {
    return GestureDetector(
      onTap: () {
        _showSaleDetails(context, sale);
      },
      child: Card(
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A4D2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(sale.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      sale.category,
                      style: TextStyle(
                        color: _getCategoryColor(sale.category),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              if (sale.brand != null || sale.model != null)
                Row(
                  children: [
                    Icon(Icons.phone_iphone, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${sale.brand ?? ''} ${sale.model ?? sale.itemName}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 4),
              if (sale.imei != null && sale.imei!.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.confirmation_number,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'IMEI: ${sale.imei}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: 'Monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Date & Shop',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yy').format(sale.date),
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      Text(
                        sale.shopName,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              if (sale.customerPhone != null)
                Row(
                  children: [
                    Icon(Icons.phone, size: 12, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      sale.customerPhone!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              if (sale.salesPersonEmail != null || sale.salesPersonName != null)
                Text(
                  'Sales Person: ${sale.salesPersonEmail ?? sale.salesPersonName}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaleDetails(BuildContext context, Sale sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sale Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Customer', sale.customerName),
              _buildDetailRow('Category', sale.category),
              _buildDetailRow('Shop', sale.shopName),
              _buildDetailRow(
                'Date',
                DateFormat('dd MMM yyyy, hh:mm a').format(sale.date),
              ),
              _buildDetailRow('Amount', '₹${widget.formatNumber(sale.amount)}'),
              if (sale.customerPhone != null)
                _buildDetailRow('Phone', sale.customerPhone!),
              if (sale.brand != null) _buildDetailRow('Brand', sale.brand!),
              if (sale.model != null) _buildDetailRow('Model', sale.model!),
              if (sale.imei != null) _buildDetailRow('IMEI', sale.imei!),
              if (sale.salesPersonName != null)
                _buildDetailRow('Sales Person', sale.salesPersonName!),
              if (sale.cashAmount != null && sale.cashAmount! > 0)
                _buildDetailRow(
                  'Cash',
                  '₹${widget.formatNumber(sale.cashAmount!)}',
                ),
              if (sale.cardAmount != null && sale.cardAmount! > 0)
                _buildDetailRow(
                  'Card',
                  '₹${widget.formatNumber(sale.cardAmount!)}',
                ),
              if (sale.gpayAmount != null && sale.gpayAmount! > 0)
                _buildDetailRow(
                  'GPay',
                  '₹${widget.formatNumber(sale.gpayAmount!)}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'New Phone':
        return Color(0xFF4CAF50);
      case 'Base Model':
        return Color(0xFF2196F3);
      case 'Second Phone':
        return Color(0xFF9C27B0);
      case 'Service':
        return Color(0xFFFF9800);
      default:
        return Colors.grey;
    }
  }
}
