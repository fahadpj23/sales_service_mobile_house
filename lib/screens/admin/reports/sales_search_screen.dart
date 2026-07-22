// lib/screens/admin/reports/sales_search_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../providers/auth_provider.dart';
import 'bills_reprint.dart';

class productDetails extends StatefulWidget {
  final Function(double) formatNumber;
  final List<Map<String, dynamic>> shops;

  const productDetails({
    super.key,
    required this.formatNumber,
    required this.shops,
  });

  @override
  State<productDetails> createState() => _productDetailsState();
}

class _productDetailsState extends State<productDetails> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _allBills = [];
  bool _hasSearched = false;
  bool _isGeneratingPDF = false;

  final Color primaryGreen = const Color(0xFF0A4D2E);
  final Color secondaryGreen = const Color(0xFF1A7D4A);
  final Color warningColor = const Color(0xFFFFC107);

  // Search filters
  String _selectedFilter = 'all';
  final List<String> _filterOptions = [
    'All',
    'IMEI',
    'Serial Number',
    'Customer Name',
    'Customer Phone',
    'Product Name',
    'Bill Number',
  ];

  // Print helper
  late BillRePrint _printHelper;

  @override
  void initState() {
    super.initState();
    _printHelper = BillRePrint();
    _loadAllBills();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllBills() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot billsSnapshot = await _firestore
          .collection('bills')
          .orderBy('billDate', descending: true)
          .get();

      _allBills.clear();

      for (var doc in billsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        _allBills.add(data);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading bills: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _performSearch() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a search term'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _searchQuery = query;
      _isLoading = true;
      _hasSearched = true;
    });

    // Search in all bills
    final results = _allBills.where((bill) {
      return _matchesSearchCriteria(bill, query);
    }).toList();

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No results found for "$query"'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  bool _matchesSearchCriteria(Map<String, dynamic> bill, String query) {
    final searchLower = query.toLowerCase().trim();

    // Get all searchable fields
    final String customerName = (bill['customerName'] as String? ?? '')
        .toLowerCase();
    final String customerMobile = (bill['customerMobile'] as String? ?? '')
        .toLowerCase();
    final String billNumber = (bill['billNumber'] as String? ?? '')
        .toLowerCase();
    final String productName = _getProductName(bill).toLowerCase();
    final String imei = _getImei(bill).toLowerCase();
    final String serialNumber = _getSerialNumber(bill).toLowerCase();
    final String shopName = (bill['shopName'] as String? ?? '').toLowerCase();

    // Check if any field contains the search query
    if (_selectedFilter == 'all') {
      return customerName.contains(searchLower) ||
          customerMobile.contains(searchLower) ||
          billNumber.contains(searchLower) ||
          productName.contains(searchLower) ||
          imei.contains(searchLower) ||
          serialNumber.contains(searchLower) ||
          shopName.contains(searchLower);
    }

    // Filter by specific field
    switch (_selectedFilter) {
      case 'IMEI':
        return imei.contains(searchLower);
      case 'Serial Number':
        return serialNumber.contains(searchLower);
      case 'Customer Name':
        return customerName.contains(searchLower);
      case 'Customer Phone':
        return customerMobile.contains(searchLower);
      case 'Product Name':
        return productName.contains(searchLower);
      case 'Bill Number':
        return billNumber.contains(searchLower);
      default:
        return customerName.contains(searchLower) ||
            customerMobile.contains(searchLower) ||
            billNumber.contains(searchLower) ||
            productName.contains(searchLower) ||
            imei.contains(searchLower) ||
            serialNumber.contains(searchLower);
    }
  }

  String _getProductName(Map<String, dynamic> bill) {
    final billType = bill['billType'] as String?;
    final type = bill['type'] as String?;

    // Check original data first
    final originalPhoneData = bill['originalPhoneData'];
    if (originalPhoneData != null &&
        originalPhoneData is Map<String, dynamic>) {
      return originalPhoneData['productName'] ?? bill['productName'] ?? '';
    }

    final originalTvData = bill['originalTvData'];
    if (originalTvData != null && originalTvData is Map<String, dynamic>) {
      return originalTvData['modelName'] ??
          bill['modelName'] ??
          bill['productName'] ??
          '';
    }

    final originalApplianceData = bill['originalApplianceData'];
    if (originalApplianceData != null &&
        originalApplianceData is Map<String, dynamic>) {
      return originalApplianceData['productName'] ?? bill['productName'] ?? '';
    }

    // Fallback to bill data
    if (type == 'tv') {
      return bill['modelName'] ?? bill['productName'] ?? '';
    }

    return bill['productName'] ?? '';
  }

  String _getImei(Map<String, dynamic> bill) {
    final originalPhoneData = bill['originalPhoneData'];
    if (originalPhoneData != null &&
        originalPhoneData is Map<String, dynamic>) {
      return originalPhoneData['imei'] ?? bill['imei'] ?? '';
    }
    return bill['imei'] ?? '';
  }

  String _getSerialNumber(Map<String, dynamic> bill) {
    final billType = bill['billType'] as String?;
    final type = bill['type'] as String?;

    if (type == 'tv') {
      final originalTvData = bill['originalTvData'];
      if (originalTvData != null && originalTvData is Map<String, dynamic>) {
        return originalTvData['serialNumber'] ?? bill['serialNumber'] ?? '';
      }
      return bill['serialNumber'] ?? '';
    }

    if (billType == 'Appliances' || billType == 'Appliance') {
      final originalApplianceData = bill['originalApplianceData'];
      if (originalApplianceData != null &&
          originalApplianceData is Map<String, dynamic>) {
        return originalApplianceData['serialNumber'] ??
            bill['serialNumber'] ??
            '';
      }
      return bill['serialNumber'] ?? '';
    }

    return '';
  }

  // ==================== COPY IMEI FUNCTION ====================
  void _copyImei(String imei) {
    if (imei.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: imei));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('IMEI copied to clipboard: $imei'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ==================== PRINT BILL ====================
  Future<void> _printAndShareBill(Map<String, dynamic> bill) async {
    await _printHelper.printAndShareBill(
      context: context,
      bill: bill,
      setState: setState,
    );
  }

  // ==================== GENERATE SEARCH REPORT PDF ====================
  Future<void> _generateSearchReport() async {
    if (_searchResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No results to generate report'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingPDF = true;
    });

    try {
      // Determine bill types
      final phoneBills = _searchResults.where((bill) {
        final billType = bill['billType'] as String?;
        final type = bill['type'] as String?;
        return billType != 'Appliances' &&
            billType != 'Appliance' &&
            billType != 'GST Accessories' &&
            type != 'tv';
      }).toList();

      final accessoriesBills = _searchResults.where((bill) {
        return bill['billType'] == 'GST Accessories';
      }).toList();

      final tvBills = _searchResults.where((bill) {
        return bill['type'] == 'tv';
      }).toList();

      final applianceBills = _searchResults.where((bill) {
        final billType = bill['billType'] as String?;
        return billType == 'Appliances' || billType == 'Appliance';
      }).toList();

      final pdf = pw.Document();

      // Add company header
      pdf.addPage(
        pw.MultiPage(
          build: (context) {
            final List<pw.Widget> widgets = [];

            // Header
            widgets.add(
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(width: 2)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'SALES SEARCH REPORT',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Search Query: "${_searchQuery}"',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                    ),
                    pw.Text(
                      'Total Results: ${_searchResults.length}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );

            pw.SizedBox(height: 10);

            // Summary
            final totalAmount = _searchResults.fold<double>(0, (sum, bill) {
              return sum + ((bill['totalAmount'] as num?)?.toDouble() ?? 0);
            });

            final totalTaxable = _searchResults.fold<double>(0, (sum, bill) {
              return sum + ((bill['taxableAmount'] as num?)?.toDouble() ?? 0);
            });

            final totalGst = _searchResults.fold<double>(0, (sum, bill) {
              return sum + ((bill['gstAmount'] as num?)?.toDouble() ?? 0);
            });

            widgets.add(
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSummaryItem(
                          'Total Bills',
                          _searchResults.length.toString(),
                        ),
                        _buildSummaryItem(
                          'Taxable',
                          '₹${widget.formatNumber(totalTaxable)}',
                        ),
                        _buildSummaryItem(
                          'GST',
                          '₹${widget.formatNumber(totalGst)}',
                        ),
                        _buildSummaryItem(
                          'Total Sales',
                          '₹${widget.formatNumber(totalAmount)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            pw.SizedBox(height: 10);

            // Category wise breakdown
            if (phoneBills.isNotEmpty) {
              widgets.add(
                _buildCategoryHeader('Phone Bills (${phoneBills.length})'),
              );
              widgets.addAll(_buildBillList(phoneBills));
              widgets.add(pw.SizedBox(height: 8));
            }

            if (accessoriesBills.isNotEmpty) {
              widgets.add(
                _buildCategoryHeader(
                  'Accessories Bills (${accessoriesBills.length})',
                ),
              );
              widgets.addAll(_buildBillList(accessoriesBills));
              widgets.add(pw.SizedBox(height: 8));
            }

            if (tvBills.isNotEmpty) {
              widgets.add(_buildCategoryHeader('TV Bills (${tvBills.length})'));
              widgets.addAll(_buildBillList(tvBills));
              widgets.add(pw.SizedBox(height: 8));
            }

            if (applianceBills.isNotEmpty) {
              widgets.add(
                _buildCategoryHeader(
                  'Appliance Bills (${applianceBills.length})',
                ),
              );
              widgets.addAll(_buildBillList(applianceBills));
              widgets.add(pw.SizedBox(height: 8));
            }

            return widgets;
          },
        ),
      );

      // Save and share PDF
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/sales_search_report.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Sales Search Report - Query: $_searchQuery');

      setState(() {
        _isGeneratingPDF = false;
      });
    } catch (e) {
      setState(() {
        _isGeneratingPDF = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildCategoryHeader(String title) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey300,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  List<pw.Widget> _buildBillList(List<Map<String, dynamic>> bills) {
    final List<pw.Widget> widgets = [];

    for (int i = 0; i < bills.length; i++) {
      final bill = bills[i];
      final serialNumber = i + 1;

      widgets.add(
        pw.Container(
          padding: pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '$serialNumber. ${bill['billNumber'] ?? 'N/A'}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  pw.Text(
                    '₹${widget.formatNumber((bill['totalAmount'] as num?)?.toDouble() ?? 0)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                      color: PdfColors.green,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Customer: ${bill['customerName'] ?? 'N/A'}',
                style: pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Mobile: ${bill['customerMobile'] ?? 'N/A'}',
                style: pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Product: ${_getProductName(bill)}',
                style: pw.TextStyle(fontSize: 9),
              ),
              if (_getImei(bill).isNotEmpty)
                pw.Text(
                  'IMEI: ${_getImei(bill)}',
                  style: pw.TextStyle(fontSize: 9),
                ),
              if (_getSerialNumber(bill).isNotEmpty)
                pw.Text(
                  'Serial: ${_getSerialNumber(bill)}',
                  style: pw.TextStyle(fontSize: 9),
                ),
              pw.Text(
                'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format((bill['billDate'] as Timestamp?)?.toDate() ?? DateTime.now())}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _searchResults = [];
      _hasSearched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Search Sales',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          if (_hasSearched && _searchResults.isNotEmpty)
            IconButton(
              icon: _isGeneratingPDF
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              onPressed: _isGeneratingPDF ? null : _generateSearchReport,
              tooltip: 'Export Results as PDF',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllBills,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by any detail...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                  ),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF0A4D2E),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                        onSubmitted: (_) => _performSearch(),
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Filter dropdown
                Row(
                  children: [
                    const Text(
                      'Filter by: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFilter,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          isDense: true,
                        ),
                        items: _filterOptions.map((filter) {
                          return DropdownMenuItem(
                            value: filter.toLowerCase().replaceAll(' ', '_'),
                            child: Text(filter),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value ?? 'all';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (_hasSearched) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Found ${_searchResults.length} result(s)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: primaryGreen,
                          ),
                        ),
                        if (_searchResults.isNotEmpty)
                          Text(
                            'Total Sales: ₹${widget.formatNumber(_searchResults.fold<double>(0, (sum, bill) {
                              return sum + ((bill['totalAmount'] as num?)?.toDouble() ?? 0);
                            }))}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: secondaryGreen,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasSearched
                ? _searchResults.isEmpty
                      ? _buildEmptyState()
                      : _buildResultsList()
                : _buildWelcomeState(),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Search Sales Records',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search by IMEI, Serial Number, Customer Name,\nPhone Number, Product Name, or Bill Number',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildSearchHint('IMEI: 123456789012345'),
                _buildSearchHint('Name: John Doe'),
                _buildSearchHint('Phone: 9876543210'),
                _buildSearchHint('Product: iPhone 15'),
                _buildSearchHint('Bill: INV-2024-001'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.search, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms or filters',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _clearSearch,
            icon: const Icon(Icons.refresh),
            label: const Text('Clear Search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    // Calculate totals
    final totalAmount = _searchResults.fold<double>(0, (sum, bill) {
      return sum + ((bill['totalAmount'] as num?)?.toDouble() ?? 0);
    });

    return Column(
      children: [
        // Summary Card
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryGreen, secondaryGreen],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search Results',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      Text(
                        'Query: "$_searchQuery"',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_searchResults.length} Bills',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Sales',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          '₹${widget.formatNumber(totalAmount)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Results List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final bill = _searchResults[index];
              return _buildResultCard(bill);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(Map<String, dynamic> bill) {
    final billDate = bill['billDate'] is Timestamp
        ? (bill['billDate'] as Timestamp).toDate()
        : (bill['createdAt'] is Timestamp
              ? (bill['createdAt'] as Timestamp).toDate()
              : DateTime.now());

    final totalAmount = (bill['totalAmount'] as num?)?.toDouble() ?? 0;
    final billType = bill['billType'] as String?;
    final type = bill['type'] as String?;

    final isTvBill = type == 'tv';
    final isAccessoriesBill = billType == 'GST Accessories';
    final isApplianceBill = billType == 'Appliances' || billType == 'Appliance';
    final isPhoneBill = !isTvBill && !isAccessoriesBill && !isApplianceBill;

    final String productName = _getProductName(bill);
    final String imei = _getImei(bill);
    final String serialNumber = _getSerialNumber(bill);

    IconData getBillIcon() {
      if (isTvBill) return Icons.tv;
      if (isAccessoriesBill) return Icons.shopping_bag;
      if (isApplianceBill) return Icons.kitchen;
      return Icons.phone_android;
    }

    Color getBillColor() {
      if (isTvBill) return Colors.purple;
      if (isAccessoriesBill) return Colors.orange;
      if (isApplianceBill) return Colors.teal;
      return primaryGreen;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              _showBillDetailsDialog(bill);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: getBillColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                getBillIcon(),
                                size: 18,
                                color: getBillColor(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bill['billNumber'] ?? 'N/A',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: primaryGreen,
                                    ),
                                  ),
                                  Text(
                                    productName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${widget.formatNumber(totalAmount)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: secondaryGreen,
                            ),
                          ),
                          if (bill['sealApplied'] == true)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: warningColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Seal Applied',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: warningColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(
                          Icons.person,
                          bill['customerName'] ?? 'N/A',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoChip(
                          Icons.phone,
                          bill['customerMobile'] ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(
                          Icons.store,
                          bill['shopName'] ?? bill['shop'] ?? 'N/A',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoChip(
                          Icons.calendar_today,
                          DateFormat('dd MMM yyyy, hh:mm a').format(billDate),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  if (imei.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.qr_code,
                          'IMEI: $imei',
                          fontSize: 10,
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _copyImei(imei),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy, size: 12, color: Colors.blue),
                                const SizedBox(width: 2),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (serialNumber.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildInfoChip(
                      Icons.confirmation_number,
                      'Serial: $serialNumber',
                      fontSize: 10,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _printAndShareBill(bill),
                    icon: const Icon(Icons.print, size: 18, color: Colors.blue),
                    label: const Text(
                      'Print/Share',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                Container(height: 25, width: 1, color: Colors.grey[200]),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      // Navigate to bill details
                      _showBillDetailsDialog(bill);
                    },
                    icon: const Icon(Icons.info, size: 18, color: Colors.grey),
                    label: const Text(
                      'Details',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String text, {
    double fontSize = 10,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color ?? Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              color: color ?? Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showBillDetailsDialog(Map<String, dynamic> bill) {
    final billDate = bill['billDate'] is Timestamp
        ? (bill['billDate'] as Timestamp).toDate()
        : (bill['createdAt'] is Timestamp
              ? (bill['createdAt'] as Timestamp).toDate()
              : DateTime.now());

    final totalAmount = (bill['totalAmount'] as num?)?.toDouble() ?? 0;
    final taxableAmount = (bill['taxableAmount'] as num?)?.toDouble() ?? 0;
    final gstAmount = (bill['gstAmount'] as num?)?.toDouble() ?? 0;
    final gstRate = (bill['gstRate'] as num?)?.toDouble() ?? 0;
    final billType = bill['billType'] as String?;
    final type = bill['type'] as String?;

    final isTvBill = type == 'tv';
    final isAccessoriesBill = billType == 'GST Accessories';
    final isApplianceBill = billType == 'Appliances' || billType == 'Appliance';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isTvBill
                              ? Icons.tv
                              : isAccessoriesBill
                              ? Icons.shopping_bag
                              : isApplianceBill
                              ? Icons.kitchen
                              : Icons.phone_android,
                          color: primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          bill['billNumber'] ?? 'Bill Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          'Customer',
                          bill['customerName'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Mobile',
                          bill['customerMobile'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Address',
                          bill['customerAddress'] ?? 'N/A',
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Shop',
                          bill['shopName'] ?? bill['shop'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Created By',
                          bill['createdByName'] ?? bill['createdBy'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Date',
                          DateFormat('dd MMM yyyy, hh:mm a').format(billDate),
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Product Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildDetailRow('Product', _getProductName(bill)),
                        if (_getImei(bill).isNotEmpty)
                          _buildDetailRowWithCopy('IMEI', _getImei(bill), true),
                        if (_getSerialNumber(bill).isNotEmpty)
                          _buildDetailRow(
                            'Serial Number',
                            _getSerialNumber(bill),
                          ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Payment Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildDetailRow(
                          'Purchase Mode',
                          bill['purchaseMode'] ?? 'N/A',
                        ),
                        if (gstRate > 0) ...[
                          _buildDetailRow(
                            'GST Rate',
                            '${gstRate.toStringAsFixed(0)}%',
                          ),
                          _buildDetailRow(
                            'Taxable Amount',
                            '₹${widget.formatNumber(taxableAmount)}',
                          ),
                          _buildDetailRow(
                            'GST Amount',
                            '₹${widget.formatNumber(gstAmount)}',
                          ),
                        ],
                        _buildDetailRow(
                          'Total Amount',
                          '₹${widget.formatNumber(totalAmount)}',
                          isBold: true,
                          color: secondaryGreen,
                        ),
                        if (bill['financeType']?.isNotEmpty == true)
                          _buildDetailRow('Finance Type', bill['financeType']),
                        if (bill['sealApplied'] == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: warningColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.verified,
                                    color: warningColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Seal Applied to this product',
                                    style: TextStyle(
                                      color: warningColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithCopy(String label, String value, bool showCopy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
                if (showCopy && value.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: Colors.blue),
                    onPressed: () => _copyImei(value),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
