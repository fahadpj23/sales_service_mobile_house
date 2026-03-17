import 'package:flutter/material.dart';
import 'package:sales_stock/models/purchase_item.dart';
import 'package:sales_stock/screens/user/purchase/purchase_history_screen.dart';
import 'package:sales_stock/services/firestore_service.dart';
import 'package:sales_stock/screens/user/purchase/create_purchase_form.dart';
import 'package:sales_stock/screens/user/purchase/create_purchase_preview.dart';
import 'package:sales_stock/screens/user/purchase/create_purchase_scanner.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../../../providers/auth_provider.dart';
import '../../../models/user_model.dart';

class CreateTvPurchaseScreen extends StatefulWidget {
  final Map<String, dynamic>? supplier;

  const CreateTvPurchaseScreen({Key? key, this.supplier}) : super(key: key);

  @override
  State<CreateTvPurchaseScreen> createState() => _CreateTvPurchaseScreenState();
}

class _CreateTvPurchaseScreenState extends State<CreateTvPurchaseScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Color _primaryGreen = const Color(0xFF2E7D32);
  final Color _lightGreen = const Color(0xFF4CAF50);
  final Color _backgroundColor = const Color(0xFFF5F9F5);

  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController();
  final _invoiceController = TextEditingController();
  final _notesController = TextEditingController();
  final _tvSearchController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _tvModels = [];
  List<Map<String, dynamic>> _filteredTvModels = [];
  Map<String, dynamic>? _selectedSupplier;
  List<PurchaseItem> _purchaseItems = [];

  double _subtotal = 0.0;
  double _gstAmount = 0.0;
  double _totalAmount = 0.0;
  double _totalDiscount = 0.0;
  double _roundOff = 0.0;
  bool _isSearching = false;
  int? _currentScanItemIndex;
  int? _currentScanSerialIndex;
  Map<int, bool> _showEditSections = {};
  bool _showPreview = false;
  Map<int, List<String>> _itemSerials = {};

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
    _fetchTvModels();
    if (widget.supplier != null) {
      _selectedSupplier = widget.supplier;
      _supplierController.text = widget.supplier!['name'] ?? '';
    }
    _addNewItem();
  }

  @override
  void dispose() {
    _tvSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuppliers() async {
    _suppliers = await _firestoreService.getSuppliers();
    setState(() {});
  }

  Future<void> _fetchTvModels() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tvModels')
          .orderBy('modelName')
          .get();

      _tvModels = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _filteredTvModels = List.from(_tvModels);
    } catch (e) {
      print('Error fetching TV models: $e');
      _tvModels = [];
      _filteredTvModels = [];
    }
    setState(() {});
  }

  void _filterTvModels(String query) {
    if (query.isEmpty) {
      _filteredTvModels = List.from(_tvModels);
    } else {
      final searchQuery = query.toLowerCase().trim();
      final searchWords = searchQuery.split(' ');

      _filteredTvModels = _tvModels.where((tvModel) {
        final modelName = (tvModel['modelName'] ?? '').toString().toLowerCase();
        final brand = (tvModel['brand'] ?? '').toString().toLowerCase();
        final combinedText = '$modelName $brand';

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
              primary: _primaryGreen,
              onPrimary: Colors.white,
              onSurface: Colors.grey.shade800,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _primaryGreen),
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
      _itemSerials[newIndex] = [];

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

        final newPurchaseItems = <PurchaseItem>[];
        final newShowEditSections = <int, bool>{};
        final newItemSerials = <int, List<String>>{};

        for (int i = 0; i < _purchaseItems.length; i++) {
          newPurchaseItems.add(_purchaseItems[i]);

          if (i < index) {
            newShowEditSections[i] = _showEditSections[i] ?? false;
            newItemSerials[i] = _itemSerials[i] ?? [];
          } else {
            newShowEditSections[i] = _showEditSections[i + 1] ?? false;
            newItemSerials[i] = _itemSerials[i + 1] ?? [];
          }
        }

        _purchaseItems = newPurchaseItems;
        _showEditSections = newShowEditSections;
        _itemSerials = newItemSerials;

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

  bool _isValidSerialNumber(String serial) {
    final trimmed = serial.trim();
    return trimmed.isNotEmpty && trimmed.length >= 3 && trimmed.length <= 50;
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

  void _updateItemSerial(int itemIndex, int serialIndex, String value) {
    setState(() {
      if (_itemSerials[itemIndex] == null) {
        _itemSerials[itemIndex] = [];
      }
      while (_itemSerials[itemIndex]!.length <= serialIndex) {
        _itemSerials[itemIndex]!.add('');
      }
      _itemSerials[itemIndex]![serialIndex] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Create TV Purchase'),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          CreatePurchaseForm(
            primaryGreen: _primaryGreen,
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
            itemImeis: _itemSerials,
            showEditSections: _showEditSections,
            subtotal: _subtotal,
            totalDiscount: _totalDiscount,
            gstAmount: _gstAmount,
            roundOff: _roundOff,
            totalAmount: _totalAmount,
            addNewItem: _addNewItem,
            toggleEditSection: _toggleEditSection,
            removeItem: _removeItem,
            showProductSelection: _showTvSelection,
            showScannerDialog: _showScannerDialog,
            showManualSerialEntry: _showManualSerialEntry,
            onSerialScanned: _onScanComplete,
            isValidSerialNumber: _isValidSerialNumber,
            togglePreview: _togglePreview,
            savePurchase: _savePurchase,
            updateItemQuantity: _updateItemQuantity,
            updateItemRate: _updateItemRate,
            updateItemDiscount: _updateItemDiscount,
            updateItemSerial: _updateItemSerial,
          ),
          if (_showPreview)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: CreatePurchasePreview(
                primaryGreen: _primaryGreen,
                lightGreen: _lightGreen,
                selectedDate: _selectedDate,
                selectedSupplier: _selectedSupplier,
                invoiceController: _invoiceController,
                purchaseItems: _purchaseItems,
                itemImeis: _itemSerials,
                subtotal: _subtotal,
                totalDiscount: _totalDiscount,
                gstAmount: _gstAmount,
                roundOff: _roundOff,
                totalAmount: _totalAmount,
                togglePreview: _togglePreview,
                confirmAndSavePurchase: _confirmAndSavePurchase,
                isValidSerialNumber: _isValidSerialNumber,
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
        final currentSerials = _itemSerials[index] ?? [];
        final requiredCount = quantity.toInt();

        if (currentSerials.length > requiredCount) {
          _itemSerials[index] = currentSerials.sublist(0, requiredCount);
        }
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
                color: _primaryGreen,
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

  Future<void> _showTvSelection(int itemIndex) async {
    final selectedTv = await showModalBottomSheet<Map<String, dynamic>>(
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
                      color: _primaryGreen,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select TV Model',
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
                            _tvSearchController.clear();
                            _filterTvModels('');
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
                        controller: _tvSearchController,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search by TV model or brand...',
                          hintStyle: const TextStyle(fontSize: 11),
                          prefixIcon: Icon(
                            Icons.search,
                            color: _primaryGreen,
                            size: 18,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          suffixIcon: _tvSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    _tvSearchController.clear();
                                    _filterTvModels('');
                                    setSheetState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          _filterTvModels(value);
                          setSheetState(() {});
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: _filteredTvModels.isEmpty
                        ? _buildEmptyTvState(setSheetState)
                        : _buildTvList(setSheetState),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (selectedTv != null) {
      _handleTvSelection(itemIndex, selectedTv);
    } else {
      _tvSearchController.clear();
      _filterTvModels('');
    }
  }

  Widget _buildEmptyTvState(StateSetter setSheetState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _tvSearchController.text.isEmpty ? Icons.tv_off : Icons.search_off,
          size: 60,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 16),
        Text(
          _tvSearchController.text.isEmpty
              ? 'No TV models available'
              : 'TV model not found',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _tvSearchController.text.isEmpty
              ? 'Add your first TV model to continue'
              : 'Add "${_tvSearchController.text}" as new TV model',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ElevatedButton.icon(
            onPressed: () async {
              final searchText = _tvSearchController.text;
              Navigator.pop(context);
              await _showAddTvDialog(preFilledSearch: searchText);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _tvSearchController.text.isEmpty
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
              'Add New TV Model',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTvList(StateSetter setSheetState) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Found ${_filteredTvModels.length} TV model${_filteredTvModels.length != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              TextButton.icon(
                onPressed: () async {
                  final searchText = _tvSearchController.text;
                  Navigator.pop(context);
                  await _showAddTvDialog(preFilledSearch: searchText);
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
            itemCount: _filteredTvModels.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tvModel = _filteredTvModels[index];
              return _buildTvListItem(tvModel, setSheetState);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTvListItem(
    Map<String, dynamic> tvModel,
    StateSetter setSheetState,
  ) {
    final modelName = tvModel['modelName'] ?? 'Unnamed TV';
    final brand = tvModel['brand'] ?? '';
    final price = tvModel['price'] ?? 0.0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _lightGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.tv, size: 20, color: _lightGreen),
      ),
      title: Text(
        modelName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (brand.isNotEmpty)
            Text(
              brand,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                '₹${price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _primaryGreen,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'GST: 18%',
                  style: TextStyle(
                    fontSize: 9,
                    color: const Color(0xFF2196F3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _lightGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.add, size: 16, color: Colors.green),
      ),
      onTap: () {
        _tvSearchController.clear();
        _filterTvModels('');
        Navigator.pop(context, tvModel);
      },
    );
  }

  void _handleTvSelection(int itemIndex, Map<String, dynamic> tvModel) {
    _tvSearchController.clear();
    _filterTvModels('');

    setState(() {
      _purchaseItems[itemIndex].productId = tvModel['id'] ?? '';
      _purchaseItems[itemIndex].productName =
          tvModel['modelName'] ?? 'Unnamed TV';
      _purchaseItems[itemIndex].brand = tvModel['brand'] ?? '';
      _purchaseItems[itemIndex].rate = (tvModel['price'] ?? 0).toDouble();

      for (var key in _showEditSections.keys) {
        _showEditSections[key] = false;
      }
      _showEditSections[itemIndex] = true;

      _calculateTotals();
    });
  }

  Future<void> _showAddTvDialog({String preFilledSearch = ''}) async {
    final brandController = TextEditingController();
    final modelNameController = TextEditingController();
    final priceController = TextEditingController();

    final List<String> brandList = [
      'Samsung',
      'LG',
      'Sony',
      'Mi',
      'OnePlus',
      'Realme',
      'TCL',
      'Thomson',
      'Panasonic',
      'Haier',
      'VU',
      'Motorola',
      'Nokia',
      'Hisense',
      'Toshiba',
    ];
    String selectedBrand = '';

    if (preFilledSearch.isNotEmpty) {
      modelNameController.text = preFilledSearch;
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
                      color: _primaryGreen,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tv, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add New TV Model',
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
                        _buildFormSection(
                          label: 'Brand *',
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedBrand.isNotEmpty
                                    ? selectedBrand
                                    : null,
                                hint: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    'Select Brand',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: _primaryGreen,
                                  size: 18,
                                ),
                                isExpanded: true,
                                items: [
                                  ...brandList.map((brand) {
                                    return DropdownMenuItem(
                                      value: brand,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          brand,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  const DropdownMenuItem(
                                    value: 'other',
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.add, size: 14),
                                          SizedBox(width: 6),
                                          Text(
                                            'Add New Brand',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (String? newValue) {
                                  if (newValue == 'other') {
                                    _showAddBrandDialog().then((newBrand) {
                                      if (newBrand != null &&
                                          newBrand.isNotEmpty) {
                                        setState(() {
                                          brandList.add(newBrand);
                                          selectedBrand = newBrand;
                                        });
                                      }
                                    });
                                  } else {
                                    setState(() {
                                      selectedBrand = newValue ?? '';
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFormSection(
                          label: 'Model Name *',
                          child: TextField(
                            controller: modelNameController,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'e.g., Mi TV 5X 55" 4K',
                              hintStyle: const TextStyle(fontSize: 11),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: Icon(
                                Icons.tv,
                                color: _primaryGreen,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFormSection(
                          label: 'Price *',
                          child: TextField(
                            controller: priceController,
                            style: const TextStyle(fontSize: 12),
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter price',
                              hintStyle: const TextStyle(fontSize: 11),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixText: '₹ ',
                              prefixIcon: Icon(
                                Icons.currency_rupee,
                                color: _primaryGreen,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildPriceInfoRow(
                                'Price:',
                                priceController.text.isNotEmpty
                                    ? '₹${double.tryParse(priceController.text)?.toStringAsFixed(2) ?? '0.00'}'
                                    : '₹0.00',
                              ),
                              _buildPriceInfoRow(
                                'GST (18%):',
                                priceController.text.isNotEmpty
                                    ? '₹${(double.tryParse(priceController.text)! * 0.18).toStringAsFixed(2)}'
                                    : '₹0.00',
                              ),
                              const Divider(height: 12),
                              _buildPriceInfoRow(
                                'Total with GST:',
                                priceController.text.isNotEmpty
                                    ? '₹${(double.tryParse(priceController.text)! * 1.18).toStringAsFixed(2)}'
                                    : '₹0.00',
                                isBold: true,
                                color: _primaryGreen,
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
                              if (_validateTvForm(
                                selectedBrand,
                                modelNameController,
                                priceController,
                              )) {
                                try {
                                  await _saveTvModel(
                                    selectedBrand,
                                    modelNameController,
                                    priceController,
                                  );
                                  Navigator.pop(context);
                                } catch (e) {
                                  // Error handled in _saveTvModel
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Save TV Model',
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

  Widget _buildPriceInfoRow(
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

  bool _validateTvForm(
    String selectedBrand,
    TextEditingController modelNameController,
    TextEditingController priceController,
  ) {
    if (selectedBrand.isEmpty) {
      _showErrorSnackbar('Please select a brand');
      return false;
    }
    if (modelNameController.text.isEmpty) {
      _showErrorSnackbar('Please enter model name');
      return false;
    }
    if (priceController.text.isEmpty) {
      _showErrorSnackbar('Please enter price');
      return false;
    }

    final price = double.tryParse(priceController.text);
    if (price == null || price <= 0) {
      _showErrorSnackbar('Please enter a valid price');
      return false;
    }

    return true;
  }

  Future<void> _saveTvModel(
    String selectedBrand,
    TextEditingController modelNameController,
    TextEditingController priceController,
  ) async {
    try {
      final tvModelData = {
        'brand': selectedBrand,
        'modelName': modelNameController.text.trim(),
        'price': double.parse(priceController.text),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('tvModels').add(tvModelData);

      await _fetchTvModels();

      _tvSearchController.clear();
      _filterTvModels('');

      _showSuccessSnackbar('TV model added successfully');
    } catch (e) {
      _showErrorSnackbar('Error adding TV model: $e');
    }
  }

  Future<String?> _showAddBrandDialog() async {
    final brandController = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add New Brand',
          style: TextStyle(color: _primaryGreen, fontSize: 14),
        ),
        content: TextField(
          controller: brandController,
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Enter brand name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              final brand = brandController.text.trim();
              if (brand.isNotEmpty) {
                Navigator.pop(context, brand);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Add',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showScannerDialog(int itemIndex, {int? imeiIndex}) async {
    _currentScanItemIndex = itemIndex;
    _currentScanSerialIndex = imeiIndex;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatePurchaseScanner(
          itemIndex: itemIndex,
          imeiIndex: imeiIndex,
          currentSerial:
              imeiIndex != null &&
                  (_itemSerials[itemIndex]?.length ?? 0) > imeiIndex
              ? _itemSerials[itemIndex]![imeiIndex]
              : null,
        ),
      ),
    );

    if (result != null) {
      _onScanComplete(result);
    }
  }

  Future<void> _showManualSerialEntry(int itemIndex, {int? imeiIndex}) async {
    final serialController = TextEditingController(
      text:
          imeiIndex != null &&
              (_itemSerials[itemIndex]?.length ?? 0) > imeiIndex
          ? _itemSerials[itemIndex]![imeiIndex]
          : '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          imeiIndex != null
              ? 'Edit Serial ${imeiIndex + 1}'
              : 'Enter Serial Number',
          style: TextStyle(color: const Color(0xFFE91E63), fontSize: 14),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter Serial Number for TV inventory tracking',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: serialController,
              maxLength: 50,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Enter Serial number...',
                hintStyle: const TextStyle(fontSize: 11),
                border: const OutlineInputBorder(),
                counterText: '',
                prefixIcon: Icon(
                  Icons.confirmation_number,
                  color: _primaryGreen,
                  size: 18,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => serialController.clear(),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: _primaryGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'TV Serial Number (3-50 characters)',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (imeiIndex != null)
            TextButton(
              onPressed: () {
                setState(() {
                  if ((_itemSerials[itemIndex]?.length ?? 0) > imeiIndex) {
                    _itemSerials[itemIndex]!.removeAt(imeiIndex);
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Serial removed',
                      style: TextStyle(fontSize: 12),
                    ),
                    backgroundColor: const Color(0xFFFFB300),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE53935),
              ),
              child: const Text('Remove', style: TextStyle(fontSize: 12)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              final serial = serialController.text.trim();
              if (_isValidSerialNumber(serial)) {
                Navigator.pop(context);
                setState(() {
                  if (imeiIndex != null) {
                    if ((_itemSerials[itemIndex]?.length ?? 0) > imeiIndex) {
                      _itemSerials[itemIndex]![imeiIndex] = serial;
                    }
                  } else {
                    _itemSerials[itemIndex] ??= [];
                    _itemSerials[itemIndex]!.add(serial);
                  }
                });
                _showSuccessSnackbar(
                  'Serial saved: ${serial.substring(0, math.min(serial.length, 12))}...',
                );
              } else {
                _showErrorSnackbar(
                  'Serial must be 3-50 characters (${serial.length}/50)',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              imeiIndex != null ? 'Update Serial' : 'Save Serial',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _onScanComplete(String scannedValue) {
    if (_currentScanItemIndex != null) {
      final trimmedValue = scannedValue.trim();

      if (!_isValidSerialNumber(trimmedValue)) {
        _showErrorSnackbar(
          'Invalid Serial. Must be 3-50 characters. Scanned: ${trimmedValue.substring(0, math.min(trimmedValue.length, 20))}...',
        );
        return;
      }

      setState(() {
        if (_currentScanSerialIndex != null) {
          if ((_itemSerials[_currentScanItemIndex!]?.length ?? 0) >
              _currentScanSerialIndex!) {
            _itemSerials[_currentScanItemIndex!]![_currentScanSerialIndex!] =
                trimmedValue;
          }
        } else {
          _itemSerials[_currentScanItemIndex!] ??= [];
          _itemSerials[_currentScanItemIndex!]!.add(trimmedValue);
        }
      });

      _showSuccessSnackbar('Serial scanned successfully ✓');
    }
    _currentScanItemIndex = null;
    _currentScanSerialIndex = null;
  }

  Future<void> _savePurchase() async {
    _togglePreview();
  }

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

        final requiredSerialCount = item.quantity!.toInt();
        final itemSerials = _itemSerials[i] ?? [];

        if (itemSerials.length != requiredSerialCount) {
          _showErrorSnackbar(
            'Item ${i + 1}: Quantity is $requiredSerialCount, but you have ${itemSerials.length} Serial Numbers. Please add ${requiredSerialCount - itemSerials.length} more.',
          );
          return;
        }

        for (var j = 0; j < requiredSerialCount; j++) {
          final serial = itemSerials[j];
          if (serial.isEmpty || !_isValidSerialNumber(serial)) {
            _showErrorSnackbar(
              'Item ${i + 1}, Serial ${j + 1}: Invalid serial number (must be 3-50 characters)',
            );
            return;
          }
        }
      }

      try {
        final user = Provider.of<AuthProvider>(context, listen: false).user;

        if (user == null) {
          _showErrorSnackbar('User not authenticated');
          return;
        }

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
          'items': _purchaseItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final itemMap = item.toMap();
            itemMap['serials'] = _itemSerials[index] ?? [];
            return itemMap;
          }).toList(),
          'userId': user.uid,
          'userName': user.name ?? user.email,
          'shopId': user.shopId,
          'shopName': user.shopName,
          'createdAt': FieldValue.serverTimestamp(),
        };

        final purchaseRef = await FirebaseFirestore.instance
            .collection('tvPurchase')
            .add(purchaseData);
        final purchaseId = purchaseRef.id;

        final List<Map<String, dynamic>> tvStockList = [];

        for (var i = 0; i < _purchaseItems.length; i++) {
          final item = _purchaseItems[i];
          final itemSerials = _itemSerials[i] ?? [];

          for (var j = 0; j < itemSerials.length; j++) {
            final serial = itemSerials[j];

            final tvStockData = {
              'createdAt': FieldValue.serverTimestamp(),
              'serialNumber': serial,
              'modelBrand': item.brand ?? '',
              'modelName': item.productName ?? '',
              'modelPrice': item.rate ?? 0,
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
            };

            tvStockList.add(tvStockData);
          }
        }

        if (tvStockList.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (var tvStock in tvStockList) {
            final docRef = FirebaseFirestore.instance
                .collection('tvStock')
                .doc();
            batch.set(docRef, tvStock);
          }
          await batch.commit();
        }

        for (var i = 0; i < _purchaseItems.length; i++) {
          final item = _purchaseItems[i];
          if (item.productId != null) {
            await FirebaseFirestore.instance
                .collection('tvModels')
                .doc(item.productId)
                .update({'updatedAt': FieldValue.serverTimestamp()});
          }
        }

        _showSuccessSnackbar(
          'TV Purchase saved successfully with ${tvStockList.length} items',
        );

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
