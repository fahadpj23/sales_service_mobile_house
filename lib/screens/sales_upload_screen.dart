import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SalesUploadScreen extends StatefulWidget {
  const SalesUploadScreen({super.key});

  @override
  State<SalesUploadScreen> createState() => _SalesUploadScreenState();
}

class _SalesUploadScreenState extends State<SalesUploadScreen> {
  final TextEditingController _saleAmountController = TextEditingController();
  final TextEditingController _serviceAmountController =
      TextEditingController();
  bool _isLoading = false;
  DateTime _saleDate = DateTime.now();
  String? _shopId;
  String? _shopName;

  // Phone sales controllers
  final Map<String, TextEditingController> _phoneQuantityControllers = {};
  final Map<String, TextEditingController> _phoneValueControllers = {};

  final List<String> _phoneBrands = [
    'vivo',
    'oppo',
    'redmi',
    'realme',
    'samsung',
    'iqoo',
    'moto',
    'itel',
    'nokia',
    'infinix',
    'iphone',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Color scheme
  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _secondaryColor = const Color(0xFF64748B);
  final Color _accentColor = const Color(0xFF10B981);
  final Color _backgroundColor = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _getUserShopId();
    _initializePhoneControllers();
  }

  void _initializePhoneControllers() {
    for (var brand in _phoneBrands) {
      _phoneQuantityControllers[brand] = TextEditingController();
      _phoneValueControllers[brand] = TextEditingController();

      // Add listeners to update UI when text changes
      _phoneQuantityControllers[brand]!.addListener(_updatePhoneStats);
      _phoneValueControllers[brand]!.addListener(_updatePhoneStats);
    }
  }

  void _updatePhoneStats() {
    // This forces the widget to rebuild when phone data changes
    if (mounted) {
      setState(() {});
    }
  }

