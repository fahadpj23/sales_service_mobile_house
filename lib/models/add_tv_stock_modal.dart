import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddTvStockModal extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String? selectedBrand;
  final String? selectedModel;
  final String? newModelName;
  final double? newModelPrice;
  final int? quantity;
  final List<String> serialNumbers;
  final List<TextEditingController> serialControllers;
  final List<String> brands;
  final Map<String, List<Map<String, dynamic>>> modelsByBrand;
  final bool isLoading;
  final bool showAddModelForm;
  final bool showPriceChangeOption;
  final double? originalModelPrice;
  final TextEditingController modelSearchController;
  final TextEditingController priceChangeController;
  final TextEditingController searchController;
  final TextEditingController newModelNameController;
  final TextEditingController newModelPriceController;
  final String? modalError;
  final String? modalSuccess;
  final Function(String?) onBrandChanged;
  final Function(String?) onModelSelected;
  final VoidCallback onCancelAddNewModel;
  final Function(String) onQuantityChanged;
  final Function(int) onOpenScannerForSerialField;
  final VoidCallback onClearModalMessages;
  final VoidCallback onCloseModal;
  final VoidCallback onSaveStock;
  final VoidCallback onSaveNewModel;
  final VoidCallback onAddNewBrand; // New callback for adding brand

  const AddTvStockModal({
    super.key,
    required this.formKey,
    required this.selectedBrand,
    required this.selectedModel,
    required this.newModelName,
    required this.newModelPrice,
    required this.quantity,
    required this.serialNumbers,
    required this.serialControllers,
    required this.brands,
    required this.modelsByBrand,
    required this.isLoading,
    required this.showAddModelForm,
    required this.showPriceChangeOption,
    required this.originalModelPrice,
    required this.modelSearchController,
    required this.priceChangeController,
    required this.searchController,
    required this.newModelNameController,
    required this.newModelPriceController,
    required this.modalError,
    required this.modalSuccess,
    required this.onBrandChanged,
    required this.onModelSelected,
    required this.onCancelAddNewModel,
    required this.onQuantityChanged,
    required this.onOpenScannerForSerialField,
    required this.onClearModalMessages,
    required this.onCloseModal,
    required this.onSaveStock,
    required this.onSaveNewModel,
    required this.onAddNewBrand,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Add TV to Stock',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onCloseModal,
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Error/Success messages
                      if (modalError != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  modalError!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (modalSuccess != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  modalSuccess!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Brand Selection with Add New Brand option
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: DropdownButtonFormField<String>(
                          value: selectedBrand,
                          decoration: const InputDecoration(
                            labelText: 'Select Brand *',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          style: const TextStyle(fontSize: 12, color: Colors.black),
                          items: [
                            // Add "Add New Brand" option at the top
                            const DropdownMenuItem<String>(
                              value: 'add_new_brand',
                              child: Row(
                                children: [
                                  Icon(Icons.add, color: Colors.green, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add New Brand...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Divider
                            const DropdownMenuItem<String>(
                              value: null,
                              enabled: false,
                              child: Divider(height: 1),
                            ),
                            // Existing brands
                            ...brands.map((brand) {
                              return DropdownMenuItem<String>(
                                value: brand,
                                child: Text(
                                  brand,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            if (value == 'add_new_brand') {
                              onAddNewBrand();
                            } else {
                              onBrandChanged(value);
                            }
                          },
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty ||
                                value == 'add_new_brand') {
                              return 'Please select a brand';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Model selection
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _buildModelSection(),
                      ),

                      const SizedBox(height: 12),

                      // Quantity
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Quantity *',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          style: const TextStyle(fontSize: 12, color: Colors.black),
                          keyboardType: TextInputType.number,
                          onChanged: onQuantityChanged,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter quantity';
                            }
                            final qty = int.tryParse(value);
                            if (qty == null || qty <= 0) {
                              return 'Enter valid quantity';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Serial numbers
                      if (quantity != null && quantity! > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Serial Numbers',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                              quantity!,
                              (index) => _buildSerialInputField(index),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading ? null : onCloseModal,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
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
                      onPressed: isLoading ? null : onSaveStock,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Add to Stock',
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
    );
  }

  Widget _buildModelSection() {
    if (selectedBrand == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'Please select a brand first',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }

    if (showAddModelForm) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Adding New Model',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: newModelNameController,
                  decoration: const InputDecoration(
                    labelText: 'Model Name *',
                    labelStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.black),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter model name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: newModelPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Model Price *',
                    labelStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.black),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter model price';
                    }
                    final price = double.tryParse(value.trim());
                    if (price == null || price <= 0) {
                      return 'Enter valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancelAddNewModel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onSaveNewModel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'Add Model',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Show model search dropdown
    final models = modelsByBrand[selectedBrand] ?? [];
    final searchText = modelSearchController.text.toLowerCase();
    List<Map<String, dynamic>> filteredModels = [];

    if (searchText.isNotEmpty) {
      filteredModels = models.where((model) {
        final modelName = model['modelName'] as String? ?? '';
        return modelName.toLowerCase().contains(searchText);
      }).toList();
    } else {
      filteredModels = List.from(models);
    }

    final brandHasNoModels = models.isEmpty;
    final searchHasNoResults = searchText.isNotEmpty && filteredModels.isEmpty;
    final shouldShowAddNew = brandHasNoModels || searchHasNoResults;

    return Column(
      children: [
        TextField(
          controller: modelSearchController,
          decoration: InputDecoration(
            labelText: 'Search Model',
            labelStyle: const TextStyle(fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: selectedModel != null && selectedModel!.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      onModelSelected(null);
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            hintText: selectedModel ?? 'Search or select model',
          ),
          style: const TextStyle(fontSize: 12, color: Colors.black),
          onChanged: (value) {
            onModelSelected(value);
          },
        ),
        const SizedBox(height: 8),

        if (selectedModel == null || modelSearchController.text.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: filteredModels.length + (shouldShowAddNew ? 1 : 0),
              itemBuilder: (context, index) {
                if (shouldShowAddNew && index == filteredModels.length) {
                  return _buildAddNewModelTile();
                }

                final model = filteredModels[index];
                final modelName = model['modelName'] as String? ?? '';
                final price = model['price'];
                String priceText = '';

                if (price is double) {
                  priceText = '₹${price.toStringAsFixed(0)}';
                } else if (price is int) {
                  priceText = '₹$price';
                }

                return ListTile(
                  title: Text(
                    modelName,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                    maxLines: 1,
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
                    vertical: 4,
                  ),
                  onTap: () {
                    onModelSelected(modelName);
                  },
                  trailing: selectedModel == modelName
                      ? const Icon(Icons.check, color: Colors.green, size: 16)
                      : null,
                );
              },
            ),
          ),

        if (selectedModel != null && modelSearchController.text.isEmpty)
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
                      Text(
                        'Selected Model:',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedModel!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (originalModelPrice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Price: ₹${originalModelPrice!.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () {
                    onModelSelected(null);
                  },
                  tooltip: 'Change model',
                ),
              ],
            ),
          ),

        if (showPriceChangeOption && selectedModel != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Price Change Option',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: priceChangeController,
                  decoration: const InputDecoration(
                    labelText: 'New Price (optional)',
                    labelStyle: TextStyle(fontSize: 11),
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 11, color: Colors.black),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 4),
                Text(
                  'Leave empty to keep original price',
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddNewModelTile() {
    String subtitleText = '';

    if (!modelsByBrand.containsKey(selectedBrand) ||
        (modelsByBrand[selectedBrand] ?? []).isEmpty) {
      subtitleText = 'No models found for this brand';
    } else if (modelSearchController.text.isNotEmpty &&
        modelsByBrand[selectedBrand]!.where((model) {
          final modelName = model['modelName'] as String? ?? '';
          return modelName
              .toLowerCase()
              .contains(modelSearchController.text.toLowerCase());
        }).isEmpty) {
      subtitleText = 'No matching models found';
    }

    return ListTile(
      leading: const Icon(Icons.add, color: Colors.green, size: 18),
      title: const Text(
        'Add New Model...',
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onTap: () {
        onModelSelected('add_new');
      },
    );
  }

  Widget _buildSerialInputField(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: index < serialControllers.length
                  ? serialControllers[index]
                  : null,
              decoration: InputDecoration(
                labelText: 'Serial Number ${index + 1} *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.qr_code, size: 18),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index < serialNumbers.length &&
                        serialNumbers[index].isNotEmpty)
                      Icon(
                        serialNumbers[index].length >= 8
                            ? Icons.check_circle
                            : Icons.warning,
                        color: serialNumbers[index].length >= 8
                            ? Colors.green
                            : Colors.orange,
                        size: 16,
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      onPressed: () => onOpenScannerForSerialField(index),
                      tooltip: 'Scan Serial',
                      color: Colors.blue,
                    ),
                  ],
                ),
                labelStyle: const TextStyle(fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              style: const TextStyle(fontSize: 12, color: Colors.black),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter serial number';
                }
                final trimmedValue = value.trim();
                if (trimmedValue.length < 8) {
                  return 'Serial must be at least 8 characters';
                }
                if (trimmedValue.length > 20) {
                  return 'Serial must be at most 20 characters';
                }
                if (!RegExp(r'^[A-Za-z0-9/]+$').hasMatch(trimmedValue)) {
                  return 'Use only letters, numbers, and forward slash (/)';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              if (index > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: () {
                    if (index > 0) {
                      final temp = serialNumbers[index];
                      serialNumbers[index] = serialNumbers[index - 1];
                      serialNumbers[index - 1] = temp;

                      final tempCtrl = serialControllers[index];
                      serialControllers[index] = serialControllers[index - 1];
                      serialControllers[index - 1] = tempCtrl;
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
}