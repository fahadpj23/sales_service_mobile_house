import 'package:flutter/material.dart';
import 'package:sales_stock/models/purchase_item.dart';
import 'package:sales_stock/screens/user/purchase/purchase_history_screen.dart';
import 'package:sales_stock/services/firestore_service.dart';
import 'package:sales_stock/screens/user/purchase/create_purchase_preview.dart';
import 'package:sales_stock/screens/user/purchase/create_accessory_purchase_form.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/auth_provider.dart';

class CreateAccessoryPurchaseScreen extends StatefulWidget {
  final Map<String, dynamic>? supplier;

  const CreateAccessoryPurchaseScreen({Key? key, this.supplier})
    : super(key: key);

  @override
  State<CreateAccessoryPurchaseScreen> createState() =>
      _CreateAccessoryPurchaseScreenState();
}

class _CreateAccessoryPurchaseScreenState
    extends State<CreateAccessoryPurchaseScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Color _primaryGreen = const Color(0xFF2E7D32);
  final Color _lightGreen = const Color(0xFF4CAF50);
  final Color _backgroundColor = const Color(0xFFF5F9F5);
  final Color _accessoryColor = const Color(
    0xFF9C27B0,
  ); // Purple for accessories

  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController();
  final _invoiceController = TextEditingController();
  final _notesController = TextEditingController();
  final _productSearchController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _accessories = [];
  List<Map<String, dynamic>> _filteredAccessories = [];
  Map<String, dynamic>? _selectedSupplier;
  List<PurchaseItem> _purchaseItems = [];

  double _subtotal = 0.0;
  double _gstAmount = 0.0;
  double _totalAmount = 0.0;
  double _totalDiscount = 0.0;
  double _roundOff = 0.0;
  Map<int, bool> _showEditSections = {};
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
    _fetchAccessories();
    if (widget.supplier != null) {
      _selectedSupplier = widget.supplier;
      _supplierController.text = widget.supplier!['name'] ?? '';
    }
    _addNewItem();
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceController.dispose();
    _notesController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuppliers() async {
    _suppliers = await _firestoreService.getSuppliers();
    setState(() {});
  }

  Future<void> _fetchAccessories() async {
    _accessories = await _firestoreService.getAccessories();
    _filteredAccessories = List.from(_accessories);
    setState(() {});
  }

  void _filterAccessories(String query) {
    if (query.isEmpty) {
      _filteredAccessories = List.from(_accessories);
    } else {
      final searchQuery = query.toLowerCase().trim();
      final searchWords = searchQuery.split(' ');

      _filteredAccessories = _accessories.where((accessory) {
        final accessoryName = (accessory['accessoryName'] ?? '')
            .toString()
            .toLowerCase();
        final combinedText = accessoryName;

        return searchWords.every((word) {
          if (word.isEmpty) return true;
          return combinedText.contains(word);
        });
      }).toList();
    }
    setState(() {});
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _accessoryColor,
              onPrimary: Colors.white,
              onSurface: Colors.grey.shade800,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _accessoryColor),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _calculateTotals() {
    _subtotal = 0.0;
    _totalDiscount = 0.0;
    _gstAmount = 0.0;

    for (var item in _purchaseItems) {
      if (item.quantity != null && item.rate != null) {
        double itemTotal = item.quantity! * item.rate!;

        if (item.discountPercentage != null && item.discountPercentage! > 0) {
          double discountAmount = itemTotal * (item.discountPercentage! / 100);
          itemTotal -= discountAmount;
          _totalDiscount += discountAmount;
        }

        _subtotal += itemTotal;
        item.gstAmount = itemTotal * 0.18;
        _gstAmount += item.gstAmount!;
      }
    }

    _totalAmount = _subtotal + _gstAmount;
    _roundOff = _totalAmount.roundToDouble() - _totalAmount;
    _totalAmount = _totalAmount.roundToDouble();

    setState(() {});
  }

  void _addNewItem() {
    setState(() {
      final newIndex = _purchaseItems.length;
      _purchaseItems.add(PurchaseItem(discountPercentage: 0.0, quantity: 1.0));

      for (var key in _showEditSections.keys) {
        _showEditSections[key] = false;
      }
      _showEditSections[newIndex] = true;
    });
  }

  void _removeItem(int index) {
    if (_purchaseItems.length > 1) {
      setState(() {
        _purchaseItems.removeAt(index);

        // Rebuild indices for remaining items
        final newPurchaseItems = <PurchaseItem>[];
        final newShowEditSections = <int, bool>{};

        for (int i = 0; i < _purchaseItems.length; i++) {
          newPurchaseItems.add(_purchaseItems[i]);

          if (i < index) {
            newShowEditSections[i] = _showEditSections[i] ?? false;
          } else {
            newShowEditSections[i] = _showEditSections[i + 1] ?? false;
          }
        }

        _purchaseItems = newPurchaseItems;
        _showEditSections = newShowEditSections;

        _calculateTotals();
      });
    }
  }

  void _toggleEditSection(int index) {
    setState(() {
      final currentState = _showEditSections[index] ?? false;

      if (!currentState) {
        for (var key in _showEditSections.keys) {
          _showEditSections[key] = false;
        }
      }
      _showEditSections[index] = !currentState;
    });
  }

  void _togglePreview() {
    setState(() {
      _showPreview = !_showPreview;
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: const Color(0xFFE53935),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: _lightGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Purchase Accessories'),
        backgroundColor: _accessoryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          CreateAccessoryPurchaseForm(
            primaryGreen: _accessoryColor,
            lightGreen: _lightGreen,
            formKey: _formKey,
            selectedDate: _selectedDate,
            selectDate: _selectDate,
            suppliers: _suppliers,
            selectedSupplier: _selectedSupplier,
            supplierController: _supplierController,
            showSupplierSelection: _showSupplierSelection,
            invoiceController: _invoiceController,
            notesController: _notesController,
            purchaseItems: _purchaseItems,
            showEditSections: _showEditSections,
            subtotal: _subtotal,
            totalDiscount: _totalDiscount,
            gstAmount: _gstAmount,
            roundOff: _roundOff,
            totalAmount: _totalAmount,
            addNewItem: _addNewItem,
            toggleEditSection: _toggleEditSection,
            removeItem: _removeItem,
            showProductSelection: _showAccessorySelection,
            togglePreview: _togglePreview,
            savePurchase: _savePurchase,
            updateItemQuantity: _updateItemQuantity,
            updateItemRate: _updateItemRate,
            updateItemDiscount: _updateItemDiscount,
            // Removed updateItemHsnCode
          ),
          if (_showPreview)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: CreatePurchasePreview(
                primaryGreen: _accessoryColor,
                lightGreen: _lightGreen,
                selectedDate: _selectedDate,
                selectedSupplier: _selectedSupplier,
                invoiceController: _invoiceController,
                purchaseItems: _purchaseItems,
                itemImeis: {}, // Empty map since accessories don't need IMEI
                subtotal: _subtotal,
                totalDiscount: _totalDiscount,
                gstAmount: _gstAmount,
                roundOff: _roundOff,
                totalAmount: _totalAmount,
                togglePreview: _togglePreview,
                confirmAndSavePurchase: _confirmAndSavePurchase,
                isValidSerialNumber: (s) => true,
                hideSerialInfo: true, // Hide serial info in preview
              ),
            ),
        ],
      ),
    );
  }

  void _updateItemQuantity(int index, String value) {
    final quantity = double.tryParse(value);
    if (quantity != null && quantity > 0) {
      setState(() {
        _purchaseItems[index].quantity = quantity;
      });
      _calculateTotals();
    }
  }

  void _updateItemRate(int index, String value) {
    final rate = double.tryParse(value);
    if (rate != null && rate >= 0) {
      setState(() {
        _purchaseItems[index].rate = rate;
      });
      _calculateTotals();
    }
  }

  void _updateItemDiscount(int index, String value) {
    final discount = double.tryParse(value);
    if (discount != null && discount >= 0) {
      setState(() {
        _purchaseItems[index].discountPercentage = discount;
      });
      _calculateTotals();
    }
  }

  // Removed _updateItemHsnCode method

  void _showSupplierSelection() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accessoryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Supplier',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _suppliers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.business,
                            size: 50,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No suppliers found',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add suppliers in the suppliers section',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _suppliers.length,
                      itemBuilder: (context, index) {
                        final supplier = _suppliers[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: _lightGreen.withOpacity(0.1),
                            radius: 16,
                            child: Icon(
                              Icons.business,
                              color: _lightGreen,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            supplier['name'] ?? 'Unnamed',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          subtitle: supplier['phone'] != null
                              ? Text(
                                  supplier['phone']!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                )
                              : null,
                          trailing: _selectedSupplier?['id'] == supplier['id']
                              ? Icon(
                                  Icons.check_circle,
                                  color: _lightGreen,
                                  size: 18,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedSupplier = supplier;
                              _supplierController.text = supplier['name'] ?? '';
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAccessorySelection(int itemIndex) async {
    final selectedAccessory = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _accessoryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Accessory',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            _productSearchController.clear();
                            _filterAccessories('');
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _productSearchController,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search by name...',
                          hintStyle: const TextStyle(fontSize: 11),
                          prefixIcon: Icon(
                            Icons.search,
                            color: _accessoryColor,
                            size: 18,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          suffixIcon: _productSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    _productSearchController.clear();
                                    _filterAccessories('');
                                    setSheetState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          _filterAccessories(value);
                          setSheetState(() {});
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: _filteredAccessories.isEmpty
                        ? _buildEmptyAccessoryState(setSheetState)
                        : _buildAccessoryList(setSheetState),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (selectedAccessory != null) {
      _handleAccessorySelection(itemIndex, selectedAccessory);
    } else {
      _productSearchController.clear();
      _filterAccessories('');
    }
  }

  Widget _buildEmptyAccessoryState(StateSetter setSheetState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _productSearchController.text.isEmpty
              ? Icons.headphones_outlined
              : Icons.search_off,
          size: 60,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 16),
        Text(
          _productSearchController.text.isEmpty
              ? 'No accessories available'
              : 'Accessory not found',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _productSearchController.text.isEmpty
              ? 'Add your first accessory to continue'
              : 'Add "${_productSearchController.text}" as new accessory',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ElevatedButton.icon(
            onPressed: () async {
              final searchText = _productSearchController.text;
              Navigator.pop(context);
              await _showAddAccessoryDialog(preFilledSearch: searchText);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _productSearchController.text.isEmpty
                  ? _lightGreen
                  : const Color(0xFFFF9800),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
              'Add New Accessory',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessoryList(StateSetter setSheetState) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Found ${_filteredAccessories.length} accessory${_filteredAccessories.length != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              TextButton.icon(
                onPressed: () async {
                  final searchText = _productSearchController.text;
                  Navigator.pop(context);
                  await _showAddAccessoryDialog(preFilledSearch: searchText);
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2196F3),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add New', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _filteredAccessories.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final accessory = _filteredAccessories[index];
              return _buildAccessoryListItem(accessory, setSheetState);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccessoryListItem(
    Map<String, dynamic> accessory,
    StateSetter setSheetState,
  ) {
    final hasPurchaseRate =
        accessory['purchaseRate'] != null &&
        (accessory['purchaseRate'] is num) &&
        accessory['purchaseRate'] > 0;
    final accessoryName = accessory['accessoryName'] ?? 'Unnamed Accessory';
    final purchaseRate = accessory['purchaseRate'] ?? 0.0;
    final salesRate = accessory['salesRate'] ?? 0.0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: hasPurchaseRate
              ? _accessoryColor.withOpacity(0.1)
              : const Color(0xFFFFB300).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.headphones,
          size: 20,
          color: hasPurchaseRate ? _accessoryColor : const Color(0xFFFFB300),
        ),
      ),
      title: Text(
        accessoryName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Purchase: ₹${(purchaseRate as num).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _accessoryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sales: ₹${(salesRate as num).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _lightGreen,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _accessoryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.add, size: 16, color: _accessoryColor),
      ),
      onTap: () async {
        if (!hasPurchaseRate) {
          final rates = await _showSetRatesDialog(accessoryName);
          if (rates != null) {
            await _firestoreService.updateAccessoryRates(
              accessory['id'] ?? '',
              rates['purchaseRate'],
              rates['salesRate'],
            );
            accessory['purchaseRate'] = rates['purchaseRate'];
            accessory['salesRate'] = rates['salesRate'];
            await _fetchAccessories();
            _productSearchController.clear();
            _filterAccessories('');
            Navigator.pop(context, accessory);
          }
        } else {
          _productSearchController.clear();
          _filterAccessories('');
          Navigator.pop(context, accessory);
        }
      },
    );
  }

  void _handleAccessorySelection(
    int itemIndex,
    Map<String, dynamic> accessory,
  ) {
    _productSearchController.clear();
    _filterAccessories('');

    setState(() {
      _purchaseItems[itemIndex].productId = accessory['id'] ?? '';
      _purchaseItems[itemIndex].productName =
          accessory['accessoryName'] ?? 'Unnamed Accessory';
      // Removed HSN code assignment

      final purchaseRate = accessory['purchaseRate'];
      if (purchaseRate != null && purchaseRate is num && purchaseRate > 0) {
        _purchaseItems[itemIndex].rate = purchaseRate.toDouble();
        _purchaseItems[itemIndex].gstAmount = purchaseRate.toDouble() * 0.18;
      }

      for (var key in _showEditSections.keys) {
        _showEditSections[key] = false;
      }
      _showEditSections[itemIndex] = true;

      _calculateTotals();
    });
  }

  Future<Map<String, double>?> _showSetRatesDialog(String accessoryName) async {
    final purchaseRateController = TextEditingController();
    final salesRateController = TextEditingController();

    return await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Set Rates',
              style: TextStyle(color: _accessoryColor, fontSize: 14),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    accessoryName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter purchase rate (cost price):',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: purchaseRateController,
                    style: const TextStyle(fontSize: 12),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Purchase Rate',
                      labelStyle: const TextStyle(fontSize: 11),
                      hintText: 'Enter purchase rate...',
                      hintStyle: const TextStyle(fontSize: 11),
                      prefixText: '₹ ',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    autofocus: true,
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter sales rate (selling price):',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: salesRateController,
                    style: const TextStyle(fontSize: 12),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Sales Rate',
                      labelStyle: const TextStyle(fontSize: 11),
                      hintText: 'Enter sales rate...',
                      hintStyle: const TextStyle(fontSize: 11),
                      prefixText: '₹ ',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                  if (purchaseRateController.text.isNotEmpty &&
                      salesRateController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accessoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            _buildPriceCalculationRow(
                              'Purchase Rate:',
                              '₹${double.tryParse(purchaseRateController.text)?.toStringAsFixed(2) ?? '0.00'}',
                            ),
                            _buildPriceCalculationRow(
                              'Sales Rate:',
                              '₹${double.tryParse(salesRateController.text)?.toStringAsFixed(2) ?? '0.00'}',
                            ),
                            _buildPriceCalculationRow(
                              'GST on Purchase (18%):',
                              '₹${(double.tryParse(purchaseRateController.text) ?? 0 * 0.18).toStringAsFixed(2)}',
                            ),
                            _buildPriceCalculationRow(
                              'GST on Sales (18%):',
                              '₹${(double.tryParse(salesRateController.text) ?? 0 * 0.18).toStringAsFixed(2)}',
                            ),
                            const Divider(height: 12),
                            _buildPriceCalculationRow(
                              'Profit Margin:',
                              '₹${((double.tryParse(salesRateController.text) ?? 0) - (double.tryParse(purchaseRateController.text) ?? 0)).toStringAsFixed(2)}',
                              isBold: true,
                              color: _lightGreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _productSearchController.clear();
                  _filterAccessories('');
                },
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              ElevatedButton(
                onPressed: () {
                  final purchaseRate = double.tryParse(
                    purchaseRateController.text,
                  );
                  final salesRate = double.tryParse(salesRateController.text);

                  if (purchaseRate != null &&
                      purchaseRate > 0 &&
                      salesRate != null &&
                      salesRate > 0) {
                    if (salesRate < purchaseRate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Sales rate should be greater than purchase rate',
                            style: TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'purchaseRate': purchaseRate,
                      'salesRate': salesRate,
                    });
                    _productSearchController.clear();
                    _filterAccessories('');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter valid purchase and sales rates',
                          style: TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _lightGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'Set Rates',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPriceCalculationRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: color ?? Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAccessoryDialog({String preFilledSearch = ''}) async {
    final accessoryNameController = TextEditingController();
    final purchaseRateController = TextEditingController();
    final salesRateController = TextEditingController();

    if (preFilledSearch.isNotEmpty) {
      accessoryNameController.text = preFilledSearch;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _accessoryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.headphones, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add New Accessory',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // Accessory Name
                        _buildFormSection(
                          label: 'Accessory Name *',
                          child: TextField(
                            controller: accessoryNameController,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'e.g., Fast Charger, USB Cable',
                              hintStyle: const TextStyle(fontSize: 11),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: Icon(
                                Icons.headphones,
                                color: _accessoryColor,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Pricing Information Section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _accessoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _accessoryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pricing Information',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _accessoryColor,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Purchase Rate
                              _buildFormSection(
                                label: 'Purchase Rate (Cost Price) *',
                                child: TextField(
                                  controller: purchaseRateController,
                                  style: const TextStyle(fontSize: 12),
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter purchase rate',
                                    hintStyle: const TextStyle(fontSize: 11),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixText: '₹ ',
                                  ),
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Sales Rate
                              _buildFormSection(
                                label: 'Sales Rate (Selling Price) *',
                                child: TextField(
                                  controller: salesRateController,
                                  style: const TextStyle(fontSize: 12),
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter sales rate',
                                    hintStyle: const TextStyle(fontSize: 11),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixText: '₹ ',
                                  ),
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),

                              // Price Calculation Preview
                              if (purchaseRateController.text.isNotEmpty &&
                                  salesRateController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildPriceRow(
                                          'Purchase Rate:',
                                          '₹${double.tryParse(purchaseRateController.text)?.toStringAsFixed(2) ?? '0.00'}',
                                        ),
                                        _buildPriceRow(
                                          'Sales Rate:',
                                          '₹${double.tryParse(salesRateController.text)?.toStringAsFixed(2) ?? '0.00'}',
                                        ),
                                        _buildPriceRow(
                                          'GST on Purchase (18%):',
                                          '₹${(double.tryParse(purchaseRateController.text) ?? 0 * 0.18).toStringAsFixed(2)}',
                                        ),
                                        _buildPriceRow(
                                          'GST on Sales (18%):',
                                          '₹${(double.tryParse(salesRateController.text) ?? 0 * 0.18).toStringAsFixed(2)}',
                                        ),
                                        const Divider(height: 10),
                                        _buildPriceRow(
                                          'Profit Margin:',
                                          '₹${((double.tryParse(salesRateController.text) ?? 0) - (double.tryParse(purchaseRateController.text) ?? 0)).toStringAsFixed(2)}',
                                          color: _lightGreen,
                                          isBold: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_validateAccessoryForm(
                                accessoryNameController,
                                purchaseRateController,
                                salesRateController,
                              )) {
                                try {
                                  await _saveAccessory(
                                    accessoryNameController,
                                    purchaseRateController,
                                    salesRateController,
                                  );
                                  Navigator.pop(context);
                                } catch (e) {
                                  // Error handled in _saveAccessory
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accessoryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Save Accessory',
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
        },
      ),
    );
  }

  bool _validateAccessoryForm(
    TextEditingController accessoryNameController,
    TextEditingController purchaseRateController,
    TextEditingController salesRateController,
  ) {
    if (accessoryNameController.text.isEmpty) {
      _showErrorSnackbar('Please enter accessory name');
      return false;
    }

    if (purchaseRateController.text.isEmpty) {
      _showErrorSnackbar('Please enter purchase rate');
      return false;
    }

    if (salesRateController.text.isEmpty) {
      _showErrorSnackbar('Please enter sales rate');
      return false;
    }

    final purchaseRate = double.tryParse(purchaseRateController.text);
    final salesRate = double.tryParse(salesRateController.text);

    if (purchaseRate == null || purchaseRate <= 0) {
      _showErrorSnackbar('Please enter a valid purchase rate');
      return false;
    }

    if (salesRate == null || salesRate <= 0) {
      _showErrorSnackbar('Please enter a valid sales rate');
      return false;
    }

    if (salesRate < purchaseRate) {
      _showErrorSnackbar('Sales rate should be greater than purchase rate');
      return false;
    }

    return true;
  }

  Future<void> _saveAccessory(
    TextEditingController accessoryNameController,
    TextEditingController purchaseRateController,
    TextEditingController salesRateController,
  ) async {
    try {
      final accessoryData = {
        'accessoryName': accessoryNameController.text.trim(),
        'purchaseRate': double.parse(purchaseRateController.text),
        'salesRate': double.parse(salesRateController.text),
        'stockQuantity': 0,
        'createdAt': DateTime.now(),
      };

      await _firestoreService.addAccessory(accessoryData);
      await _fetchAccessories();

      _productSearchController.clear();
      _filterAccessories('');

      _showSuccessSnackbar('Accessory added successfully');
    } catch (e) {
      _showErrorSnackbar('Error adding accessory: $e');
    }
  }

  Widget _buildFormSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color ?? Colors.grey.shade800,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePurchase() async {
    _togglePreview();
  }

  // Simplified stock creation for accessories (no serial numbers)
  Future<void> _confirmAndSavePurchase() async {
    if (_formKey.currentState!.validate() &&
        _selectedSupplier != null &&
        _purchaseItems.isNotEmpty) {
      for (var i = 0; i < _purchaseItems.length; i++) {
        final item = _purchaseItems[i];

        if (item.productId == null ||
            item.quantity == null ||
            item.rate == null) {
          _showErrorSnackbar(
            'Please fill all required fields for item ${i + 1}',
          );
          return;
        }
      }

      try {
        final user = Provider.of<AuthProvider>(context, listen: false).user;

        if (user == null) {
          _showErrorSnackbar('User not authenticated');
          return;
        }

        // Create purchase data
        final purchaseData = {
          'supplierId': _selectedSupplier!['id'],
          'supplierName': _selectedSupplier!['name'],
          'invoiceNumber': _invoiceController.text.trim(),
          'purchaseDate': _selectedDate,
          'subtotal': _subtotal,
          'gstAmount': _gstAmount,
          'totalDiscount': _totalDiscount,
          'roundOff': _roundOff,
          'totalAmount': _totalAmount,
          'notes': _notesController.text.trim(),
          'items': _purchaseItems.map((item) => item.toMap()).toList(),
          'userId': user.uid,
          'userName': user.name ?? user.email,
          'shopId': user.shopId,
          'shopName': user.shopName,
          'createdAt': FieldValue.serverTimestamp(),
          'purchaseType': 'accessory',
        };

        final purchaseId = await _firestoreService.createPurchase(purchaseData);

        // Create accessory stock entries (simplified - no serial numbers)
        final List<Map<String, dynamic>> accessoryStockList = [];

        for (var i = 0; i < _purchaseItems.length; i++) {
          final item = _purchaseItems[i];

          // Create ONE stock entry with quantity (accessories don't need serial numbers)
          final accessoryStockData = {
            'createdAt': FieldValue.serverTimestamp(),
            'productName': item.productName ?? '',
            'productPrice': item.rate ?? 0,
            'shopId': user.shopId,
            'shopName': user.shopName,
            'status': 'available',
            'uploadedAt': FieldValue.serverTimestamp(),
            'uploadedBy': user.email,
            'uploadedById': user.uid,
            'purchaseId': purchaseId,
            'purchaseInvoice': _invoiceController.text.trim(),
            'supplierId': _selectedSupplier!['id'],
            'supplierName': _selectedSupplier!['name'],
            'productId': item.productId,
            // Removed hsnCode
            'quantity': item.quantity!.toInt(),
          };
          accessoryStockList.add(accessoryStockData);
        }

        // Add all accessory stock entries in batch
        if (accessoryStockList.isNotEmpty) {
          await _firestoreService.addMultipleAccessoryStock(accessoryStockList);
        }

        // Update accessory master records with new stock counts
        for (var i = 0; i < _purchaseItems.length; i++) {
          final item = _purchaseItems[i];
          if (item.productId != null) {
            // Update purchase rate if changed
            if (item.rate != null) {
              await _firestoreService.updateAccessoryPurchaseRate(
                item.productId!,
                item.rate!,
              );
            }

            // Removed HSN code update

            // Update total stock quantity in accessory master record
            await _firestoreService.updateAccessoryStock(
              item.productId!,
              item.quantity!.toInt(),
            );
          }
        }

        _showSuccessSnackbar(
          'Purchase saved successfully with ${accessoryStockList.length} item(s)',
        );

        // Navigate to purchase history
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => PurchaseHistoryScreen()),
          (route) => false,
        );
      } catch (e) {
        _showErrorSnackbar('Error saving purchase: $e');
      }
    } else {
      _showErrorSnackbar('Please fill all required fields');
    }
  }
}