  void _getUserShopId() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          setState(() {
            _shopId = userData['shopId'];
            _shopName = userData['shopName'];
          });
        }
      }
    } catch (e) {
      print('Error getting shop ID: $e');
    }
  }

  void _uploadSalesData() async {
    if (_saleAmountController.text.isEmpty) {
      _showMessage('Please enter sale amount');
      return;
    }

    final saleAmount = double.tryParse(_saleAmountController.text);
    final serviceAmount = double.tryParse(_serviceAmountController.text) ?? 0.0;

    if (saleAmount == null) {
      _showMessage('Please enter valid sale amount');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        _showMessage('User not authenticated');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (_shopId == null) {
        _showMessage(
          'Shop information not found. Please check your profile setup.',
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Prepare phone sales data
      Map<String, dynamic> phoneSales = {};
      double totalPhoneSalesValue = 0.0;
      int totalPhonesSold = 0;

      for (var brand in _phoneBrands) {
        final qtyText = _phoneQuantityControllers[brand]!.text;
        final valueText = _phoneValueControllers[brand]!.text;

        if (qtyText.isNotEmpty || valueText.isNotEmpty) {
          final quantity = int.tryParse(qtyText) ?? 0;
          final value = double.tryParse(valueText) ?? 0.0;

          phoneSales[brand] = {'quantity': quantity, 'totalValue': value};

          totalPhonesSold += quantity;
          totalPhoneSalesValue += value;
        }
      }

      final salesData = {
        'userId': user.uid,
        'userEmail': user.email,
        'shopId': _shopId,
        'shopName': _shopName,
        'saleDate': _saleDate,
        'saleAmount': saleAmount,
        'serviceAmount': serviceAmount,
        'totalAmount': saleAmount + serviceAmount,
        'phoneSales': phoneSales,
        'totalPhonesSold': totalPhonesSold,
        'totalPhoneSalesValue': totalPhoneSalesValue,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('sales').add(salesData);

      _showMessage('Sales data uploaded successfully!', isError: false);
      _clearForm();
    } catch (e) {
      _showMessage('Failed to upload sales data₹: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : _accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _clearForm() {
    _saleAmountController.clear();
    _serviceAmountController.clear();

    for (var brand in _phoneBrands) {
      _phoneQuantityControllers[brand]!.clear();
      _phoneValueControllers[brand]!.clear();
    }

    setState(() {
      _saleDate = DateTime.now();
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _saleDate) {
      setState(() {
        _saleDate = picked;
      });
    }
  }

  Widget _buildPhoneSalesSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_iphone,
                    color: _primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Phone Sales by Brand',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const Spacer(),
                _buildPhoneStats(),
              ],
            ),
            const SizedBox(height: 12),

            // Compact table
            Container(
              height: 320, // Increased height to accommodate larger fields
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'BRAND',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'QTY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'VALUE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Scrollable brands list
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _phoneBrands.length,
                      itemBuilder: (context, index) {
                        final brand = _phoneBrands[index];
                        return _buildCompactPhoneRow(brand);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStats() {
    int totalQty = 0;
    double totalValue = 0.0;

    for (var brand in _phoneBrands) {
      final qty = int.tryParse(_phoneQuantityControllers[brand]!.text) ?? 0;
      final value = double.tryParse(_phoneValueControllers[brand]!.text) ?? 0.0;
      totalQty += qty;
      totalValue += value;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _secondaryColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2, size: 12, color: _primaryColor),
                  const SizedBox(width: 2),
                  Text(
                    totalQty.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
              Text(
                'Phones',
                style: TextStyle(fontSize: 9, color: _secondaryColor),
              ),
            ],
          ),
          const SizedBox(width: 6),
          Container(
            width: 1,
            height: 20,
            color: _secondaryColor.withOpacity(0.2),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(Icons.attach_money, size: 12, color: _accentColor),
                  const SizedBox(width: 2),
                  Text(
                    '${totalValue.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                    ),
                  ),
                ],
              ),
              Text(
                'Value',
                style: TextStyle(fontSize: 9, color: _secondaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPhoneRow(String brand) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: _secondaryColor.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Brand name with colored icon
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _getBrandColor(brand).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.phone_android,
                    size: 14,
                    color: _getBrandColor(brand),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getBrandDisplayName(brand),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _secondaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Quantity field
          Expanded(
            child: Container(
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _phoneQuantityControllers[brand],
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: _secondaryColor.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: _primaryColor, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),

          // Value field
          Expanded(
            child: Container(
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _phoneValueControllers[brand],
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: _secondaryColor.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: _primaryColor, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBrandColor(String brand) {
    final colors = {
      'iphone': const Color(0xFFA2AAAD),
      'samsung': const Color(0xFF1428A0),
      'vivo': const Color(0xFF415FFF),
      'oppo': const Color(0xFF46C1BE),
      'redmi': const Color(0xFFFF6900),
      'realme': const Color(0xFFFFC915),
      'iqoo': const Color(0xFF5600FF),
      'moto': const Color(0xFFE10032),
      'nokia': const Color(0xFF124191),
      'infinix': const Color(0xFF000000),
      'itel': const Color(0xFFFF0000),
    };
    return colors[brand] ?? _primaryColor;
  }

  String _getBrandDisplayName(String brand) {
    final names = {
      'iphone': 'iPhone',
      'samsung': 'Samsung',
      'vivo': 'Vivo',
      'oppo': 'Oppo',
      'redmi': 'Redmi',
      'realme': 'Realme',
      'iqoo': 'iQOO',
      'moto': 'Motorola',
      'nokia': 'Nokia',
      'infinix': 'Infinix',
      'itel': 'Itel',
    };
    return names[brand] ?? brand.toUpperCase();
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, Color(0xFF1D4ED8)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Daily Sales Report',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildShopInfo() {
    if (_shopId == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _secondaryColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.store, color: _secondaryColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: _isLoading
                  ? Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Loading shop...',
                          style: TextStyle(
                            fontSize: 12,
                            color: _secondaryColor,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Shop information not available',
                      style: TextStyle(fontSize: 12, color: _secondaryColor),
                    ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _accentColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.store, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Active Shop",
                  style: TextStyle(
                    fontSize: 10,
                    color: _secondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _shopName!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool isOptional = false,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _secondaryColor,
                fontSize: 13,
              ),
            ),
            if (isOptional)
              Text(
                ' (Optional)',
                style: TextStyle(
                  color: _secondaryColor.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: _primaryColor, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _secondaryColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _primaryColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sale Date',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _secondaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: _secondaryColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: _primaryColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_saleDate.day}/${_saleDate.month}/${_saleDate.year}',
                  style: TextStyle(fontSize: 14, color: _secondaryColor),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down, color: _primaryColor, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        gradient: (_isLoading || _shopId == null)
            ? null
            : LinearGradient(
                colors: [_primaryColor, Color(0xFF1D4ED8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        borderRadius: BorderRadius.circular(12),
        color: (_isLoading || _shopId == null)
            ? _secondaryColor.withOpacity(0.3)
            : null,
      ),
      child: ElevatedButton(
        onPressed: (_isLoading || _shopId == null) ? null : _uploadSalesData,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Uploading...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Text(
                _shopId == null
                    ? 'Waiting for Shop Info'
                    : 'Upload Sales Report',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Sales Upload'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 20),

            // Shop Info
            _buildShopInfo(),
            const SizedBox(height: 20),

            // Main Form
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDatePicker(),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'Sale Total Amount',
                      icon: Icons.attach_money,
                      controller: _saleAmountController,
                      hintText: 'Enter total sale amount',
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(
                      label: 'Service Amount',
                      icon: Icons.build,
                      controller: _serviceAmountController,
                      isOptional: true,
                      hintText: 'Enter service amount (optional)',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Phone Sales Section - Always Visible
            _buildPhoneSalesSection(),

            const SizedBox(height: 20),

            // Upload Button
            _buildUploadButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _saleAmountController.dispose();
    _serviceAmountController.dispose();

    // Remove listeners and dispose all phone sales controllers
    for (var brand in _phoneBrands) {
      _phoneQuantityControllers[brand]!.removeListener(_updatePhoneStats);
      _phoneValueControllers[brand]!.removeListener(_updatePhoneStats);
      _phoneQuantityControllers[brand]!.dispose();
      _phoneValueControllers[brand]!.dispose();
    }

    super.dispose();
  }
}
