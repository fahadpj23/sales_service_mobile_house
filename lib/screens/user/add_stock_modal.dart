// lib/screens/inventory/widgets/add_stock_modal.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class AddStockModal extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final String? selectedBrand;
  final String? selectedProduct;
  final String? newProductName;
  final double? newProductPrice;
  final int? quantity;
  final List<String> imeiNumbers;
  final List<TextEditingController> imeiControllers;
  final List<String> brands;
  final Map<String, List<Map<String, dynamic>>> productsByBrand;
  final bool isLoading;
  final bool showAddProductForm;
  final bool showPriceChangeOption;
  final double? originalProductPrice;
  final TextEditingController productSearchController;
  final TextEditingController priceChangeController;
  final TextEditingController searchController;
  final String? modalError;
  final String? modalSuccess;

  final Function(String?) onBrandChanged;
  final Function(String?) onProductSelected;
  final Function() onCancelAddNewProduct;
  final Function(String) onQuantityChanged;
  final Function(int) onOpenScannerForImeiField;
  final Function() onClearModalMessages;
  final Function() onCloseModal;
  final Function() onSaveStock;
  final Function() onSaveNewProduct;

  const AddStockModal({
    super.key,
    required this.formKey,
    required this.selectedBrand,
    required this.selectedProduct,
    required this.newProductName,
    required this.newProductPrice,
    required this.quantity,
    required this.imeiNumbers,
    required this.imeiControllers,
    required this.brands,
    required this.productsByBrand,
    required this.isLoading,
    required this.showAddProductForm,
    required this.showPriceChangeOption,
    required this.originalProductPrice,
    required this.productSearchController,
    required this.priceChangeController,
    required this.searchController,
    required this.modalError,
    required this.modalSuccess,
    required this.onBrandChanged,
    required this.onProductSelected,
    required this.onCancelAddNewProduct,
    required this.onQuantityChanged,
    required this.onOpenScannerForImeiField,
    required this.onClearModalMessages,
    required this.onCloseModal,
    required this.onSaveStock,
    required this.onSaveNewProduct,
  });

  @override
  State<AddStockModal> createState() => _AddStockModalState();
}

class _AddStockModalState extends State<AddStockModal> {
  List<Map<String, dynamic>> _filteredProducts = [];

  String _formatPrice(dynamic price) {
    try {
      if (price == null) return '₹0';
      if (price is int) {
        return '₹${NumberFormat('#,##0').format(price)}';
      }
      if (price is double) {
        return '₹${NumberFormat('#,##0').format(price)}';
      }
      if (price is String) {
        final parsed = double.tryParse(price);
        if (parsed != null) {
          return '₹${NumberFormat('#,##0').format(parsed)}';
        }
      }
      return '₹0';
    } catch (e) {
      return '₹0';
    }
  }

  // FIXED: Smart Search Logic that handles "f17 4/128" searching in "samsung galaxy f17 5g 4/128 violet pop"
  List<Map<String, dynamic>> _filterProductsBySearch(
    List<Map<String, dynamic>> products,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return products;

    final query = searchQuery.toLowerCase().trim();
    final result = <Map<String, dynamic>>[];

    for (final product in products) {
      final productName = (product['productName'] as String? ?? '')
          .toLowerCase();
      final price = product['price'];

      // Create variations for the word
      final combinedText = productName;

      // Split search query into words
      final searchWords = query.split(' ').where((w) => w.isNotEmpty).toList();

      bool allWordsFound = true;

      // Check if ALL search words are found (case-insensitive)
      for (final word in searchWords) {
        // Create variations for the word
        final variations = <String>[word];

        // Handle slash variations like "4/128"
        if (word.contains('/')) {
          variations.add(word.replaceAll('/', ' '));
          variations.add(word.replaceAll('/', ''));
          variations.add(word.replaceAll('/', 'gb/'));
          variations.add(word.replaceAll('/', '/gb'));
        }

        // Handle "g" variations like "5g"
        if (word.endsWith('g') && word.length > 1) {
          variations.add(word.substring(0, word.length - 1));
        }

        // Handle "gb" variations like "4gb"
        if (word.toLowerCase().endsWith('gb') && word.length > 2) {
          variations.add(word.toLowerCase().replaceAll('gb', ''));
        }

        // Handle "ram" variations like "8ram"
        if (word.toLowerCase().endsWith('ram') && word.length > 3) {
          final ramValue = word.toLowerCase().replaceAll('ram', '');
          variations.add(ramValue);
          variations.add('${ramValue}gb');
          variations.add('${ramValue} gb');
        }

        // Handle "gb" standalone
        if (word.toLowerCase() == 'gb') {
          variations.add('gb');
          variations.add('g');
          variations.add(' ');
        }

        // Handle "rom" variations like "128rom"
        if (word.toLowerCase().endsWith('rom') && word.length > 3) {
          final romValue = word.toLowerCase().replaceAll('rom', '');
          variations.add(romValue);
          variations.add('${romValue}gb');
          variations.add('${romValue} gb');
        }

        // Handle model numbers with spaces/dashes
        if (word.contains('-')) {
          variations.add(word.replaceAll('-', ' '));
          variations.add(word.replaceAll('-', ''));
        }

        // Handle "plus" variations
        if (word.toLowerCase().endsWith('plus')) {
          variations.add(word.toLowerCase().replaceAll('plus', '+'));
          variations.add(word.toLowerCase().replaceAll('plus', ' +'));
        }

        // Check if any variation is found in product name
        bool wordFound = false;
        for (final variation in variations) {
          if (combinedText.contains(variation)) {
            wordFound = true;
            break;
          }
        }

        if (!wordFound) {
          allWordsFound = false;
          break;
        }
      }

      if (allWordsFound) {
        result.add(product);
      }
    }

    return result;
  }

