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
  String _filterType = 'all'; // all, phone, tv, appliances, accessories
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

    // Apply type filter
    if (_filterType != 'all') {
      filtered = filtered.where((product) {
        return product['productType'].toString().toLowerCase().contains(
          _filterType.toLowerCase(),
        );
      }).toList();
    }

    // Apply search filter
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

    // Apply price filter
    filtered = filtered.where((product) {
      double saleRate = product['saleRate'] ?? 0;
      return saleRate >= _minPrice && saleRate <= _maxPrice;
    }).toList();

    return filtered;
  }

  void _showProductDetails(Map<String, dynamic> product) {
    double profit = product['saleRate'] - product['purchaseRate'];
    double margin = product['purchaseRate'] > 0
        ? (profit / product['purchaseRate'] * 100)
        : 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.inventory_2,
                color: Colors.green[700],
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                product['productName'],
                style: const TextStyle(fontSize: 16),
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
              _buildDetailRow('Type', product['productType'], Icons.category),
              _buildDetailRow(
                'Brand',
                product['brand'],
                Icons.branding_watermark,
              ),
              _buildDetailRow('HSN Code', product['hsn'], Icons.code),
              _buildDetailRow(
                'GST',
                '${product['gstPercentage'].toStringAsFixed(0)}%',
                Icons.percent,
              ),
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Purchase Rate',
                      '₹${product['purchaseRate'].toStringAsFixed(2)}',
                      Icons.arrow_downward,
                      isHighlighted: true,
                    ),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      'Sale Rate',
                      '₹${product['saleRate'].toStringAsFixed(2)}',
                      Icons.arrow_upward,
                      isHighlighted: true,
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[50]!, Colors.green[100]!],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Profit per unit',
                      '₹${profit.toStringAsFixed(2)}',
                      Icons.trending_up,
                      isTotal: true,
                    ),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      'Margin',
                      '${margin.toStringAsFixed(1)}%',
                      Icons.percent,
                      isTotal: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Added on',
                DateFormat('dd MMM yyyy, hh:mm a').format(product['createdAt']),
                Icons.calendar_today,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _editProduct(product);
            },
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _deleteProduct(product['id']),
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    bool isHighlighted = false,
    bool isTotal = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isTotal
              ? Colors.green[700]
              : isHighlighted
              ? Colors.green[600]
              : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isTotal ? Colors.black87 : Colors.grey[600],
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal
                ? Colors.green[700]
                : isHighlighted
                ? Colors.green[800]
                : Colors.black87,
          ),
        ),
      ],
    );
  }

  void _editProduct(Map<String, dynamic> product) {
    // Navigate to edit product screen (you can reuse AddProductScreen with edit mode)
    // For now, show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon!')),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text(
          'Are you sure you want to delete this product? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestore.collection('products').doc(productId).delete();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product deleted successfully')),
                );
                await _loadProducts();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting product: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Products'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Price Range
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Min Price',
                      prefixText: '₹',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _minPrice = double.tryParse(value) ?? 0;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Max Price',
                      prefixText: '₹',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
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
            child: const Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Apply'),
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
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color: Colors.green[700],
                      size: 22,
                    ),
                    onPressed: _showFilterDialog,
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                const Spacer(),
                Text(
                  '${_filteredProducts.length} products',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Products Grid/List
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
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No products match your search'
                              : 'No products found',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          Text(
                            'Try adjusting your search',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        if (_products.isEmpty)
                          TextButton.icon(
                            onPressed: () {
                              // Navigate to Add Product
                              // You can use drawer navigation
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Product'),
                          ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadProducts,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width > 600
                            ? 3
                            : 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        double profit =
                            product['saleRate'] - product['purchaseRate'];
                        bool isProfitable = profit > 0;

                        return GestureDetector(
                          onTap: () => _showProductDetails(product),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white,
                                    isProfitable
                                        ? Colors.green[50]!
                                        : Colors.red[50]!,
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Product Icon and Type
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            _getProductIcon(
                                              product['productType'],
                                            ),
                                            size: 16,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            product['productType'] ?? 'N/A',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isProfitable
                                                ? Colors.green[100]
                                                : Colors.red[100],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            isProfitable ? 'Profit' : 'Loss',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: isProfitable
                                                  ? Colors.green[700]
                                                  : Colors.red[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    // Product Name
                                    Text(
                                      product['productName'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    const SizedBox(height: 4),

                                    // Brand
                                    Text(
                                      product['brand'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    const Spacer(),

                                    // Price Section
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Sale Price',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                            Text(
                                              '₹${product['saleRate'].toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Purchase',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                            Text(
                                              '₹${product['purchaseRate'].toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 4),

                                    // HSN Code
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'HSN: ${product['hsn']}',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = selected ? value : 'all';
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.green,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
