import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  String _searchQuery = '';
  String _filterType = 'all';
  double _minPrice = 0;
  double _maxPrice = double.infinity;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('products')
          .orderBy('productName')
          .get();

      _products = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'productType': data['productType'] ?? 'N/A',
          'brand': data['brand'] ?? 'N/A',
          'productName': data['productName'] ?? 'Unknown',
          'hsn': data['hsn'] ?? 'N/A',
          'purchaseRate': (data['purchaseRate'] ?? 0).toDouble(),
          'saleRate': (data['saleRate'] ?? 0).toDouble(),
          'gstPercentage': data['gstPercentage'] ?? 0,
          'createdAt': data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
        };
      }).toList();
    } catch (e) {
      print('Error loading products: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    var filtered = _products;

    if (_filterType != 'all') {
      filtered = filtered.where((product) {
        return product['productType'].toString().toLowerCase().contains(
          _filterType.toLowerCase(),
        );
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        return product['productName'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            product['brand'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            product['productType'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            product['hsn'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
      }).toList();
    }

    filtered = filtered.where((product) {
      double saleRate = product['saleRate'] ?? 0;
      return saleRate >= _minPrice && saleRate <= _maxPrice;
    }).toList();

    return filtered;
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.inventory_2,
                color: Colors.green[700],
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                product['productName'],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Type',
                product['productType'],
                Icons.category,
                Colors.green[700]!,
              ),
              _buildDetailRow(
                'Brand',
                product['brand'],
                Icons.branding_watermark,
                Colors.green[700]!,
              ),
              _buildDetailRow(
                'HSN',
                product['hsn'],
                Icons.code,
                Colors.green[700]!,
              ),
              _buildDetailRow(
                'GST',
                '${product['gstPercentage'].toStringAsFixed(0)}%',
                Icons.percent,
                Colors.green[700]!,
              ),
              const Divider(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Purchase',
                      '₹${product['purchaseRate'].toStringAsFixed(2)}',
                      Icons.arrow_downward,
                      Colors.orange[700]!,
                    ),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      'Sale',
                      '₹${product['saleRate'].toStringAsFixed(2)}',
                      Icons.arrow_upward,
                      Colors.green[700]!,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                'Added',
                DateFormat('dd MMM yyyy').format(product['createdAt']),
                Icons.calendar_today,
                Colors.grey[600]!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontSize: 13)),
          ),
          IconButton(
            onPressed: () {
              Navigator.pop(context);
              _editProduct(product);
            },
            icon: Icon(Icons.edit, size: 20, color: Colors.green[700]),
          ),
          IconButton(
            onPressed: () => _deleteProduct(product['id']),
            icon: Icon(Icons.delete, size: 20, color: Colors.red[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color iconColor, {
    bool isHighlighted = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  void _editProduct(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductScreen(
          product: product,
          onProductUpdated: _loadProducts,
        ),
      ),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete', style: TextStyle(fontSize: 15)),
        content: const Text('Are you sure?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestore.collection('products').doc(productId).delete();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product deleted')),
                );
                await _loadProducts();
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter', style: TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Min',
                      labelStyle: TextStyle(fontSize: 13),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13),
                    onChanged: (value) {
                      _minPrice = double.tryParse(value) ?? 0;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Max',
                      labelStyle: TextStyle(fontSize: 13),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13),
                    onChanged: (value) {
                      _maxPrice = double.tryParse(value) ?? double.infinity;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _minPrice = 0;
                _maxPrice = double.infinity;
              });
              Navigator.pop(context);
            },
            child: const Text('Reset', style: TextStyle(fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Apply', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.green[600],
                        size: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 8,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color: Colors.green[600],
                      size: 20,
                    ),
                    onPressed: _showFilterDialog,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeChip('All', 'all'),
                  const SizedBox(width: 6),
                  _buildTypeChip('Phone', 'phone'),
                  const SizedBox(width: 6),
                  _buildTypeChip('TV', 'tv'),
                  const SizedBox(width: 6),
                  _buildTypeChip('Appliances', 'appliances'),
                  const SizedBox(width: 6),
                  _buildTypeChip('Accessories', 'accessories'),
                  const SizedBox(width: 8),
                  Text(
                    '${_filteredProducts.length}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Products List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory,
                          size: 50,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No matches'
                              : 'No products',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadProducts,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Colors.grey[200]!,
                              width: 0.5,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _showProductDetails(product),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  // Icon
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      _getProductIcon(product['productType']),
                                      size: 16,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['productName'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${product['brand']} • HSN: ${product['hsn']}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Prices with labels
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Sale: ',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '₹${product['saleRate'].toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Purchase: ',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.orange[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '₹${product['purchaseRate'].toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(width: 10),

                                  // Action Buttons - Only Icons
                                  Column(
                                    children: [
                                      InkWell(
                                        onTap: () => _editProduct(product),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.green[50],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.edit,
                                            size: 16,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () =>
                                            _deleteProduct(product['id']),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red[50],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.delete,
                                            size: 16,
                                            color: Colors.red[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String value) {
    bool isSelected = _filterType == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isSelected ? Colors.white : Colors.grey[700],
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = selected ? value : 'all';
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.green[700],
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  IconData _getProductIcon(String productType) {
    switch (productType.toLowerCase()) {
      case 'phone':
        return Icons.phone_android;
      case 'tv':
        return Icons.tv;
      case 'appliances':
        return Icons.kitchen;
      case 'accessories':
        return Icons.headphones;
      default:
        return Icons.inventory;
    }
  }
}

// Edit Product Screen
class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onProductUpdated;

  const EditProductScreen({
    super.key,
    required this.product,
    required this.onProductUpdated,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _hsnController = TextEditingController();
  final TextEditingController _purchaseRateController = TextEditingController();
  final TextEditingController _saleRateController = TextEditingController();

  String? _selectedProductType;
  int _gstPercentage = 18;
  bool _isLoading = false;
  bool _submitted = false;

  List<String> _productTypes = ['Phone', 'TV', 'Appliances', 'Accessories'];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _selectedProductType = widget.product['productType'];
    _brandController.text = widget.product['brand'];
    _productNameController.text = widget.product['productName'];
    _hsnController.text = widget.product['hsn'];
    _purchaseRateController.text = widget.product['purchaseRate'].toString();
    _saleRateController.text = widget.product['saleRate'].toString();
    _gstPercentage = widget.product['gstPercentage'] ?? 18;
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
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onProductTypeChanged(String? value) {
    setState(() => _selectedProductType = value);
  }

  Future<void> _updateProduct() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _firestore.collection('products').doc(widget.product['id']).update({
        'productType': _selectedProductType,
        'brand': _brandController.text.trim(),
        'productName': _productNameController.text.trim(),
        'hsn': _hsnController.text.trim(),
        'purchaseRate': double.parse(_purchaseRateController.text),
        'saleRate': double.parse(_saleRateController.text),
        'gstPercentage': _gstPercentage,
        'updatedAt': DateTime.now(),
      });

      _showSnackBar('Product updated!');
      widget.onProductUpdated();
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product', style: TextStyle(fontSize: 15)),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration(
                      'Product Type',
                      Icons.category,
                    ),
                    value: _selectedProductType,
                    items: _productTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: _onProductTypeChanged,
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _brandController,
                    decoration: _inputDecoration(
                      'Brand',
                      Icons.branding_watermark,
                    ),
                    style: const TextStyle(fontSize: 13),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _productNameController,
                    decoration: _inputDecoration(
                      'Product Name',
                      Icons.production_quantity_limits,
                    ),
                    style: const TextStyle(fontSize: 13),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _hsnController,
                    decoration: _inputDecoration(
                      'HSN Code',
                      Icons.code,
                      helper: '8 digits',
                    ),
                    style: const TextStyle(fontSize: 13),
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
                      if (value == null || value.trim().isEmpty)
                        return 'Required';
                      if (value.trim().length != 8) return '8 digits required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _purchaseRateController,
                          decoration: _inputDecoration(
                            'Purchase Rate',
                            Icons.currency_rupee,
                            helper: 'Cost',
                          ),
                          style: const TextStyle(fontSize: 13),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Required';
                            if (double.tryParse(value) == null)
                              return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _saleRateController,
                          decoration: _inputDecoration(
                            'Sale Rate',
                            Icons.currency_rupee,
                            helper: 'Sell',
                          ),
                          style: const TextStyle(fontSize: 13),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Required';
                            if (double.tryParse(value) == null)
                              return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    decoration: _inputDecoration('GST', Icons.percent),
                    value: _gstPercentage,
                    items: [5, 12, 18, 28].map((percent) {
                      return DropdownMenuItem(
                        value: percent,
                        child: Text(
                          '$percent%',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _gstPercentage = value!),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _updateProduct,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Update',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      helperText: helper,
      helperStyle: const TextStyle(fontSize: 11),
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
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      isDense: true,
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