  Widget _buildProductList() {
    final brandHasNoProducts =
        !widget.productsByBrand.containsKey(widget.selectedBrand!) ||
        (widget.productsByBrand[widget.selectedBrand!] ?? []).isEmpty;

    final searchHasNoResults =
        widget.productSearchController.text.isNotEmpty &&
        _filteredProducts.isEmpty;

    final shouldShowAddNew = brandHasNoProducts || searchHasNoResults;

    return ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _filteredProducts.length + (shouldShowAddNew ? 1 : 0),
      itemBuilder: (context, index) {
        if (shouldShowAddNew && index == _filteredProducts.length) {
          return _buildAddNewProductTile();
        }

        final product = _filteredProducts[index];
        final productName = product['productName'] as String? ?? '';
        final price = product['price'];
        String priceText = '';

        if (price is double) {
          priceText = '₹${price.toStringAsFixed(0)}';
        } else if (price is int) {
          priceText = '₹$price';
        }

        return ListTile(
          title: Text(
            productName,
            style: const TextStyle(fontSize: 12, color: Colors.black),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            priceText,
            style: const TextStyle(fontSize: 10, color: Colors.green),
          ),
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          onTap: () {
            widget.onProductSelected(productName);
          },
          trailing: widget.selectedProduct == productName
              ? const Icon(Icons.check, color: Colors.green, size: 16)
              : null,
        );
      },
    );
  }

  Widget _buildAddNewProductTile() {
    String subtitleText = '';

    if (!widget.productsByBrand.containsKey(widget.selectedBrand!) ||
        (widget.productsByBrand[widget.selectedBrand!] ?? []).isEmpty) {
      subtitleText = 'No products found for this brand';
    } else if (widget.productSearchController.text.isNotEmpty &&
        _filteredProducts.isEmpty) {
      subtitleText = 'No matching products found';
    }

    return ListTile(
      leading: const Icon(Icons.add, color: Colors.green, size: 18),
      title: const Text(
        'Add New Product...',
        style: TextStyle(fontSize: 12, color: Colors.black),
      ),
      subtitle: subtitleText.isNotEmpty
          ? Text(
              subtitleText,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            )
          : null,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onTap: () {
        widget.onProductSelected('add_new');
      },
    );
  }

  Widget _buildProductSearchDropdown() {
    if (widget.selectedBrand == null) return const SizedBox();

    if (widget.showAddProductForm) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Text(
                  'Adding New Product',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'Enter product details below. Product will be saved to database.',
              style: TextStyle(fontSize: 10, color: Colors.blue),
            ),
          ],
        ),
      );
    }

    // Filter products based on search text or selected product
    final products = widget.productsByBrand[widget.selectedBrand!] ?? [];
    final searchText = widget.productSearchController.text;

    // Apply smart search filter
    if (searchText.isNotEmpty) {
      _filteredProducts = _filterProductsBySearch(products, searchText);
    } else {
      _filteredProducts = List.from(products);
    }

    // Sort filtered products alphabetically
    _filteredProducts.sort((a, b) {
      final aName = a['productName'] as String? ?? '';
      final bName = b['productName'] as String? ?? '';
      return aName.compareTo(bName);
    });

    return Column(
      children: [
        TextField(
          controller: widget.productSearchController,
          decoration: InputDecoration(
            labelText: 'Search Product',
            labelStyle: const TextStyle(fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon:
                widget.selectedProduct != null &&
                    widget.selectedProduct!.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      setState(() {
                        widget.onProductSelected(null);
                        widget.productSearchController.clear();
                      });
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            hintText: 'Search by model, specs (e.g., "f17 4/128", "5g 256gb")',
          ),
          style: const TextStyle(fontSize: 12, color: Colors.black),
          onChanged: (value) {
            setState(() {
              // If user starts typing, clear the selected product
              if (widget.selectedProduct != null &&
                  value != widget.selectedProduct) {
                widget.onProductSelected(null);
              }
              widget.onClearModalMessages();
            });
          },
          onTap: () {
            // When user taps to search, show all products
            if (widget.selectedProduct != null &&
                widget.productSearchController.text == widget.selectedProduct) {
              widget.productSearchController.clear();
              setState(() {
                widget.onClearModalMessages();
              });
            }
          },
        ),
        const SizedBox(height: 8),

        // Search Tips
        if (widget.productSearchController.text.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
          ),

        if (widget.modalSuccess != null &&
            widget.modalSuccess!.contains('Product added'))
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.modalSuccess!,
                    style: const TextStyle(fontSize: 11, color: Colors.green),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),

        // Show product dropdown only if no product is selected or user is searching
        if (widget.selectedProduct == null ||
            widget.productSearchController.text.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Results count
                if (_filteredProducts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_filteredProducts.length} product(s) found',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (widget.productSearchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                widget.productSearchController.clear();
                                widget.onClearModalMessages();
                              });
                            },
                            child: Text(
                              'Clear search',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                // Product list
                Expanded(child: _buildProductList()),
              ],
            ),
          ),

        // Show selected product info if a product is selected
        if (widget.selectedProduct != null &&
            widget.productSearchController.text.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Selected Product:',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 14),
                            onPressed: () {
                              setState(() {
                                widget.onProductSelected(null);
                                widget.productSearchController.clear();
                              });
                            },
                            tooltip: 'Change product',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.selectedProduct!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.originalProductPrice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Text(
                                'Price: ${_formatPrice(widget.originalProductPrice)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const Spacer(),
                              if (widget.showPriceChangeOption)
                                GestureDetector(
                                  onTap: () {
                                    // Focus on price change field
                                    FocusScope.of(context).nextFocus();
                                  },
                                  child: Text(
                                    'Change price',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue.shade700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildImeiInputField(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: index < widget.imeiControllers.length
                  ? widget.imeiControllers[index]
                  : null,
              decoration: InputDecoration(
                labelText: 'IMEI ${index + 1} *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.confirmation_number, size: 18),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index < widget.imeiNumbers.length &&
                        widget.imeiNumbers[index].isNotEmpty)
                      Icon(
                        widget.imeiNumbers[index].length >= 15
                            ? Icons.check_circle
                            : Icons.warning,
                        color: widget.imeiNumbers[index].length >= 15
                            ? Colors.green
                            : Colors.orange,
                        size: 16,
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      onPressed: () => widget.onOpenScannerForImeiField(index),
                      tooltip: 'Scan IMEI',
                      color: Colors.blue,
                    ),
                  ],
                ),
                labelStyle: const TextStyle(fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontSize: 12, color: Colors.black),
              onChanged: (value) {
                if (index < widget.imeiNumbers.length) {
                  setState(() {
                    widget.imeiNumbers[index] = value;
                    widget.onClearModalMessages();
                  });
                }
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter IMEI';
                }
                final trimmedValue = value.trim();
                if (trimmedValue.length < 15) {
                  return 'IMEI must be at least 15 digits';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.content_copy, size: 18),
                onPressed: () {
                  if (index < widget.imeiNumbers.length &&
                      widget.imeiNumbers[index].isNotEmpty) {
                    Clipboard.setData(
                      ClipboardData(text: widget.imeiNumbers[index]),
                    );
                    widget.onClearModalMessages();
                    // Show success message (this would need a callback)
                  }
                },
                tooltip: 'Copy IMEI',
                color: Colors.grey,
              ),
              if (index > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: () {
                    if (index > 0) {
                      final temp = widget.imeiNumbers[index];
                      widget.imeiNumbers[index] = widget.imeiNumbers[index - 1];
                      widget.imeiNumbers[index - 1] = temp;

                      final tempCtrl = widget.imeiControllers[index];
                      widget.imeiControllers[index] =
                          widget.imeiControllers[index - 1];
                      widget.imeiControllers[index - 1] = tempCtrl;

                      setState(() {});
                    }
                  },
                  tooltip: 'Move up',
                  color: Colors.blue,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityField() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Quantity *',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.numbers, size: 18),
        suffixIcon: widget.quantity != null && widget.quantity! > 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.quantity} unit${widget.quantity! > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              )
            : null,
        labelStyle: const TextStyle(fontSize: 12),
        hintText: 'Enter number of units',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      style: const TextStyle(fontSize: 12, color: Colors.black),
      keyboardType: TextInputType.number,
      onChanged: widget.onQuantityChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter quantity';
        }
        final qty = int.tryParse(value);
        if (qty == null || qty <= 0) {
          return 'Please enter valid quantity (min: 1)';
        }
        if (qty > 50) {
          return 'Maximum 50 units at a time';
        }
        return null;
      },
    );
  }

  Widget _buildNewProductForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'New Product Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.green,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 16),
                onPressed: widget.onCancelAddNewProduct,
                tooltip: 'Back to product selection',
              ),
            ],
          ),
          const SizedBox(height: 10),

          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Product Name *',
              border: OutlineInputBorder(),
              labelStyle: TextStyle(fontSize: 12),
              hintText: 'e.g., iPhone 15 Pro Max 256GB',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            style: const TextStyle(fontSize: 12, color: Colors.black),
            onChanged: (value) {
              setState(() {
                widget.onClearModalMessages();
              });
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter product name';
              }
              return null;
            },
          ),

          const SizedBox(height: 10),

          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Price *',
              border: OutlineInputBorder(),
              labelStyle: TextStyle(fontSize: 12),
              prefixText: '₹ ',
              hintText: 'e.g., 129999',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            style: const TextStyle(fontSize: 12, color: Colors.black),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                widget.onClearModalMessages();
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter price';
              }
              final price = double.tryParse(value);
              if (price == null || price <= 0) {
                return 'Please enter valid price';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChangeOption() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price Change Option',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Original Price: ${_formatPrice(widget.originalProductPrice)}',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.priceChangeController,
            decoration: const InputDecoration(
              labelText: 'New Price (optional)',
              border: OutlineInputBorder(),
              labelStyle: TextStyle(fontSize: 12),
              prefixText: '₹ ',
              hintText: 'Enter new price',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            style: const TextStyle(fontSize: 12, color: Colors.black),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              widget.onClearModalMessages();
            },
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Please enter valid price';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 6),
          const Text(
            'Note: Changing price will update this product\'s price for all future stock entries.',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (widget.modalError == null) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.modalError!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: widget.onClearModalMessages,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    if (widget.modalSuccess == null ||
        widget.modalSuccess!.contains('Product added')) {
      return const SizedBox();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.modalSuccess!,
              style: const TextStyle(fontSize: 12, color: Colors.green),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: widget.onClearModalMessages,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildImeiFields() {
    if (widget.quantity == null || widget.quantity! <= 0) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter IMEI Numbers: *',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Each IMEI must be 15-16 digits (${widget.quantity} required)',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: widget.quantity! <= 3 ? widget.quantity! * 70.0 : 210.0,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: widget.quantity!,
            itemBuilder: (context, index) {
              return _buildImeiInputField(index);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Phone Stock',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.white,
                        ),
                        onPressed: widget.onCloseModal,
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: widget.formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand Selection
                        DropdownButtonFormField<String>(
                          value: widget.selectedBrand,
                          dropdownColor: Colors.white,
                          decoration: const InputDecoration(
                            labelText: 'Select Brand *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.branding_watermark,
                              size: 18,
                            ),
                            labelStyle: TextStyle(fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                          items: widget.brands.map<DropdownMenuItem<String>>((
                            brand,
                          ) {
                            return DropdownMenuItem<String>(
                              value: brand,
                              child: Text(
                                brand,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: widget.onBrandChanged,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a brand';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // Product Search/Selection
                        if (widget.selectedBrand != null) ...[
                          _buildProductSearchDropdown(),
                          const SizedBox(height: 12),

                          // New Product Form
                          if (widget.showAddProductForm) ...[
                            _buildNewProductForm(),
                            const SizedBox(height: 12),
                          ],

                          // Price Change Option
                          if (widget.showPriceChangeOption &&
                              widget.originalProductPrice != null) ...[
                            _buildPriceChangeOption(),
                            const SizedBox(height: 12),
                          ],
                        ],

                        // Quantity Field
                        if (widget.selectedProduct != null ||
                            widget.showAddProductForm) ...[
                          _buildQuantityField(),
                          const SizedBox(height: 12),
                        ],

                        // IMEI Fields
                        if (widget.quantity != null &&
                            widget.quantity! > 0) ...[
                          _buildImeiFields(),
                          const SizedBox(height: 12),
                        ],

                        // Error Message
                        _buildErrorMessage(),

                        // Success Message
                        _buildSuccessMessage(),

                        // Action Buttons
                        Container(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: widget.onCloseModal,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: widget.isLoading
                                      ? null
                                      : widget.onSaveStock,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                  child: widget.isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Save Stock',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}
