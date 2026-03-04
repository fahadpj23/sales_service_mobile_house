import 'package:flutter/material.dart';

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

  const AddTvStockModal({
    super.key,
    required this.formKey,
    this.selectedBrand,
    this.selectedModel,
    this.newModelName,
    this.newModelPrice,
    this.quantity,
    required this.serialNumbers,
    required this.serialControllers,
    required this.brands,
    required this.modelsByBrand,
    required this.isLoading,
    required this.showAddModelForm,
    required this.showPriceChangeOption,
    this.originalModelPrice,
    required this.modelSearchController,
    required this.priceChangeController,
    required this.searchController,
    required this.newModelNameController,
    required this.newModelPriceController,
    this.modalError,
    this.modalSuccess,
    required this.onBrandChanged,
    required this.onModelSelected,
    required this.onCancelAddNewModel,
    required this.onQuantityChanged,
    required this.onOpenScannerForSerialField,
    required this.onClearModalMessages,
    required this.onCloseModal,
    required this.onSaveStock,
    required this.onSaveNewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
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
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tv, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'Add TV Stock',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onCloseModal,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBrandDropdown(),
                      const SizedBox(height: 16),
                      _buildModelSection(),
                      if (showAddModelForm) ...[
                        const SizedBox(height: 16),
                        _buildAddModelForm(),
                      ],
                      if (showPriceChangeOption) ...[
                        const SizedBox(height: 16),
                        _buildPriceChangeField(),
                      ],
                      const SizedBox(height: 16),
                      _buildQuantityField(),
                      const SizedBox(height: 16),
                      _buildSerialNumbersList(),
                      const SizedBox(height: 16),
                      if (modalError != null) _buildErrorWidget(),
                      if (modalSuccess != null) _buildSuccessWidget(),
                      const SizedBox(height: 20),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Brand *',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedBrand,
              isExpanded: true,
              hint: const Text('Choose a brand'),
              items: [
                ...brands.map((brand) {
                  return DropdownMenuItem<String>(
                    value: brand,
                    child: Text(brand, style: const TextStyle(fontSize: 13)),
                  );
                }),
              ],
              onChanged: isLoading ? null : onBrandChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModelSection() {
    if (selectedBrand == null) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Model *',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        _buildModelSearchDropdown(),
      ],
    );
  }

  Widget _buildModelSearchDropdown() {
    if (showAddModelForm) {
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
                  'Adding New Model',
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
              'Enter model details below. Model will be saved to database.',
              style: TextStyle(fontSize: 10, color: Colors.blue),
            ),
          ],
        ),
      );
    }

    final models = modelsByBrand[selectedBrand!] ?? [];
    final filteredModels = modelSearchController.text.isEmpty
        ? models
        : models.where((model) {
            final modelName = model['modelName'] as String? ?? '';
            return modelName.toLowerCase().contains(
              modelSearchController.text.toLowerCase(),
            );
          }).toList();

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
                      modelSearchController.clear();
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
            if (selectedModel != null && value != selectedModel) {
              onModelSelected(null);
            }
            onClearModalMessages();
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
            child: _buildModelList(filteredModels),
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
      ],
    );
  }

  Widget _buildModelList(List<Map<String, dynamic>> filteredModels) {
    final brandHasNoModels =
        !modelsByBrand.containsKey(selectedBrand!) ||
        (modelsByBrand[selectedBrand!] ?? []).isEmpty;

    final searchHasNoResults =
        modelSearchController.text.isNotEmpty && filteredModels.isEmpty;

    final shouldShowAddNew = brandHasNoModels || searchHasNoResults;

    return ListView.builder(
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
    );
  }

  Widget _buildAddNewModelTile() {
    String subtitleText = '';

    if (!modelsByBrand.containsKey(selectedBrand!) ||
        (modelsByBrand[selectedBrand!] ?? []).isEmpty) {
      subtitleText = 'No models found for this brand';
    } else if (modelSearchController.text.isNotEmpty) {
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

  Widget _buildAddModelForm() {
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
          const Text(
            'New Model Details',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: newModelNameController,
            decoration: const InputDecoration(
              labelText: 'Model Name *',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: newModelPriceController,
            decoration: const InputDecoration(
              labelText: 'Price *',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancelAddNewModel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onSaveNewModel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Model'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChangeField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.amber.shade700, size: 16),
              const SizedBox(width: 8),
              Text(
                'Original Price: ${originalModelPrice?.toStringAsFixed(0) ?? ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: priceChangeController,
            decoration: InputDecoration(
              labelText: 'New Price (Optional)',
              prefixText: '₹ ',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              hintText: 'Leave empty to keep original price',
            ),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quantity *',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.numbers, size: 18),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            hintText: 'Enter quantity',
          ),
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 12),
          onChanged: onQuantityChanged,
        ),
      ],
    );
  }

  Widget _buildSerialNumbersList() {
    if (quantity == null || quantity! <= 0) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Serial Numbers *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              '(${serialNumbers.length}/$quantity)',
              style: TextStyle(
                fontSize: 11,
                color: serialNumbers.length == quantity
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(quantity!, (index) {
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
                      labelStyle: const TextStyle(fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                    onChanged: (value) {
                      if (index < serialNumbers.length) {
                        serialNumbers[index] = value;
                      }
                    },
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
                      if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(trimmedValue)) {
                        return 'Use only letters and numbers';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (index > 0)
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        onPressed: () {
                          if (index > 0) {
                            final temp = serialNumbers[index];
                            serialNumbers[index] = serialNumbers[index - 1];
                            serialNumbers[index - 1] = temp;

                            final tempCtrl = serialControllers[index];
                            serialControllers[index] =
                                serialControllers[index - 1];
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
        }),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              modalError!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              modalSuccess!,
              style: TextStyle(fontSize: 12, color: Colors.green.shade700),
            ),
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
            onPressed: isLoading ? null : onCloseModal,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: isLoading ? null : onSaveStock,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
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
                : const Text('Save Stock'),
          ),
        ),
      ],
    );
  }
}
