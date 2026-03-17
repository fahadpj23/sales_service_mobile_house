import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firestore_service.dart';

class GSTAccessoriesSaleUpload extends StatefulWidget {
  final Map<String, dynamic>? initialProductData;

  const GSTAccessoriesSaleUpload({super.key, this.initialProductData});

  @override
  State<GSTAccessoriesSaleUpload> createState() =>
      _GSTAccessoriesSaleUploadState();
}

class _GSTAccessoriesSaleUploadState extends State<GSTAccessoriesSaleUpload> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Controllers
  final TextEditingController _billNumberController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _customerAddressController =
      TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _taxableAmountController =
      TextEditingController();
  final TextEditingController _gstAmountController = TextEditingController();

  // Product controllers
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );

  // New Product controllers (for adding new product)
  final TextEditingController _newProductNameController =
      TextEditingController();
  final TextEditingController _newProductPriceController =
      TextEditingController();

  // State variables
  bool isLoading = false;
  bool _isGeneratingBill = false;
  bool _sealChecked = false;
  bool _isAddingProduct = false;

  // FIXED: GST rate fixed at 18%
  final double gstRate = 18.0;

  // FIXED: Shop selection - default Peringottukara
  String? _selectedShop = 'Peringottukara';
  final List<String> _shopOptions = ['Peringottukara', 'Cherpu'];

  // FIXED: Purchase Mode - Always Ready Cash, no dropdown
  final String _purchaseMode = 'Ready Cash';

  // Images for PDF
  Uint8List? _logoImage;
  Uint8List? _sealImage;
  File? _savedPdfFile;

  // Selected product
  Map<String, dynamic>? _selectedProduct;
  List<Map<String, dynamic>> _accessoriesList = [];
  bool _isLoadingAccessories = false;

  // Original stock data from accessories stock screen
  Map<String, dynamic>? _originalStockData;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _generateNextBillNumber();
    _loadAccessories();

    // Initialize with product data if provided
    if (widget.initialProductData != null) {
      _initializeWithProductData(widget.initialProductData!);
    }

    // Add listeners with proper error handling
    _quantityController.addListener(_onPriceOrQuantityChanged);
    _discountController.addListener(_onPriceOrQuantityChanged);
  }

  void _initializeWithProductData(Map<String, dynamic> data) {
    // Store original stock data for later use
    _originalStockData = data;

    // Set quantity
    if (data['quantity'] != null) {
      _quantityController.text = data['quantity'].toString();
    }

    // We'll select the product after loading accessories list
    // This will be handled in _loadAccessories when data is loaded
  }

  Future<void> _loadAccessories() async {
    setState(() => _isLoadingAccessories = true);
    try {
      final querySnapshot = await _firestore
          .collection('accessories')
          .orderBy('accessoryName')
          .get();

      final accessories = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'accessoryName': data['accessoryName'] ?? '',
          'salesPrice':
              data['salesPrice'] ??
              0.0, // Using salesPrice instead of purchaseRate
          'stockQuantity': data['stockQuantity'] ?? 0,
          'hsnCode': data['hsnCode'] ?? '',
          'category': data['category'] ?? '',
        };
      }).toList();

      setState(() {
        _accessoriesList = accessories;
        _isLoadingAccessories = false;
      });

      // If we have initial product data, select the matching product
      if (widget.initialProductData != null && mounted) {
        _selectProductFromInitialData();
      }
    } catch (e) {
      print('Error loading accessories: $e');
      setState(() => _isLoadingAccessories = false);
    }
  }

  void _selectProductFromInitialData() {
    final initialData = widget.initialProductData!;
    final productId = initialData['productId'];
    final productName = initialData['productName'];

    if (productId != null) {
      // Try to find by ID first
      final product = _accessoriesList.firstWhere(
        (p) => p['id'] == productId,
        orElse: () => <String, dynamic>{},
      );

      if (product.isNotEmpty) {
        setState(() {
          _selectedProduct = product;
        });
        _onPriceOrQuantityChanged();
        return;
      }
    }

    if (productName != null) {
      // Fallback to name search
      final product = _accessoriesList.firstWhere(
        (p) => p['accessoryName'] == productName,
        orElse: () => <String, dynamic>{},
      );

      if (product.isNotEmpty) {
        setState(() {
          _selectedProduct = product;
        });
        _onPriceOrQuantityChanged();
      }
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

  // ============ ADD NEW PRODUCT TO ACCESSORIES COLLECTION ============
  Future<void> _addNewProduct() async {
    if (_newProductNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter accessory name')),
      );
      return;
    }

    if (_newProductPriceController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter sales price')));
      return;
    }

    try {
      setState(() => _isAddingProduct = true);

      final price = double.parse(_newProductPriceController.text);
      final now = DateTime.now();

      final productData = {
        'accessoryName': _newProductNameController.text.trim(),
        'salesPrice': price,
        'stockQuantity': 0,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'shop': _selectedShop,
      };

      // Add to accessories collection
      final docRef = await _firestore
          .collection('accessories')
          .add(productData);

      // Auto-select the newly added product
      setState(() {
        _selectedProduct = {
          'id': docRef.id,
          'accessoryName': _newProductNameController.text.trim(),
          'salesPrice': price,
          'stockQuantity': 0,
        };

        // Add to local list and select it
        _accessoriesList.add({
          'id': docRef.id,
          'accessoryName': _newProductNameController.text.trim(),
          'salesPrice': price,
          'stockQuantity': 0,
        });

        // Sort the list alphabetically by accessoryName
        _accessoriesList.sort(
          (a, b) => a['accessoryName'].compareTo(b['accessoryName']),
        );
      });

      // Trigger price calculation
      _onPriceOrQuantityChanged();

      // Clear new product form
      _newProductNameController.clear();
      _newProductPriceController.clear();

      // Close the dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Accessory added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding accessory: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isAddingProduct = false);
    }
  }

  // ============ SHOW ADD PRODUCT DIALOG ============
  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Accessory'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _newProductNameController,
                  decoration: const InputDecoration(
                    labelText: 'Accessory Name *',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newProductPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Sales Price (Inc. GST) *',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _newProductNameController.clear();
                _newProductPriceController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isAddingProduct ? null : _addNewProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
              ),
              child: _isAddingProduct
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Accessory'),
            ),
          ],
        );
      },
    );
  }

  // ============ BILL NUMBER GENERATION ============
  Future<void> _generateNextBillNumber() async {
    try {
      setState(() {
        isLoading = true;
      });

      final QuerySnapshot snapshot = await _firestore
          .collection('bills')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      String nextBillNo = '001';

      if (snapshot.docs.isNotEmpty) {
        final Map<String, dynamic> billData =
            snapshot.docs.first.data() as Map<String, dynamic>;
        final String lastBillNo = billData['billNumber'] as String? ?? '';

        final RegExp regex = RegExp(r'MH-(\d+)');
        final Match? match = regex.firstMatch(lastBillNo);

        if (match != null) {
          int lastNumber = int.tryParse(match.group(1) ?? '0') ?? 0;
          int nextNumber = lastNumber + 1;
          nextBillNo = nextNumber.toString().padLeft(3, '0');
        }
      }

      if (mounted) {
        setState(() {
          _billNumberController.text = nextBillNo;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error generating bill number: $e');
      if (mounted) {
        setState(() {
          _billNumberController.text = '001';
          isLoading = false;
        });
      }
    }
  }

  // ============ GST CALCULATION - Price with GST ============
  void _onPriceOrQuantityChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _calculateGST();
      }
    });
  }

  void _calculateGST() {
    if (_selectedProduct == null) return;

    final priceWithGst =
        _selectedProduct!['salesPrice'] as double; // Using salesPrice
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final discount = double.tryParse(_discountController.text) ?? 0.0;

    double totalWithGst = priceWithGst * quantity;

    if (discount > 0) {
      totalWithGst = totalWithGst - (totalWithGst * discount / 100);
    }

    final taxableAmount = totalWithGst / (1 + gstRate / 100);
    final gstAmount = totalWithGst - taxableAmount;

    setState(() {
      _totalAmountController.text = totalWithGst.toStringAsFixed(2);
      _taxableAmountController.text = taxableAmount.toStringAsFixed(2);
      _gstAmountController.text = gstAmount.toStringAsFixed(2);
    });
  }

  // ============ UPDATE STOCK AFTER SALE ============
  Future<void> _updateAccessoryStock() async {
    if (_originalStockData == null) return;

    try {
      final stockId = _originalStockData!['stockId'];
      final productId = _originalStockData!['productId'];
      final quantity = int.tryParse(_quantityController.text) ?? 1;
      final currentQuantity = _originalStockData!['currentQuantity'] ?? 0;
      final minStockLevel = _originalStockData!['minStockLevel'] ?? 5;

      final newQuantity = currentQuantity - quantity;

      // Update accessoryStock collection
      final updateData = {
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newQuantity == 0) {
        updateData['status'] = 'sold_out';
        updateData['soldOutAt'] = FieldValue.serverTimestamp();
      } else if (newQuantity < minStockLevel) {
        updateData['status'] = 'low_stock';
      } else {
        updateData['status'] = 'available';
      }

      await _firestore
          .collection('accessoryStock')
          .doc(stockId)
          .update(updateData);

      // Also update the master accessories collection stock quantity
      final accessoryDoc = await _firestore
          .collection('accessories')
          .doc(productId)
          .get();

      if (accessoryDoc.exists) {
        final currentMasterStock = accessoryDoc.data()?['stockQuantity'] ?? 0;
        await _firestore.collection('accessories').doc(productId).update({
          'stockQuantity': (currentMasterStock as int) - quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Add to stock movement log
      await _firestore.collection('accessoryMovements').add({
        'productId': productId,
        'productName': _selectedProduct?['accessoryName'],
        'productCategory': _originalStockData!['productCategory'],
        'movementType': 'sale',
        'quantity': quantity,
        'previousQuantity': currentQuantity,
        'newQuantity': newQuantity,
        'shopId': _originalStockData!['shopId'],
        'shopName': _originalStockData!['shopName'],
        'performedBy':
            Provider.of<AuthProvider>(context, listen: false).user?.email ??
            'Unknown',
        'performedById':
            Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'billNumber': 'MH-${_billNumberController.text}',
        'notes': 'Sale via GST bill',
      });
    } catch (e) {
      print('Error updating accessory stock: $e');
      rethrow;
    }
  }

  // ============ SAVE BILL AND GENERATE PDF ============
  Future<void> _saveAndPrintBill() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    // Validate product selection
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a product')));
      return;
    }

    if (_billNumberController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter bill number')));
      return;
    }

    // Validate stock if coming from stock screen
    if (_originalStockData != null) {
      final quantity = int.tryParse(_quantityController.text) ?? 1;
      final currentQuantity = _originalStockData!['currentQuantity'] ?? 0;

      if (quantity > currentQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient stock! Available: $currentQuantity'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    try {
      setState(() => _isGeneratingBill = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      // Prepare product data
      final priceWithGst = _selectedProduct!['salesPrice'] as double;
      final quantity = int.tryParse(_quantityController.text) ?? 1;
      final discount = double.tryParse(_discountController.text) ?? 0.0;

      double totalWithGst = priceWithGst * quantity;
      if (discount > 0) {
        totalWithGst = totalWithGst - (totalWithGst * discount / 100);
      }

      final taxableAmount = totalWithGst / (1 + gstRate / 100);
      final gstAmount = totalWithGst - taxableAmount;

      final product = {
        'productName': _selectedProduct!['accessoryName'],
        'productId': _selectedProduct!['id'],
        'quantity': quantity,
        'price': priceWithGst,
        'discount': discount,
        'taxableAmount': taxableAmount,
        'gstAmount': gstAmount,
        'totalAmount': totalWithGst,
        'hsnCode': _selectedProduct!['hsnCode'] ?? '',
      };

      final now = DateTime.now();

      // Prepare bill data
      final billData = {
        'billNumber': 'MH-${_billNumberController.text}',
        'billDate': Timestamp.fromDate(now),
        'createdAt': FieldValue.serverTimestamp(),
        'customerName': _customerNameController.text,
        'customerMobile': _customerPhoneController.text,
        'customerAddress': _customerAddressController.text,
        'product': product,
        'totalAmount': totalWithGst,
        'taxableAmount': taxableAmount,
        'gstAmount': gstAmount,
        'gstRate': gstRate,
        'shop': _selectedShop,
        'shopId': user?.shopId,
        'shopName': user?.shopName ?? user?.shopId,
        'createdBy': user?.email,
        'createdById': user?.uid,
        'createdByName': user?.name ?? 'User',
        'sealApplied': _sealChecked,
        'billType': 'GST Accessories',
        'purchaseMode': _purchaseMode,
        'originalStockId': _originalStockData?['stockId'],
        'originalProductId': _originalStockData?['productId'],
      };

      // Save to Firestore
      final docRef = await _firestore.collection('bills').add(billData);

      await _firestore.collection('gst_accessories_sales').add({
        ...billData,
        'billId': docRef.id,
        'timestamp': FieldValue.serverTimestamp(),
        'saleDate': now.toIso8601String(),
      });

      // Update accessory stock if this came from stock screen
      if (_originalStockData != null) {
        await _updateAccessoryStock();
      } else {
        // If not from stock screen, just update the master stock
        final currentStock = _selectedProduct!['stockQuantity'] as int;
        final newStock = currentStock - quantity;

        await _firestore
            .collection('accessories')
            .doc(_selectedProduct!['id'])
            .update({
              'stockQuantity': newStock < 0 ? 0 : newStock,
              'updatedAt': Timestamp.fromDate(now),
            });
      }

      // Generate PDF
      final pdfBytes = await _generatePdf(
        product,
        totalWithGst,
        taxableAmount,
        gstAmount,
        now,
      );
      final filePath = await _savePdfToStorage(pdfBytes);
      final pdfFile = File(filePath);

      setState(() {
        _savedPdfFile = pdfFile;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        await _sharePdf(pdfFile);
        _clearForm();
        await _generateNextBillNumber();

        // Refresh accessories list to get updated stock
        await _loadAccessories();

        // Return true to indicate success to the calling screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingBill = false);
      }
    }
  }

  // ============ PDF GENERATION ============
  Future<String> _savePdfToStorage(Uint8List pdfBytes) async {
    try {
      Directory directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final mobileHouseDir = Directory('${directory.path}/MobileHouse');
      if (!await mobileHouseDir.exists()) {
        await mobileHouseDir.create(recursive: true);
      }

      final fileName = 'MH_${_billNumberController.text}_GST.pdf';
      final filePath = '${mobileHouseDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(pdfBytes, flush: true);
      return filePath;
    } catch (e) {
      print('Error saving PDF: $e');
      rethrow;
    }
  }

  Future<void> _sharePdf(File pdfFile) async {
    try {
      if (!await pdfFile.exists()) {
        throw Exception('PDF file not found');
      }

      final fileName = pdfFile.path.split('/').last;

      await Share.shareXFiles(
        [XFile(pdfFile.path, mimeType: 'application/pdf', name: fileName)],
        text: 'Mobile House Bill - ${_customerNameController.text}',
        subject: 'Mobile House Bill - MH-${_billNumberController.text}',
      );
    } catch (e) {
      print('Error sharing PDF: $e');
    }
  }

  Future<void> _shareSavedPdf() async {
    if (_savedPdfFile == null || !await _savedPdfFile!.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No PDF file found. Please create a bill first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    await _sharePdf(_savedPdfFile!);
  }

  // ============ AMOUNT TO WORDS CONVERSION ============
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

  // ============ PDF DESIGN ============
  Future<Uint8List> _generatePdf(
    Map<String, dynamic> product,
    double totalAmount,
    double taxableAmount,
    double gstAmount,
    DateTime billDate,
  ) async {
    final pdf = pw.Document();
    final pageFormat = PdfPageFormat.a4;
    final currentDate = DateFormat('dd MMMM yyyy').format(billDate);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(15),
        build: (pw.Context context) {
          return _buildInvoiceContent(
            currentDate,
            pageFormat,
            product,
            totalAmount,
            taxableAmount,
            gstAmount,
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildInvoiceContent(
    String currentDate,
    PdfPageFormat pageFormat,
    Map<String, dynamic> product,
    double totalAmount,
    double taxableAmount,
    double gstAmount,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader(currentDate),
          _buildCustomerDetails(),
          pw.SizedBox(height: 4),
          _buildMainTable(product),
          pw.Container(
            height: 330,
            child: pw.Stack(
              children: [
                if (_sealImage != null && _sealChecked)
                  pw.Positioned(
                    right: 15,
                    bottom: 18,
                    child: pw.Transform.rotate(
                      angle: 25 * 3.14159 / 180,
                      child: pw.SizedBox(
                        width: 150,
                        height: 150,
                        child: pw.Image(
                          pw.MemoryImage(_sealImage!),
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildTotalSection(product, totalAmount, taxableAmount, gstAmount),
          _buildBottomSection(totalAmount, gstAmount),
        ],
      ),
    );
  }

  pw.Widget _buildHeader(String currentDate) {
    return pw.Column(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              'GSTIN: 32BSGPJ3340H1Z4',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
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
                    _selectedShop == 'Peringottukara'
                        ? '3way junction Peringottukara'
                        : 'Cherpu, Thayamkulangara',
                    style: pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _selectedShop == 'Peringottukara'
                        ? 'Mob: 9072430483, 8304830868'
                        : 'Mob: 9544466724',
                    style: pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('Mobile house', style: pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'GST TAX INVOICE (TYPE-B2C) - CASH SALE',
                    style: pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                    'Invoice No. : MH-${_billNumberController.text}',
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

  pw.Widget _buildCustomerDetails() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: pw.Container(
        padding: const pw.EdgeInsets.all(2),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Customer  : ${_customerNameController.text}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Address     :', style: pw.TextStyle(fontSize: 11)),
                pw.SizedBox(width: 4),
                pw.Expanded(
                  child: pw.Text(
                    _customerAddressController.text.isNotEmpty
                        ? _customerAddressController.text
                        : '  ',
                    style: pw.TextStyle(fontSize: 11),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Mobile Tel  : ${_customerPhoneController.text}',
              style: pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildMainTable(Map<String, dynamic> product) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: pw.FixedColumnWidth(40),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FixedColumnWidth(30),
        3: pw.FixedColumnWidth(40),
        4: pw.FixedColumnWidth(50),
        5: pw.FixedColumnWidth(45),
        6: pw.FixedColumnWidth(70),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: [
            _buildTableCell('SLNO', isHeader: true, fontSize: 9),
            _buildTableCell('Product Name', isHeader: true, fontSize: 9),
            _buildTableCell('Qty', isHeader: true, fontSize: 9),
            _buildTableCell('Rate', isHeader: true, fontSize: 9),
            _buildTableCell('Disc%', isHeader: true, fontSize: 9),
            _buildTableCell('GST Amt', isHeader: true, fontSize: 9),
            _buildTableCell('Total Amount', isHeader: true, fontSize: 9),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('1', fontSize: 9),
            _buildTableCell(
              product['productName'] ?? '',
              textAlign: pw.TextAlign.left,
              fontSize: 9,
              maxLines: 2,
            ),
            _buildTableCell(
              product['quantity']?.toString() ?? '1',
              fontSize: 9,
            ),
            _buildTableCell(
              (product['price'] ?? 0.0).toStringAsFixed(0),
              fontSize: 9,
            ),
            _buildTableCell(
              product['discount'] > 0 ? '${product['discount']}%' : '-',
              fontSize: 9,
            ),
            _buildTableCell(
              (product['gstAmount'] ?? 0.0).toStringAsFixed(0),
              fontSize: 9,
            ),
            _buildTableCell(
              (product['totalAmount'] ?? 0.0).toStringAsFixed(0),
              fontSize: 9,
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTotalSection(
    Map<String, dynamic> product,
    double totalAmount,
    double taxableAmount,
    double gstAmount,
  ) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.black, thickness: 0.5, height: 0),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Qty: ${product['quantity'] ?? 1}   ',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Taxable: ${taxableAmount.toStringAsFixed(0)}    ',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'GST: ${gstAmount.toStringAsFixed(0)}   ',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Total: ${totalAmount.toStringAsFixed(0)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.Divider(color: PdfColors.black, thickness: 0.5, height: 0),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'In Words: ${_amountToWords(totalAmount.toStringAsFixed(2))}',
                style: pw.TextStyle(fontSize: 10),
                maxLines: 2,
              ),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total Amount: ${totalAmount.toStringAsFixed(0)}',
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

  pw.Widget _buildBottomSection(double totalAmount, double gstAmount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(2),
              child: _buildGstBreakdownTable(gstAmount),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            flex: 1,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Certified that the particulars given above are true and correct',
                    style: pw.TextStyle(
                      fontSize: 8,
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
                    style: pw.TextStyle(fontSize: 7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Table _buildGstBreakdownTable(double gstAmount) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: pw.FixedColumnWidth(35),
        1: pw.FixedColumnWidth(30),
        2: pw.FixedColumnWidth(30),
        3: pw.FixedColumnWidth(30),
        4: pw.FixedColumnWidth(35),
        5: pw.FixedColumnWidth(35),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          children: [
            _buildTableCell('', isHeader: true, fontSize: 8),
            _buildTableCell('0%', isHeader: true, fontSize: 8),
            _buildTableCell('5%', isHeader: true, fontSize: 8),
            _buildTableCell('12%', isHeader: true, fontSize: 8),
            _buildTableCell('18%', isHeader: true, fontSize: 8),
            _buildTableCell('28%', isHeader: true, fontSize: 8),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Taxable', fontSize: 8),
            _buildTableCell('0', fontSize: 8),
            _buildTableCell('0', fontSize: 8),
            _buildTableCell('0', fontSize: 8),
            _buildTableCell(
              (gstAmount * 100 / 18).toStringAsFixed(0),
              fontSize: 8,
            ),
            _buildTableCell('0', fontSize: 8),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('CGST', fontSize: 8),
            _buildTableCell('0', fontSize: 8),
            _buildTableCell('0', fontSize: 8),
            _buildTableCell('0', fontSize: 8),
            _buildTableCell((gstAmount / 2).toStringAsFixed(0), fontSize: 8),
            _buildTableCell('0', fontSize: 8),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('SGST', fontSize: 8),
            _buildTableCell('0', fontSize: 8),
            _buildTableCell('0', fontSize: 8),
            _buildTableCell('0', fontSize: 8),
            _buildTableCell((gstAmount / 2).toStringAsFixed(0), fontSize: 8),
            _buildTableCell('0', fontSize: 8),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    double fontSize = 9,
    pw.TextAlign textAlign = pw.TextAlign.center,
    int maxLines = 1,
  }) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 1, vertical: 2),
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

  // ============ FORM CLEAR ============
  void _clearForm() {
    _customerNameController.clear();
    _customerPhoneController.clear();
    _customerAddressController.clear();
    _quantityController.text = '1';
    _discountController.text = '0';
    _totalAmountController.clear();
    _taxableAmountController.clear();
    _gstAmountController.clear();
    setState(() {
      _selectedProduct = null;
      _sealChecked = false;
    });
  }

  // ============ UI BUILD ============
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'GST Accessories Sale',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box, color: Colors.white, size: 20),
            onPressed: _showAddProductDialog,
            tooltip: 'Add New Accessory',
          ),
          if (_savedPdfFile != null)
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white, size: 20),
              onPressed: _shareSavedPdf,
              tooltip: 'Share Last Bill',
            ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.green[700]))
          : _buildForm(),
      floatingActionButton: _savedPdfFile != null
          ? FloatingActionButton(
              onPressed: _shareSavedPdf,
              backgroundColor: Colors.green[700],
              child: const Icon(Icons.share, color: Colors.white, size: 20),
              tooltip: 'Share Bill',
            )
          : null,
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            _buildShopDropdown(),
            const SizedBox(height: 12),
            _buildBillNumberCard(),
            const SizedBox(height: 12),
            _buildCustomerCard(),
            const SizedBox(height: 16),
            _buildProductDetailsCard(),
            const SizedBox(height: 12),
            _buildGSTSummaryCard(),
            const SizedBox(height: 12),
            _buildSealCheckbox(),
            const SizedBox(height: 12),
            _buildActionButton(),
            const SizedBox(height: 12),
            if (_savedPdfFile != null) _buildShareButton(),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget _buildShopDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green[200]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.store, color: Colors.green[700], size: 18),
          const SizedBox(width: 8),
          const Text(
            'Shop:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedShop,
                isExpanded: true,
                style: TextStyle(fontSize: 12, color: Colors.green[800]),
                items: _shopOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (String? newValue) =>
                    setState(() => _selectedShop = newValue),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.green[700],
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillNumberCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.receipt, color: Colors.green[800], size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bill Number',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                TextFormField(
                  controller: _billNumberController,
                  decoration: const InputDecoration(
                    hintText: 'Bill No',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintStyle: TextStyle(fontSize: 13),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green[700],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'AUTO',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: Colors.green[700], size: 16),
              const SizedBox(width: 6),
              const Text(
                'Customer Details',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTextField(
            _customerNameController,
            'Customer Name *',
            Icons.person_outline,
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 10),
          _buildTextField(
            _customerPhoneController,
            'Mobile Number *',
            Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Required';
              if (value!.length != 10) return 'Enter 10-digit number';
              return null;
            },
          ),
          const SizedBox(height: 10),
          _buildTextField(
            _customerAddressController,
            'Address',
            Icons.location_on_outlined,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.shopping_cart, color: Colors.green[700], size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Product Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add New', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green[700],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Product Selection Dropdown
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green[200]!),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _isLoadingAccessories
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedProduct,
                    hint: const Text('Select Accessory *'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.inventory,
                        color: Colors.green[700],
                        size: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                    ),
                    items: _accessoriesList.map((accessory) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: accessory,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    accessory['accessoryName'],
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (accessory['stockQuantity'] != null)
                                    Text(
                                      'Stock: ${accessory['stockQuantity']}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: accessory['stockQuantity'] > 0
                                            ? Colors.green[600]
                                            : Colors.red[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '₹${accessory['salesPrice']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (Map<String, dynamic>? newValue) {
                      setState(() {
                        _selectedProduct = newValue;
                        if (newValue != null) {
                          _onPriceOrQuantityChanged();
                        } else {
                          _totalAmountController.clear();
                          _taxableAmountController.clear();
                          _gstAmountController.clear();
                        }
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a product' : null,
                  ),
          ),

          const SizedBox(height: 10),

          // Quantity and Discount Row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _quantityController,
                  'Quantity',
                  Icons.production_quantity_limits_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  _discountController,
                  'Discount % (Default 0)',
                  Icons.percent,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          // Show warning if stock is low
          if (_selectedProduct != null &&
              _selectedProduct!['stockQuantity'] != null &&
              int.tryParse(_quantityController.text) != null &&
              _selectedProduct!['stockQuantity'] <
                  int.tryParse(_quantityController.text)!)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Insufficient stock! Available: ${_selectedProduct!['stockQuantity']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Show original stock info if from stock screen
          if (_originalStockData != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stock available: ${_originalStockData!['currentQuantity']} units',
                        style: TextStyle(fontSize: 11, color: Colors.blue[800]),
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

  Widget _buildGSTSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          // Purchase Mode - Fixed
          Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.green[700], size: 16),
              const SizedBox(width: 8),
              const Text(
                'Purchase Mode:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _purchaseMode,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // GST Rate - Fixed 18%
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[700],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'GST 18%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Inclusive in price',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Calculation Summary
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Taxable Amount:',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '₹${_taxableAmountController.text.isEmpty ? "0.00" : _taxableAmountController.text}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'GST Amount (18%):',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '₹${_gstAmountController.text.isEmpty ? "0.00" : _gstAmountController.text}',
                      style: TextStyle(fontSize: 12, color: Colors.green[700]),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${_totalAmountController.text.isEmpty ? "0.00" : _totalAmountController.text}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSealCheckbox() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _sealChecked,
            onChanged: (value) => setState(() => _sealChecked = value ?? false),
            activeColor: Colors.green[700],
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Apply Seal on Bill',
              style: TextStyle(fontSize: 12, color: Colors.amber[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool readOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 12),
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.green[700], size: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.green[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.green[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.green[700]!),
        ),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[50] : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        isDense: true,
      ),
    );
  }

  Widget _buildActionButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isGeneratingBill ? null : _saveAndPrintBill,
          icon: _isGeneratingBill
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save, size: 18),
          label: Text(
            _isGeneratingBill ? 'Processing...' : 'Generate Bill & Print',
            style: const TextStyle(fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _shareSavedPdf,
          icon: const Icon(Icons.share, size: 18),
          label: const Text('Share Bill Again', style: TextStyle(fontSize: 14)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _billNumberController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _quantityController.dispose();
    _discountController.dispose();
    _totalAmountController.dispose();
    _taxableAmountController.dispose();
    _gstAmountController.dispose();
    _newProductNameController.dispose();
    _newProductPriceController.dispose();
    super.dispose();
  }
}
