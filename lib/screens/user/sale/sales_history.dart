import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

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

  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  double totalAmount = 0.0;
  int totalSales = 0;
  Map<String, double> typeTotals = {};

  final Color _primaryColor = const Color(0xFF10B981);
  final Color _whatsappColor = const Color(0xFF25D366);
  final Color _shareColor = const Color(0xFF3B82F6);

  Uint8List? _logoImage;
  Uint8List? _sealImage;

  // Shop details for sharing
  String? _shopMobileNumber;
  String? _shopWhatsAppNumber;
  String? _shopInstagram;

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _loadImages();
    _getShopDetails();
    if (widget.shopId.isEmpty) {
      _showError('Shop ID is required to view sales history');
      setState(() => isLoading = false);
    } else {
      fetchSalesData();
    }
  }

  Future<void> _getShopDetails() async {
    try {
      if (widget.shopId.isEmpty) return;

      final shopDoc = await FirebaseFirestore.instance
          .collection('Mobile_house_Shops')
          .doc(widget.shopId)
          .get();

      if (shopDoc.exists) {
        final shopData = shopDoc.data() ?? {};
        setState(() {
          _shopMobileNumber = shopData['phone']?.toString() ?? '';
          _shopWhatsAppNumber =
              shopData['whatsapp']?.toString() ??
              shopData['phone']?.toString() ??
              '';
          _shopInstagram = shopData['instagram']?.toString() ?? 'mobile.house_';
        });
      }
    } catch (e) {
      debugPrint('Error fetching shop details: $e');
    }
  }

  Future<void> _loadImages() async {
    try {
      final logoByteData = await rootBundle.load('assets/mobileHouseLogo.png');
      _logoImage = logoByteData.buffer.asUint8List();
      final sealByteData = await rootBundle.load('assets/mobileHouseSeal.jpeg');
      _sealImage = sealByteData.buffer.asUint8List();
    } catch (e) {
      print('Error loading images: $e');
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

    for (var collection in collectionNames) {
      try {
        final List<Map<String, dynamic>> periodSales =
            await _fetchSalesForCollection(collection);

        for (var sale in periodSales) {
          sale['collection'] = collection;
          sale['type'] = _getSaleType(collection);
          sale['displayDate'] = _formatDate(sale, collection);
          sale['displayAmount'] = _getAmount(sale, collection);
          sale['customerInfo'] = _getCustomerInfo(sale);
          sale['customerPhone'] = _getCustomerPhone(sale);
          sale['paymentInfo'] = _getPaymentInfo(sale, collection);
          sale['shopName'] = _getShopName(sale, collection);

          if (collection == 'accessories_service_sales') {
            sale['accessoriesAmount'] = (sale['accessoriesAmount'] ?? 0)
                .toDouble();
            sale['serviceAmount'] = (sale['serviceAmount'] ?? 0).toDouble();
          }

          allSales.add(sale);
        }
      } catch (e) {
        print('Error fetching $collection: $e');
      }
    }

    _calculateReportData();
    _applyFilter();

    setState(() => isLoading = false);
  }

  // Updated: Improved method to get customer phone number from various field names
  String _getCustomerPhone(Map<String, dynamic> data) {
    // Check all possible field names that might contain the customer phone
    if (data['customerPhone'] != null &&
        data['customerPhone'].toString().isNotEmpty &&
        data['customerPhone'].toString() != 'null') {
      return data['customerPhone'].toString();
    }
    if (data['phone'] != null &&
        data['phone'].toString().isNotEmpty &&
        data['phone'].toString() != 'null') {
      return data['phone'].toString();
    }
    if (data['mobile'] != null &&
        data['mobile'].toString().isNotEmpty &&
        data['mobile'].toString() != 'null') {
      return data['mobile'].toString();
    }
    if (data['customerMobile'] != null &&
        data['customerMobile'].toString().isNotEmpty &&
        data['customerMobile'].toString() != 'null') {
      return data['customerMobile'].toString();
    }
    if (data['contactNumber'] != null &&
        data['contactNumber'].toString().isNotEmpty &&
        data['contactNumber'].toString() != 'null') {
      return data['contactNumber'].toString();
    }
    if (data['customer_phone'] != null &&
        data['customer_phone'].toString().isNotEmpty &&
        data['customer_phone'].toString() != 'null') {
      return data['customer_phone'].toString();
    }
    if (data['buyerPhone'] != null &&
        data['buyerPhone'].toString().isNotEmpty &&
        data['buyerPhone'].toString() != 'null') {
      return data['buyerPhone'].toString();
    }
    return '';
  }

  // Make phone call
  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _showError('No phone number available');
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showError('Could not launch phone dialer');
    }
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

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      tempSales = tempSales.where((sale) {
        final customer = (sale['customerInfo'] as String).toLowerCase();
        final customerPhone = (sale['customerPhone'] as String).toLowerCase();
        final shopName = (sale['shopName'] as String).toLowerCase();
        final type = (sale['type'] as String).toLowerCase();
        final product = (sale['productName'] ?? '').toString().toLowerCase();
        final brand = (sale['brand'] ?? '').toString().toLowerCase();
        final imei = (sale['imei'] ?? '').toString().toLowerCase();

        return customer.contains(query) ||
            customerPhone.contains(query) ||
            shopName.contains(query) ||
            type.contains(query) ||
            product.contains(query) ||
            brand.contains(query) ||
            imei.contains(query);
      }).toList();
    }

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

  // ==================== PDF BILL GENERATION ====================

  String _amountToWords(String amount) {
    try {
      double value = double.parse(amount);
      if (value == 0) return 'Zero Rupees Only';

      int rupees = value.toInt();
      int paise = ((value - rupees) * 100).round();

      String rupeeWords = _convertNumberToWords(rupees);
      String paiseWords = paise > 0
          ? ' and ${_convertNumberToWords(paise)} Paise'
          : '';

      return '${rupeeWords.trim()} Rupees$paiseWords Only';
    } catch (e) {
      return 'Amount in words conversion failed';
    }
  }

  String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';

    List<String> units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
    ];
    List<String> teens = [
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    List<String> tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    String words = '';

    if (number >= 10000000) {
      words += '${_convertNumberToWords(number ~/ 10000000)} Crore ';
      number %= 10000000;
    }

    if (number >= 100000) {
      words += '${_convertNumberToWords(number ~/ 100000)} Lakh ';
      number %= 100000;
    }

    if (number >= 1000) {
      words += '${_convertNumberToWords(number ~/ 1000)} Thousand ';
      number %= 1000;
    }

    if (number >= 100) {
      words += '${_convertNumberToWords(number ~/ 100)} Hundred ';
      number %= 100;
    }

    if (number > 0) {
      if (words.isNotEmpty) words += 'and ';

      if (number < 10) {
        words += units[number];
      } else if (number < 20) {
        words += teens[number - 10];
      } else {
        words += tens[number ~/ 10];
        if (number % 10 > 0) {
          words += ' ${units[number % 10]}';
        }
      }
    }

    return words.trim();
  }

  Future<Uint8List> _generatePdf(Map<String, dynamic> sale) async {
    final pdf = pw.Document();
    final pageFormat = PdfPageFormat.a4;
    String currentDate = DateFormat('dd MMMM yyyy').format(DateTime.now());

    final fullBillNumber =
        sale['billNumber']?.toString() ??
        sale['soldBillNo']?.toString() ??
        'MH-${DateTime.now().millisecondsSinceEpoch}';

    final customerName =
        sale['customerInfo'] as String? ??
        sale['customerName']?.toString() ??
        'Walk-in Customer';
    final customerMobile =
        sale['customerPhone']?.toString() ??
        sale['customerMobile']?.toString() ??
        '';
    final customerAddress = sale['address']?.toString() ?? '';

    final phoneModel =
        sale['productModel']?.toString() ??
        sale['productName']?.toString() ??
        'N/A';
    final imei = sale['imei']?.toString() ?? '';

    final totalAmount = (sale['displayAmount'] as num?)?.toDouble() ?? 0.0;
    final taxableAmount = totalAmount / 1.18;
    final gstAmount = totalAmount - taxableAmount;

    final purchaseMode = sale['purchaseMode']?.toString() ?? '';
    final financeType = sale['financeType']?.toString() ?? '';
    final shopName = sale['shopName']?.toString() ?? 'MOBILE HOUSE';
    final selectedShop = shopName.contains('Cherpu')
        ? 'Cherpu'
        : 'Peringottukara';

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(15),
        build: (pw.Context context) {
          return _buildInvoiceContent(
            currentDate: currentDate,
            fullBillNumber: fullBillNumber,
            customerName: customerName,
            customerMobile: customerMobile,
            customerAddress: customerAddress,
            phoneModel: phoneModel,
            imei: imei,
            totalAmount: totalAmount,
            taxableAmount: taxableAmount,
            gstAmount: gstAmount,
            selectedShop: selectedShop,
            purchaseMode: purchaseMode,
            financeType: financeType,
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildInvoiceContent({
    required String currentDate,
    required String fullBillNumber,
    required String customerName,
    required String customerMobile,
    required String customerAddress,
    required String phoneModel,
    required String imei,
    required double totalAmount,
    required double taxableAmount,
    required double gstAmount,
    required String selectedShop,
    required String purchaseMode,
    required String financeType,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader(currentDate, fullBillNumber, selectedShop),
          _buildCustomerDetails(
            customerName,
            customerMobile,
            customerAddress,
            purchaseMode,
            financeType,
          ),
          pw.SizedBox(height: 4),
          _buildMainTable(
            phoneModel,
            imei,
            taxableAmount,
            gstAmount,
            totalAmount,
          ),
          pw.SizedBox(height: 280),
          _buildTotalSection(totalAmount, taxableAmount, gstAmount),
          _buildBottomSection(),
        ],
      ),
    );
  }

  pw.Widget _buildHeader(
    String currentDate,
    String fullBillNumber,
    String selectedShop,
  ) {
    return pw.Column(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              'GSTIN: 32BSGPJ3340H1Z4',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Column(
                children: [
                  if (_logoImage != null)
                    pw.SizedBox(
                      height: 45,
                      child: pw.Image(
                        pw.MemoryImage(_logoImage!),
                        fit: pw.BoxFit.contain,
                      ),
                    )
                  else
                    pw.Text(
                      'MOBILE HOUSE',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    selectedShop == 'Peringottukara'
                        ? "3way junction Peringottukara"
                        : "Cherpu, Thayamkulangara",
                    style: pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    selectedShop == 'Peringottukara'
                        ? "Mob: 9072430483, 8304830868"
                        : "Mob: 9544466724",
                    style: pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text("Mobile house", style: pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    "GST TAX INVOICE (TYPE-B2C) - CASH SALE",
                    style: pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'STATE : KERALA',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Invoice No. : $fullBillNumber',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'STATE CODE : 32',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Invoice Date : $currentDate',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.Divider(color: PdfColors.black, thickness: 0.2, height: 0),
      ],
    );
  }

  pw.Widget _buildCustomerDetails(
    String customerName,
    String customerMobile,
    String customerAddress,
    String purchaseMode,
    String financeType,
  ) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: pw.Container(
        padding: pw.EdgeInsets.all(2),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Customer  : $customerName',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            if (customerMobile.isNotEmpty)
              pw.Text(
                'Mobile Tel  : $customerMobile',
                style: pw.TextStyle(fontSize: 11),
              ),
            pw.SizedBox(height: 4),
            if (customerAddress.isNotEmpty)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Address     :', style: pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Text(
                      customerAddress.isNotEmpty ? customerAddress : "N/A",
                      style: pw.TextStyle(fontSize: 11),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            pw.SizedBox(height: 6),
            if (purchaseMode == 'EMI' && financeType.isNotEmpty)
              pw.Row(
                children: [
                  pw.Text(
                    'Finance       : ',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    financeType,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildMainTable(
    String phoneModel,
    String imei,
    double taxableAmount,
    double gstAmount,
    double totalAmount,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: pw.FixedColumnWidth(40),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FixedColumnWidth(60),
        3: pw.FixedColumnWidth(25),
        4: pw.FixedColumnWidth(50),
        5: pw.FixedColumnWidth(70),
        6: pw.FixedColumnWidth(45),
        7: pw.FixedColumnWidth(50),
        8: pw.FixedColumnWidth(60),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: [
            _buildTableCell('SLNO', isHeader: true),
            _buildTableCell('Name of Item/Commodity', isHeader: true),
            _buildTableCell('HSNCode', isHeader: true),
            _buildTableCell('Qty', isHeader: true),
            _buildTableCell(' Rate', isHeader: true),
            _buildTableCell(' Discount', isHeader: true),
            _buildTableCell('GST%', isHeader: true),
            _buildTableCell('GST Amt', isHeader: true),
            _buildTableCell('Total ', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('1'),
            _buildTableCell(
              '${phoneModel.isNotEmpty ? phoneModel : ""}\nIMEI: ${imei.isNotEmpty ? imei : ""}',
              textAlign: pw.TextAlign.left,
              fontSize: 11,
              maxLines: 3,
            ),
            _buildTableCell('85171300'),
            _buildTableCell('1'),
            _buildTableCell(taxableAmount.toStringAsFixed(2)),
            _buildTableCell('0.00'),
            _buildTableCell('18'),
            _buildTableCell(gstAmount.toStringAsFixed(2)),
            _buildTableCell(totalAmount.toStringAsFixed(2)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTotalSection(
    double totalAmount,
    double taxableAmount,
    double gstAmount,
  ) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.black, thickness: 0.5, height: 0),
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '1',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                taxableAmount.toStringAsFixed(2),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                gstAmount.toStringAsFixed(2),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                totalAmount.toStringAsFixed(2),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.Divider(color: PdfColors.black, thickness: 0.5, height: 0),
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'In Words: ${_amountToWords(totalAmount.toStringAsFixed(2))}',
                style: pw.TextStyle(fontSize: 11),
                maxLines: 2,
              ),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total Amount: ${totalAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildBottomSection() {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: pw.EdgeInsets.all(2),
              child: _buildGstBreakdownTable(),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            flex: 1,
            child: pw.Container(
              padding: pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Certified that the particulars given above are true and correct',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 15),
                  pw.Text(
                    'For MOBILE HOUSE',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: PdfColors.black, thickness: 0.5),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Authorised Signatory',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Table _buildGstBreakdownTable() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: pw.FixedColumnWidth(40),
        1: pw.FixedColumnWidth(35),
        2: pw.FixedColumnWidth(35),
        3: pw.FixedColumnWidth(35),
        4: pw.FixedColumnWidth(40),
        5: pw.FixedColumnWidth(40),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: [
            _buildTableCell('', isHeader: true, fontSize: 9),
            _buildTableCell('GST 0%', isHeader: true, fontSize: 9),
            _buildTableCell('GST 5%', isHeader: true, fontSize: 9),
            _buildTableCell('GST 12%', isHeader: true, fontSize: 9),
            _buildTableCell('GST 18%', isHeader: true, fontSize: 9),
            _buildTableCell('GST 28%', isHeader: true, fontSize: 9),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Taxable', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('CGST Amt', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('SGST Amt', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
            _buildTableCell('0.00', fontSize: 9),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    double fontSize = 11,
    pw.TextAlign textAlign = pw.TextAlign.center,
    int maxLines = 1,
  }) {
    final lines = text.split('\n');

    if (maxLines <= 1 || lines.length <= 1) {
      return pw.Container(
        alignment: pw.Alignment.center,
        padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
          textAlign: textAlign,
          maxLines: maxLines,
        ),
      );
    }

    return pw.Container(
      alignment: pw.Alignment.center,
      padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            lines[0],
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          for (int i = 1; i < lines.length && i < maxLines; i++)
            pw.Text(
              lines[i],
              style: pw.TextStyle(
                fontSize: fontSize * 0.9,
                fontWeight: pw.FontWeight.normal,
              ),
              textAlign: pw.TextAlign.center,
            ),
        ],
      ),
    );
  }

  // ==================== SHARE FUNCTIONS ====================

  Future<void> _sharePdfBill(Map<String, dynamic> sale) async {
    try {
      _showMessage('Generating PDF bill...', isError: false);

      final pdfBytes = await _generatePdf(sale);

      final directory = await getTemporaryDirectory();
      final fileName =
          'Bill_${sale['customerInfo']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/pdf', name: fileName)],
        text: 'Mobile House Bill - ${sale['customerInfo']}',
        subject: 'Mobile House Bill',
      );

      _showMessage('PDF shared successfully!', isError: false);
    } catch (e) {
      _showError('Error sharing PDF: $e');
    }
  }

  String _generateEmiShareMessage(Map<String, dynamic> sale) {
    final brand = sale['brand']?.toString().toUpperCase() ?? '';
    final model = sale['productModel']?.toString() ?? '';
    final price = (sale['displayAmount'] as num?)?.toDouble() ?? 0.0;
    final discount = (sale['discount'] as num?)?.toDouble() ?? 0.0;
    final exchange = (sale['exchangeValue'] as num?)?.toDouble() ?? 0.0;
    final customerCredit = (sale['customerCredit'] as num?)?.toDouble() ?? 0.0;
    final effectivePrice = (sale['effectivePrice'] as num?)?.toDouble() ?? 0.0;
    final amountToPay = (sale['amountToPay'] as num?)?.toDouble() ?? 0.0;
    final balanceReturned =
        (sale['balanceReturnedToCustomer'] as num?)?.toDouble() ?? 0.0;

    DateTime saleDate;
    if (sale['saleDate'] is Timestamp) {
      saleDate = (sale['saleDate'] as Timestamp).toDate();
    } else if (sale['addedAt'] is Timestamp) {
      saleDate = (sale['addedAt'] as Timestamp).toDate();
    } else if (sale['saleDate'] is DateTime) {
      saleDate = sale['saleDate'] as DateTime;
    } else if (sale['addedAt'] is DateTime) {
      saleDate = sale['addedAt'] as DateTime;
    } else {
      saleDate = DateTime.now();
    }

    final customerName =
        sale['customerInfo'] as String? ??
        sale['customerName']?.toString() ??
        'Walk-in Customer';
    final customerPhone = sale['customerPhone']?.toString() ?? '';
    final gifts = sale['giftsList']?.toString() ?? '';

    final paymentBreakdown =
        sale['paymentBreakdown'] as Map<String, dynamic>? ?? {};
    final cashAmount = (paymentBreakdown['cash'] as num?)?.toDouble() ?? 0.0;
    final gpayAmount = (paymentBreakdown['gpay'] as num?)?.toDouble() ?? 0.0;
    final cardAmount = (paymentBreakdown['card'] as num?)?.toDouble() ?? 0.0;
    final creditAmount =
        (paymentBreakdown['credit'] as num?)?.toDouble() ?? 0.0;

    final downPayment = (sale['downPayment'] as num?)?.toDouble() ?? 0.0;
    final numberOfEmi = sale['numberOfEmi'] ?? 0;
    final perMonthEmi = (sale['perMonthEmi'] as num?)?.toDouble() ?? 0.0;
    final financeType = sale['financeType']?.toString() ?? '';
    final loanId = sale['loanId']?.toString() ?? '';
    final autoDebit = sale['autoDebit'] as bool? ?? false;
    final insurance = sale['insurance'] as bool? ?? false;

    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = dateFormat.format(saleDate);

    final shopMobile = _shopMobileNumber ?? '9072430483';
    final shopWhatsApp = _shopWhatsAppNumber ?? shopMobile;
    final shopInstagram = _shopInstagram ?? 'mobile.house_';
    final shopName = sale['shopName']?.toString() ?? 'MOBILE HOUSE';

    final buffer = StringBuffer();

    buffer.writeln('📱 *$shopName*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();
    buffer.writeln('✨ *Thanks For Your Visit* ✨');
    buffer.writeln('[ Keep In Touch With Mobile House 😍]');
    buffer.writeln(
      '📸 Instagram : https://instagram.com/${shopInstagram.replaceAll('@', '')}',
    );
    buffer.writeln();
    buffer.writeln('✨ *EMI DETAILS* ✨');
    buffer.writeln();
    buffer.writeln(' Shop : $shopName');
    buffer.writeln(' Brand : $brand');
    buffer.writeln(' Model : $model');
    buffer.writeln(' Price : ₹${price.toStringAsFixed(0)}');

    if (discount > 0) {
      buffer.writeln(' Discount : ₹${discount.toStringAsFixed(0)}');
    }

    buffer.writeln(' Down Payment : ₹${downPayment.toStringAsFixed(0)}');

    if (cashAmount > 0 ||
        gpayAmount > 0 ||
        cardAmount > 0 ||
        creditAmount > 0) {
      if (cashAmount > 0)
        buffer.writeln('    • Cash: ₹${cashAmount.toStringAsFixed(0)}');
      if (gpayAmount > 0)
        buffer.writeln('    • GPay: ₹${gpayAmount.toStringAsFixed(0)}');
      if (cardAmount > 0)
        buffer.writeln('    • Card: ₹${cardAmount.toStringAsFixed(0)}');
      if (creditAmount > 0)
        buffer.writeln('    • Credit: ₹${creditAmount.toStringAsFixed(0)}');
    }

    if (exchange > 0) {
      buffer.writeln(' Exchange : ₹${exchange.toStringAsFixed(0)}');
    }

    if (customerCredit > 0) {
      buffer.writeln(
        ' Customer Credit : ₹${customerCredit.toStringAsFixed(0)}',
      );
    }

    if (balanceReturned > 0) {
      buffer.writeln(
        ' Balance Returned : ₹${balanceReturned.toStringAsFixed(0)}',
      );
    }

    buffer.writeln();
    buffer.writeln(' EMI : ₹${perMonthEmi.toStringAsFixed(0)}*$numberOfEmi');
    buffer.writeln(' Finance : $financeType');

    if (loanId.isNotEmpty) {
      buffer.writeln(' Loan Id : $loanId');
    }

    buffer.writeln(' Auto Debit : ${autoDebit ? ' YES' : ' NO'}');
    buffer.writeln(' Insurance : ${insurance ? ' YES' : ' NO'}');
    buffer.writeln(' Date : $formattedDate');
    buffer.writeln();
    buffer.writeln(' Customer : $customerName');
    buffer.writeln(' Mobile : $customerPhone');

    if (gifts.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('*Mobile house Special gift🎁* ');
      buffer.writeln(' $gifts');
    }

    buffer.writeln();
    buffer.writeln('⚠️ *എല്ലാ മാസവും 1 നു മുമ്പ് EMI pay ചെയ്യണം*');
    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();
    buffer.writeln('🎯 *For Exciting Offers*');
    buffer.writeln('📸 Follow @${shopInstagram.replaceAll('@', '')}');
    buffer.writeln();
    buffer.writeln('📱 MOBILE SALES - SERVICE - EXCHANGE');
    buffer.writeln();
    buffer.writeln(
      '🔄 *പഴയ മൊബൈൽ കൊണ്ടു വരൂ എക്സ്ചേഞ്ച് ചെയ്തു പുതിയ മൊബൈൽ സ്വന്തമാക്കൂ...*',
    );
    buffer.writeln();
    buffer.writeln('📞 *For more info:*');
    buffer.writeln('📞 Whatsapp : $shopWhatsApp');
    buffer.writeln('🌐 Website : https://mobilehouse.in/');

    return buffer.toString();
  }

  void _shareViaIntent(String message) async {
    try {
      await Share.share(message);
    } catch (e) {
      _showError('Could not share: $e');
    }
  }

  void _shareToWhatsApp(String message, {String? phoneNumber}) async {
    try {
      String phone = phoneNumber ?? '';

      phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

      if (phone.isNotEmpty && phone.length >= 10) {
        if (phone.length == 10) {
          phone = '91$phone';
        }
      } else {
        phone = _shopWhatsAppNumber ?? '9072430483';
        if (!phone.startsWith('+') && phone.length == 10) {
          phone = '91$phone';
        } else if (phone.startsWith('+')) {
          phone = phone.substring(1);
        }
      }

      phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

      final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showMessage(
          'Could not open WhatsApp. Using share instead...',
          isError: false,
        );
        _shareViaIntent(message);
      }
    } catch (e) {
      debugPrint('Error sharing to WhatsApp: $e');
      _shareViaIntent(message);
    }
  }

  void _showShareOptionsForPhoneSale(Map<String, dynamic> sale) {
    final isEmiMode = sale['purchaseMode']?.toString() == 'EMI';
    final customerPhone = sale['customerPhone']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 20),
              const Text(
                'Share Options',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildShareOption(
                icon: Icons.picture_as_pdf,
                label: 'Share PDF Bill',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _sharePdfBill(sale);
                },
              ),
              const SizedBox(height: 12),
              if (isEmiMode)
                _buildShareOption(
                  icon: Icons.credit_card,
                  label: 'Share EMI Details',
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    final message = _generateEmiShareMessage(sale);
                    Navigator.pop(context);
                    _showShareMethodDialog(message, customerPhone);
                  },
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShareMethodDialog(String message, String customerPhone) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Share via'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.blue),
                title: const Text('Copy to Clipboard'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message));
                  Navigator.pop(context);
                  _showSuccess('Copied to clipboard!');
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.green),
                title: const Text('Share via...'),
                onTap: () {
                  Navigator.pop(context);
                  _shareViaIntent(message);
                },
              ),
              if (customerPhone.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.message, color: Color(0xFF25D366)),
                  title: const Text('Share to WhatsApp'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareToWhatsApp(message, phoneNumber: customerPhone);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  // ==================== END SHARE FUNCTIONS ====================

  Future<void> _deleteSale(Map<String, dynamic> sale) async {
    final collection = sale['collection'] as String;
    final saleId = sale['id'] as String;
    final saleType = sale['type'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sale'),
        content: Text(
          'Are you sure you want to delete this $saleType sale?\n\n'
          'Customer: ${sale['customerInfo']}\n'
          'Amount: ₹${(sale['displayAmount'] as double).toStringAsFixed(0)}\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (collection == 'base_model_sale') {
        final imei = sale['imei']?.toString();
        if (imei != null && imei.isNotEmpty) {
          final baseModelStockSnapshot = await FirebaseFirestore.instance
              .collection('baseModelStock')
              .where('imei', isEqualTo: imei)
              .where('shopId', isEqualTo: widget.shopId)
              .limit(1)
              .get();

          if (baseModelStockSnapshot.docs.isNotEmpty) {
            final stockDoc = baseModelStockSnapshot.docs.first;
            await stockDoc.reference.update({
              'status': 'available',
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedBy': 'system',
            });
          }
        }
      }

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(saleId)
          .delete();

      Navigator.pop(context);
      _showSuccess('$saleType sale deleted successfully');
      await fetchSalesData();
    } catch (e) {
      Navigator.pop(context);
      _showError('Error deleting sale: $e');
    }
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
              Clipboard.setData(ClipboardData(text: reportContent));
              _showSuccess('Report copied to clipboard');
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
              return _parseDateString(data[field].toString());
            }
          }
        }
      }

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
      if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length >= 3) {
          final day = int.tryParse(parts[0]) ?? 1;
          final month = int.tryParse(parts[1]) ?? 1;
          final year = int.tryParse(parts[2]) ?? DateTime.now().year;
          return DateTime(year, month, day);
        }
      }
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
          if (data['totalSaleAmount'] != null) {
            return (data['totalSaleAmount'] ?? 0).toDouble();
          } else {
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
      'actualCash': 0.0,
      'actualCard': 0.0,
      'actualGpay': 0.0,
    };

    try {
      if (collection == 'accessories_service_sales') {
        paymentInfo['actualCash'] = (data['cashAmount'] ?? 0).toDouble();
        paymentInfo['actualCard'] = (data['cardAmount'] ?? 0).toDouble();
        paymentInfo['actualGpay'] = (data['gpayAmount'] ?? 0).toDouble();
        paymentInfo['credit'] = (data['customerCredit'] ?? 0).toDouble();
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
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
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextField(
                    controller: searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText:
                          'Search by customer, phone, product, brand, IMEI...',
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
                              ),
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
                                    final customerPhone =
                                        sale['customerPhone']?.toString() ?? '';

                                    // Check if it's a phone sale for share button
                                    final isPhoneSale =
                                        sale['collection'] == 'phoneSales';

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
                                            // Show phone number for ALL sale types that have a phone number
                                            if (customerPhone.isNotEmpty)
                                              GestureDetector(
                                                onTap: () => _makePhoneCall(
                                                  customerPhone,
                                                ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.call,
                                                        size: 10,
                                                        color: Colors
                                                            .green
                                                            .shade700,
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        customerPhone,
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors
                                                              .green
                                                              .shade700,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
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
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isPhoneSale)
                                              IconButton(
                                                icon: Icon(
                                                  Icons.share,
                                                  size: 18,
                                                  color: _shareColor,
                                                ),
                                                onPressed: () =>
                                                    _showShareOptionsForPhoneSale(
                                                      sale,
                                                    ),
                                                tooltip: 'Share',
                                              ),
                                            Column(
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
                                                    color: color.withOpacity(
                                                      0.1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    type,
                                                    style: TextStyle(
                                                      fontSize: 8,
                                                      color: color,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: Colors.red.shade400,
                                              ),
                                              onPressed: () =>
                                                  _deleteSale(sale),
                                              tooltip: 'Delete Sale',
                                            ),
                                          ],
                                        ),
                                        onTap: () =>
                                            _showSaleDetails(context, sale),
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
    if (collection == 'accessories_service_sales') {
      final accessoriesAmount = paymentInfo['accessoriesAmount'] ?? 0.0;
      final serviceAmount = paymentInfo['serviceAmount'] ?? 0.0;

      final List<Widget> chips = [];
      if (accessoriesAmount > 0)
        chips.add(
          _buildAmountChip('Accessories', accessoriesAmount, Colors.blue),
        );
      if (serviceAmount > 0)
        chips.add(_buildAmountChip('Service', serviceAmount, Colors.orange));
      return Wrap(spacing: 3, runSpacing: 2, children: chips);
    }

    final List<Widget> chips = [];
    if (paymentInfo['cash'] > 0)
      chips.add(_buildPaymentChip('Cash', paymentInfo['cash'], Colors.green));
    if (paymentInfo['card'] > 0)
      chips.add(_buildPaymentChip('Card', paymentInfo['card'], Colors.blue));
    if (paymentInfo['gpay'] > 0)
      chips.add(_buildPaymentChip('GPay', paymentInfo['gpay'], Colors.purple));
    if (paymentInfo['credit'] > 0)
      chips.add(
        _buildPaymentChip('Credit', paymentInfo['credit'], Colors.orange),
      );
    if (collection == 'phoneSales' && paymentInfo['downPayment'] > 0)
      chips.add(
        _buildPaymentChip('Down', paymentInfo['downPayment'], Colors.teal),
      );

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
    final isPhoneSale = sale['collection'] == 'phoneSales';
    final accessoriesAmount = sale['accessoriesAmount'] as double? ?? 0.0;
    final serviceAmount = sale['serviceAmount'] as double? ?? 0.0;
    final totalAmount = (sale['displayAmount'] as double).toStringAsFixed(0);
    final paymentInfo = sale['paymentInfo'] as Map<String, dynamic>;

    // Get customer phone - check multiple possible field names
    String customerPhone = sale['customerPhone']?.toString() ?? '';

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

              // Phone number row - shown for ALL sale types that have a phone number
              if (customerPhone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Phone:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _makePhoneCall(customerPhone),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  customerPhone,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.call,
                                  size: 14,
                                  color: Colors.green.shade700,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildDetailRow('Shop', sale['shopName'].toString()),
              _buildDetailRow('Date', sale['displayDate'] as String),

              // EMI Mode Display
              if (isPhoneSale && sale['purchaseMode']?.toString() == 'EMI') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: 14,
                            color: Colors.purple.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'EMI Details',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (sale['downPayment'] != null)
                        _buildEmiDetailRow(
                          'Down Payment',
                          sale['downPayment'] as double,
                        ),
                      if (sale['perMonthEmi'] != null &&
                          sale['numberOfEmi'] != null)
                        _buildEmiDetailRow(
                          'EMI',
                          sale['perMonthEmi'] as double,
                          suffix: ' × ${sale['numberOfEmi']} months',
                        ),
                      if (sale['financeType'] != null)
                        _buildEmiDetailText(
                          'Finance',
                          sale['financeType'].toString(),
                        ),
                      if (sale['autoDebit'] != null)
                        _buildEmiDetailText(
                          'Auto Debit',
                          sale['autoDebit'] == true ? 'Yes' : 'No',
                        ),
                      if (sale['insurance'] != null)
                        _buildEmiDetailText(
                          'Insurance',
                          sale['insurance'] == true ? 'Yes' : 'No',
                        ),
                      if (sale['loanId'] != null &&
                          sale['loanId'].toString().isNotEmpty)
                        _buildEmiDetailText(
                          'Loan ID',
                          sale['loanId'].toString(),
                        ),
                    ],
                  ),
                ),
              ],

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
              ] else
                _buildDetailRow('Total Amount', '₹$totalAmount'),

              const SizedBox(height: 8),

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
              ],

              // Show product details for base model and second phone sales
              if (sale['productName'] != null &&
                  sale['collection'] != 'phoneSales')
                _buildDetailRow('Product', sale['productName'].toString()),
              if (sale['productBrand'] != null &&
                  sale['productBrand'].toString().isNotEmpty &&
                  sale['collection'] != 'phoneSales')
                _buildDetailRow('Brand', sale['productBrand'].toString()),
              if (sale['modelName'] != null &&
                  sale['modelName'].toString().isNotEmpty &&
                  sale['collection'] != 'phoneSales')
                _buildDetailRow('Model', sale['modelName'].toString()),
              if (sale['brand'] != null &&
                  sale['brand'].toString().isNotEmpty &&
                  sale['collection'] != 'phoneSales')
                _buildDetailRow('Brand', sale['brand'].toString()),
              if (sale['imei'] != null && sale['collection'] != 'phoneSales')
                _buildDetailRow('IMEI', sale['imei'].toString()),
              if (sale['defect'] != null &&
                  sale['defect'].toString().isNotEmpty)
                _buildDetailRow('Defect', sale['defect'].toString()),
              if (sale['notes'] != null && (sale['notes'] as String).isNotEmpty)
                _buildDetailRow('Notes', sale['notes'].toString()),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  if (!isPhoneSale) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteSale(sale);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper methods for EMI details display
  Widget _buildEmiDetailRow(String label, double amount, {String suffix = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            '₹${amount.toStringAsFixed(0)}$suffix',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmiDetailText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
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
    if (paymentInfo['cash'] > 0)
      widgets.add(_buildPaymentDetailRow('Cash', paymentInfo['cash']));
    if (paymentInfo['card'] > 0)
      widgets.add(_buildPaymentDetailRow('Card', paymentInfo['card']));
    if (paymentInfo['gpay'] > 0)
      widgets.add(_buildPaymentDetailRow('GPay', paymentInfo['gpay']));
    if (paymentInfo['credit'] > 0)
      widgets.add(_buildPaymentDetailRow('Credit', paymentInfo['credit']));
    if (collection == 'phoneSales' && paymentInfo['downPayment'] > 0)
      widgets.add(
        _buildPaymentDetailRow('Down Payment', paymentInfo['downPayment']),
      );
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
