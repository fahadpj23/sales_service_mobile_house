import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product.dart';
import 'product_list_screen.dart';

class AddProductScreen extends StatefulWidget {
  final Function(int)? onNavigateToProductList;

  const AddProductScreen({super.key, this.onNavigateToProductList});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _hsnController = TextEditingController();
  final TextEditingController _purchaseRateController = TextEditingController();
  final TextEditingController _saleRateController = TextEditingController();

  String? _selectedProductType;
  String? _selectedBrand;
  int _gstPercentage = 18;
  bool _isLoading = false;
  bool _showNewBrandField = false;
  bool _showPreview = false;
  bool _submitted = false;

  List<String> _productTypes = ['Phone', 'TV', 'Appliances', 'Accessories'];
  List<String> _brands = [];

  Map<String, dynamic>? _previewData;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, String> _defaultHsnCodes = {
    'Phone': '85171300',
    'TV': '85287219',
    'Appliances': '84181090',
    'Accessories': '85177990',
  };

  @override
  void initState() {
    super.initState();
    _loadBrands();
    _hsnController.addListener(_validateHsnLength);
  }

  void _validateHsnLength() {
    if (_hsnController.text.length > 8) {
      _hsnController.value = TextEditingValue(
        text: _hsnController.text.substring(0, 8),
        selection: TextSelection.collapsed(offset: 8),
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadBrands() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('brands').get();
      List<String> brands = snapshot.docs
          .map((doc) => doc['name'] as String)
          .toList();
      setState(() => _brands = brands);
    } catch (e) {
      _showSnackBar('Error loading brands: $e', isError: true);
    }
  }

  Future<void> _addNewBrand(String brandName) async {
    if (brandName.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('brands').add({
        'name': brandName.trim(),
        'createdAt': DateTime.now(),
      });
      await _loadBrands();
      setState(() {
        _selectedBrand = brandName.trim();
        _showNewBrandField = false;
        _isLoading = false;
      });
      _showSnackBar('Brand added successfully!');
    } catch (e) {
      _showSnackBar('Error adding brand: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _onProductTypeChanged(String? value) {
    setState(() {
      _selectedProductType = value;
      if (value == 'Phone' && _defaultHsnCodes.containsKey(value)) {
        _hsnController.text = _defaultHsnCodes[value]!;
      } else if (_hsnController.text.isEmpty) {
        _hsnController.clear();
      }
    });
  }

  void _showPreviewDialog() {
    setState(() => _submitted = true);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedBrand == null || _selectedBrand!.isEmpty) {
      _showSnackBar('Please select a brand first!', isError: true);
      return;
    }

    double purchaseRate = double.parse(_purchaseRateController.text);
    double saleRate = double.parse(_saleRateController.text);

    if (saleRate < purchaseRate) {
      _showSnackBar(
        'Sale rate cannot be less than purchase rate!',
        isError: true,
      );
      return;
    }

    setState(() {
      _previewData = {
        'productType': _selectedProductType,
        'brand': _selectedBrand,
        'productName': _productNameController.text.trim(),
        'hsn': _hsnController.text.trim(),
        'purchaseRate': purchaseRate,
        'saleRate': saleRate,
        'gstPercentage': _gstPercentage,
        'profit': saleRate - purchaseRate,
        'margin': ((saleRate - purchaseRate) / purchaseRate * 100)
            .toStringAsFixed(1),
      };
      _showPreview = true;
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.preview, color: Colors.green[700], size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Preview Product',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPreviewItem('Product Type', _previewData!['productType']),
                const SizedBox(height: 6),
                _buildPreviewItem('Brand', _previewData!['brand']),
                const SizedBox(height: 6),
                _buildPreviewItem('Product Name', _previewData!['productName']),
                const SizedBox(height: 6),
                _buildPreviewItem('HSN Code', _previewData!['hsn']),
                const SizedBox(height: 6),
                _buildPreviewItem(
                  'Purchase Rate',
                  '₹${_previewData!['purchaseRate'].toStringAsFixed(2)}',
                ),
                const SizedBox(height: 6),
                _buildPreviewItem(
                  'Sale Rate',
                  '₹${_previewData!['saleRate'].toStringAsFixed(2)}',
                ),
                const SizedBox(height: 6),
                _buildPreviewItem(
                  'GST Percentage',
                  '${_previewData!['gstPercentage']}%',
                ),
                const Divider(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[50]!, Colors.green[100]!],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      _buildPreviewItem(
                        'Profit per unit',
                        '₹${_previewData!['profit'].toStringAsFixed(2)}',
                        isBold: true,
                      ),
                      const SizedBox(height: 4),
                      _buildPreviewItem(
                        'Margin',
                        '${_previewData!['margin']}%',
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              child: const Text('EDIT', style: TextStyle(fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _saveProduct();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('CONFIRM', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewItem(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isBold ? Colors.green[700] : Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<void> _saveProduct() async {
    setState(() => _submitted = true);

    if (_selectedBrand == null || _selectedBrand!.isEmpty) {
      _showSnackBar('Please select a brand first!', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      Product product = Product(
        productType: _selectedProductType!,
        brand: _selectedBrand!,
        productName: _productNameController.text.trim(),
        hsn: _hsnController.text.trim(),
        purchaseRate: double.parse(_purchaseRateController.text),
        saleRate: double.parse(_saleRateController.text),
        gstPercentage: _gstPercentage,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('products').add(product.toMap());

      _showSnackBar('Product added successfully!');

      _productNameController.clear();
      _hsnController.clear();
      _purchaseRateController.clear();
      _saleRateController.clear();
      setState(() {
        _selectedProductType = null;
        _selectedBrand = null;
        _gstPercentage = 18;
        _submitted = false;
      });

      if (widget.onNavigateToProductList != null) {
        widget.onNavigateToProductList!(6);
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar('Error saving product: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 14),

              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _buildSectionHeader(
                        Icons.category,
                        'Product Information',
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        decoration: _buildInputDecoration(
                          'Product Type *',
                          Icons.category,
                        ),
                        value: _selectedProductType,
                        items: _productTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        }).toList(),
                        onChanged: _onProductTypeChanged,
                        validator: (value) =>
                            value == null ? 'Please select product type' : null,
                      ),
                      const SizedBox(height: 12),

                      _buildBrandSection(),
                      const SizedBox(height: 12),

                      _buildSectionHeader(Icons.description, 'Product Details'),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _productNameController,
                        decoration: _buildInputDecoration(
                          'Product Name *',
                          Icons.production_quantity_limits,
                        ),
                        style: const TextStyle(fontSize: 12),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Please enter product name'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _hsnController,
                        decoration: _buildInputDecoration(
                          'HSN Code *',
                          Icons.code,
                          helperText: '8-digit HSN code',
                        ),
                        style: const TextStyle(fontSize: 12),
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        buildCounter:
                            (
                              BuildContext context, {
                              required int currentLength,
                              required bool isFocused,
                              required int? maxLength,
                            }) {
                              return null;
                            },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter HSN code';
                          }
                          if (value.trim().length != 8) {
                            return 'HSN code must be 8 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _purchaseRateController,
                              decoration: _buildInputDecoration(
                                'Purchase Rate *',
                                Icons.currency_rupee,
                                helperText: 'Cost price',
                              ),
                              style: const TextStyle(fontSize: 12),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Invalid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _saleRateController,
                              decoration: _buildInputDecoration(
                                'Sale Rate *',
                                Icons.currency_rupee,
                                helperText: 'Selling price',
                              ),
                              style: const TextStyle(fontSize: 12),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Invalid number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      if (_purchaseRateController.text.isNotEmpty &&
                          _saleRateController.text.isNotEmpty &&
                          double.tryParse(_purchaseRateController.text) !=
                              null &&
                          double.tryParse(_saleRateController.text) != null)
                        _buildProfitPreview(),

                      const SizedBox(height: 12),

                      DropdownButtonFormField<int>(
                        decoration: _buildInputDecoration(
                          'GST Percentage *',
                          Icons.percent,
                        ),
                        value: _gstPercentage,
                        items: [5, 12, 18, 28].map((percent) {
                          return DropdownMenuItem(
                            value: percent,
                            child: Text(
                              '$percent%',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _gstPercentage = value!),
                      ),

                      const SizedBox(height: 18),

                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green[400]!, Colors.green[700]!],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.add_shopping_cart,
            color: Colors.white,
            size: 15,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add New Product',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              Text(
                'Fill in the product details below',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrandSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_showNewBrandField) ...[
          Container(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.branding_watermark,
                  size: 14,
                  color: Colors.green[600],
                ),
                const SizedBox(width: 4),
                const Text(
                  'Brand',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const Text(
                  ' *',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _submitted && _selectedBrand == null
                    ? Colors.red
                    : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedBrand,
                hint: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Text(
                    'Select or add brand',
                    style: TextStyle(
                      fontSize: 11,
                      color: _submitted && _selectedBrand == null
                          ? Colors.red
                          : Colors.grey[500],
                    ),
                  ),
                ),
                items: [
                  ..._brands.map((brand) {
                    return DropdownMenuItem(
                      value: brand,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          brand,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    );
                  }),
                  DropdownMenuItem(
                    value: '__add_new__',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle,
                            color: Colors.green[600],
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Add New Brand',
                            style: TextStyle(
                              color: Colors.green[600],
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == '__add_new__') {
                    setState(() {
                      _showNewBrandField = true;
                      _brandController.clear();
                    });
                  } else {
                    setState(() => _selectedBrand = value);
                  }
                },
              ),
            ),
          ),
          if (_submitted && _selectedBrand == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Please select or add a brand',
                style: TextStyle(fontSize: 10, color: Colors.red[400]),
              ),
            ),
          if (_selectedBrand != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Selected: $_selectedBrand',
                    style: TextStyle(fontSize: 10, color: Colors.green[700]),
                  ),
                ],
              ),
            ),
        ],
        if (_showNewBrandField) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _brandController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Enter brand name',
                      hintStyle: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.green[700]!),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_brandController.text.trim().isNotEmpty) {
                            _addNewBrand(_brandController.text);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showNewBrandField = false;
                      _brandController.clear();
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfitPreview() {
    double purchaseRate = double.parse(_purchaseRateController.text);
    double saleRate = double.parse(_saleRateController.text);
    double profit = saleRate - purchaseRate;
    double margin = (profit / purchaseRate * 100);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoChip(
            'Profit',
            '₹${profit.toStringAsFixed(2)}',
            Icons.trending_up,
          ),
          Container(width: 1, height: 25, color: Colors.green[200]),
          _buildInfoChip(
            'Margin',
            '${margin.toStringAsFixed(1)}%',
            Icons.percent,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              _showPreviewDialog();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green[700],
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: BorderSide(color: Colors.green[700]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Preview', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () {
                    _showPreviewDialog();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Product', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.green[700], size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 11),
      hintText: 'Enter $label',
      hintStyle: const TextStyle(fontSize: 11),
      helperText: helperText,
      helperStyle: const TextStyle(fontSize: 10),
      errorStyle: const TextStyle(fontSize: 10),
      prefixIcon: Icon(icon, color: Colors.green[600], size: 16),
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
        borderSide: BorderSide(color: Colors.green[700]!, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      isDense: true,
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.green[700], size: 14),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.green[800],
              ),
            ),
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _brandController.dispose();
    _productNameController.dispose();
    _hsnController.dispose();
    _purchaseRateController.dispose();
    _saleRateController.dispose();
    _hsnController.removeListener(_validateHsnLength);
    super.dispose();
  }
}
