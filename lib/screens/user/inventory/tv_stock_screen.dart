import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'tv_bill_form.dart';
import '../../../providers/auth_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../../../models/add_tv_stock_modal.dart';

class TvStockScreen extends StatefulWidget {
  const TvStockScreen({super.key});

  @override
  State<TvStockScreen> createState() => _TvStockScreenState();
}

class _TvStockScreenState extends State<TvStockScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  String _searchQuery = '';
  late TextEditingController _searchController;

  String? _selectedBrand;
  String? _selectedModel;
  String? _newModelName;
  double? _newModelPrice;
  int? _quantity;
  List<String> _serialNumbers = [];
  final List<TextEditingController> _serialControllers = [];

  final List<String> _brands = [
    'Mi',
    'gadzo',
    'Mr.plus',
    'Samsung',
    'LG',
    'Sony',
    'TCL',
    'Other',
  ];
  final Map<String, List<Map<String, dynamic>>> _modelsByBrand = {};
  bool _isLoading = false;
  bool _showAddModelForm = false;
  bool _showAddStockModal = false;

  List<Map<String, dynamic>> _shops = [];
  Map<String, dynamic>? _selectedTvForAction;
  String _selectedAction = 'sell';

  late TextEditingController _modelSearchController;
  List<Map<String, dynamic>> _filteredModels = [];

  double? _originalModelPrice;
  bool _showPriceChangeOption = false;
  late TextEditingController _priceChangeController;

  late TextEditingController _newModelNameController;
  late TextEditingController _newModelPriceController;

  String? _modalError;
  String? _modalSuccess;

  late TabController _tabController;
  int _currentTabIndex = 0;
  final List<String> _tabTitles = ['Available', 'Sold', 'Returned'];

  final FocusNode _searchFocusNode = FocusNode();

  Map<String, dynamic>? _foundInSoldStock;
  bool _showingSoldStockWarning = false;

  List<Map<String, dynamic>> _filterStocksBySearch(
    List<QueryDocumentSnapshot> stocks,
  ) {
    if (_searchQuery.isEmpty) {
      return stocks.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {...data, 'id': doc.id};
      }).toList();
    }

    final query = _searchQuery.toLowerCase().trim();
    final result = <Map<String, dynamic>>[];

    for (final doc in stocks) {
      final data = doc.data() as Map<String, dynamic>;
      final modelName = (data['modelName'] as String? ?? '').toLowerCase();
      final modelBrand = (data['modelBrand'] as String? ?? '').toLowerCase();
      final serialNumber = (data['serialNumber'] as String? ?? '')
          .toLowerCase();
      final combinedText = '$modelName $modelBrand';

      final searchWords = query.split(' ').where((w) => w.isNotEmpty).toList();

      bool allWordsFound = true;

      for (final word in searchWords) {
        final variations = <String>[word];

        if (word.contains('/')) {
          variations.add(word.replaceAll('/', ' '));
          variations.add(word.replaceAll('/', ''));
          variations.add(word.replaceAll('/', 'inch/'));
          variations.add(word.replaceAll('/', '/inch'));
        }

        if (word.endsWith('inch') && word.length > 4) {
          variations.add(word.substring(0, word.length - 4));
        }

        bool wordFound = false;
        for (final variation in variations) {
          if (combinedText.contains(variation)) {
            wordFound = true;
            break;
          }
        }

        if (!wordFound && serialNumber.contains(word)) {
          wordFound = true;
        }

        if (!wordFound) {
          allWordsFound = false;
          break;
        }
      }

      if (allWordsFound) {
        result.add({...data, 'id': doc.id});
      }
    }

    return result;
  }

  Future<Map<String, dynamic>?> _checkSerialInSoldStock(
    String serialNumber,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      final currentShopId = user?.shopId;

      if (currentShopId == null) return null;

      final snapshot = await FirebaseFirestore.instance
          .collection('tvStock')
          .where('shopId', isEqualTo: currentShopId)
          .where('serialNumber', isEqualTo: serialNumber)
          .where('status', isEqualTo: 'sold')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return {...data, 'id': snapshot.docs.first.id};
      }
      return null;
    } catch (e) {
      print('Error checking sold stock: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _modelSearchController = TextEditingController();
    _priceChangeController = TextEditingController();
    _newModelNameController = TextEditingController();
    _newModelPriceController = TextEditingController();

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
        _foundInSoldStock = null;
        _showingSoldStockWarning = false;
      });
    });
    _loadExistingModels();
    _loadShops();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocusNode.dispose();
    _disposeAllControllers();
    super.dispose();
  }

  void _disposeAllControllers() {
    _searchController.dispose();
    _modelSearchController.dispose();
    _priceChangeController.dispose();
    _newModelNameController.dispose();
    _newModelPriceController.dispose();
    _disposeSerialControllers();
  }

  void _disposeSerialControllers() {
    for (var controller in _serialControllers) {
      controller.dispose();
    }
    _serialControllers.clear();
  }

  Future<void> _loadShops() async {
    try {
      final snapshot = await _firestore.collection('Mobile_house_Shops').get();
      setState(() {
        _shops = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['shopName'] ?? 'Unknown Shop',
            'address': data['address'] ?? '',
            'phone': data['phoneNumber'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      _showError('Error loading shops: $e');
    }
  }

  Future<void> _loadExistingModels() async {
    try {
      setState(() => _isLoading = true);

      final snapshot = await _firestore.collection('tvModels').get();

      _modelsByBrand.clear();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final brand = data['brand'] as String?;
        final modelName = data['modelName'] as String?;
        final price = data['price'];

        if (brand != null && modelName != null && price != null) {
          double? priceDouble;
          if (price is int) {
            priceDouble = price.toDouble();
          } else if (price is double) {
            priceDouble = price;
          } else if (price is String) {
            priceDouble = double.tryParse(price);
          }

          if (priceDouble != null) {
            if (!_brands.contains(brand)) {
              _brands.add(brand);
            }

            if (!_modelsByBrand.containsKey(brand)) {
              _modelsByBrand[brand] = [];
            }

            final existingModelIndex = _modelsByBrand[brand]!.indexWhere(
              (m) => m['modelName'] == modelName,
            );

            if (existingModelIndex == -1) {
              _modelsByBrand[brand]!.add({
                'id': doc.id,
                'modelName': modelName,
                'price': priceDouble,
              });
            } else {
              _modelsByBrand[brand]![existingModelIndex]['price'] = priceDouble;
            }
          }
        }
      }

      _brands.sort();

      for (var brand in _modelsByBrand.keys) {
        _modelsByBrand[brand]!.sort(
          (a, b) =>
              (a['modelName'] as String).compareTo(b['modelName'] as String),
        );
      }

      setState(() {});
    } catch (e) {
      _showError('Failed to load models: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleModelSelection(String? value) {
    if (value == 'add_new') {
      setState(() {
        _showAddModelForm = true;
        _selectedModel = null;
        _showPriceChangeOption = false;
        _priceChangeController.clear();
        _modelSearchController.clear();
        _clearModalMessages();
        _newModelNameController.clear();
        _newModelPriceController.clear();
      });
    } else {
      setState(() {
        _selectedModel = value;
        _showAddModelForm = false;
        _modelSearchController.text = value ?? '';
        _clearModalMessages();

        if (_selectedBrand != null && value != null) {
          final models = _modelsByBrand[_selectedBrand!];
          if (models != null) {
            final model = models.firstWhere(
              (m) => m['modelName'] == value,
              orElse: () => <String, dynamic>{},
            );

            if (model.isNotEmpty) {
              final price = model['price'];
              _originalModelPrice = price is double
                  ? price
                  : price is int
                  ? price.toDouble()
                  : 0.0;
              _showPriceChangeOption = true;
              _priceChangeController.text =
                  _originalModelPrice?.toStringAsFixed(0) ?? '';
            }
          }
        }
      });
    }
  }

  void _cancelAddNewModel() {
    setState(() {
      _showAddModelForm = false;
      _newModelName = null;
      _newModelPrice = null;
      _modelSearchController.clear();
      _newModelNameController.clear();
      _newModelPriceController.clear();
      _clearModalMessages();
    });
  }

  void _handleQuantityChange(String value) {
    final qty = int.tryParse(value);
    if (qty != null && qty > 0) {
      _disposeSerialControllers();

      setState(() {
        _quantity = qty;
        _serialNumbers = List.filled(qty, '');

        for (int i = 0; i < qty; i++) {
          _serialControllers.add(TextEditingController());
        }
        _clearModalMessages();
      });
    } else if (value.isEmpty) {
      _disposeSerialControllers();
      setState(() {
        _quantity = null;
        _serialNumbers = [];
        _clearModalMessages();
      });
    }
  }

  Future<void> _saveNewModel() async {
    if (_selectedBrand == null) {
      _showModalError('Please select a brand');
      return;
    }

    final modelName = _newModelNameController.text.trim();
    final priceText = _newModelPriceController.text.trim();

    if (modelName.isEmpty) {
      _showModalError('Please enter model name');
      return;
    }

    if (priceText.isEmpty) {
      _showModalError('Please enter model price');
      return;
    }

    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      _showModalError('Please enter valid price');
      return;
    }

    try {
      setState(() => _isLoading = true);

      final newModel = {
        'brand': _selectedBrand!,
        'modelName': modelName,
        'price': price,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('tvModels').add(newModel);

      if (!_modelsByBrand.containsKey(_selectedBrand!)) {
        _modelsByBrand[_selectedBrand!] = [];
      }

      final existingModelIndex = _modelsByBrand[_selectedBrand!]!.indexWhere(
        (m) => m['modelName'] == modelName,
      );

      if (existingModelIndex == -1) {
        _modelsByBrand[_selectedBrand!]!.add({
          'id': 'temp',
          'modelName': modelName,
          'price': price,
        });

        _modelsByBrand[_selectedBrand!]!.sort(
          (a, b) =>
              (a['modelName'] as String).compareTo(b['modelName'] as String),
        );
      }

      if (!mounted) return;

      setState(() {
        _showAddModelForm = false;
        _selectedModel = modelName;
        _originalModelPrice = price;
        _clearModalMessages();
        _showModalSuccess('Model "$modelName" added successfully!');
        _newModelNameController.clear();
        _newModelPriceController.clear();
      });
    } catch (e) {
      _showModalError('Failed to add model: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveStock() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _clearModalMessages();
      });

      if (_selectedBrand == null || _selectedBrand!.isEmpty) {
        _showModalError('Please select a brand');
        return;
      }

      String modelName;
      double modelPrice;
      String? modelId;

      if (_showAddModelForm) {
        final newModelName = _newModelNameController.text.trim();
        final newPriceText = _newModelPriceController.text.trim();

        if (newModelName.isEmpty) {
          _showModalError('Please enter model name');
          return;
        }

        if (newPriceText.isEmpty) {
          _showModalError('Please enter model price');
          return;
        }

        final newPrice = double.tryParse(newPriceText);
        if (newPrice == null || newPrice <= 0) {
          _showModalError('Please enter valid price');
          return;
        }

        modelName = newModelName;
        modelPrice = newPrice;
        await _saveNewModel();
        if (_selectedModel == null) {
          _showModalError('Model not selected after creation');
          return;
        }
      } else {
        if (_selectedModel == null || _selectedModel!.isEmpty) {
          _showModalError('Please select a model');
          return;
        }

        final models = _modelsByBrand[_selectedBrand!];
        if (models == null || models.isEmpty) {
          _showModalError('No models found for selected brand');
          return;
        }

        final model = models.firstWhere(
          (m) => m['modelName'] == _selectedModel,
          orElse: () => <String, dynamic>{},
        );

        if (model.isEmpty) {
          _showModalError('Selected model not found');
          return;
        }

        modelName = model['modelName'] as String;
        final modelPriceTemp = model['price'];
        modelId = model['id'] as String?;

        if (_showPriceChangeOption && _priceChangeController.text.isNotEmpty) {
          final newPrice = double.tryParse(_priceChangeController.text);
          if (newPrice != null && newPrice > 0) {
            modelPrice = newPrice;
            if (modelId != null && modelId != 'temp') {
              await _firestore.collection('tvModels').doc(modelId).update({
                'price': modelPrice,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } else {
            modelPrice = modelPriceTemp is int
                ? modelPriceTemp.toDouble()
                : modelPriceTemp as double;
          }
        } else {
          modelPrice = modelPriceTemp is int
              ? modelPriceTemp.toDouble()
              : modelPriceTemp as double;
        }
      }

      if (_quantity == null || _quantity! <= 0) {
        _showModalError('Please enter valid quantity');
        return;
      }

      if (_serialNumbers.length != _quantity) {
        _showModalError('Serial numbers count does not match quantity');
        return;
      }

      for (int i = 0; i < _serialNumbers.length; i++) {
        final serial = _serialNumbers[i];
        if (serial.isEmpty) {
          _showModalError('Please enter serial number for item ${i + 1}');
          return;
        }

        if (serial.length < 8 || serial.length > 20) {
          _showModalError(
            'Serial ${i + 1} must be 8-20 characters (${serial.length} entered)',
          );
          return;
        }

        // UPDATED: Allow forward slash in serial numbers
        if (!RegExp(r'^[A-Za-z0-9/]+$').hasMatch(serial)) {
          _showModalError(
            'Serial ${i + 1} contains invalid characters. Use only letters, numbers, and forward slash (/)',
          );
          return;
        }
      }

      final uniqueSerials = _serialNumbers.toSet();
      if (uniqueSerials.length != _serialNumbers.length) {
        _showModalError('Duplicate serial numbers found in this batch');
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        _showModalError('User not authenticated. Please log in again.');
        return;
      }

      final shopId = user.shopId?.trim() ?? 'unknown_shop';
      final shopName =
          user.shopName?.trim() ?? user.name.trim() ?? 'Unknown Shop';
      final uploadedBy =
          user.email.trim() ?? user.name.trim() ?? 'Unknown User';
      final uploadedById = user.uid;

      try {
        for (String serial in _serialNumbers) {
          final existingQuery = await _firestore
              .collection('tvStock')
              .where('serialNumber', isEqualTo: serial)
              .limit(1)
              .get();

          if (existingQuery.docs.isNotEmpty) {
            _showModalError(
              'Serial number ${_formatSerialForDisplay(serial)} already exists in stock database',
            );
            return;
          }
        }
      } catch (e) {
        print('Serial check error: $e');
      }

      final savedCount = _serialNumbers.length;
      final batch = _firestore.batch();

      for (int i = 0; i < _serialNumbers.length; i++) {
        final serial = _serialNumbers[i].trim();

        final stockData = {
          'modelBrand': _selectedBrand!.trim(),
          'modelName': modelName,
          'modelPrice': modelPrice,
          'serialNumber': serial,
          'shopId': shopId,
          'shopName': shopName,
          'uploadedBy': uploadedBy,
          'uploadedById': uploadedById,
          'uploadedAt': FieldValue.serverTimestamp(),
          'status': 'available',
          'createdAt': FieldValue.serverTimestamp(),
        };

        final docRef = _firestore.collection('tvStock').doc();
        batch.set(docRef, stockData);
      }

      await batch.commit();

      if (!mounted) return;

      _showSuccess('Successfully added $savedCount TV(s) to stock!');

      _closeAddStockModal();
    } catch (e) {
      print('Save stock error: $e');
      _showModalError('Failed to save stock: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetAddStockForm() {
    setState(() {
      _selectedBrand = null;
      _selectedModel = null;
      _newModelName = null;
      _newModelPrice = null;
      _quantity = null;
      _serialNumbers = [];
      _showAddModelForm = false;
      _showPriceChangeOption = false;
      _originalModelPrice = null;
      _clearModalMessages();
    });

    _modelSearchController.clear();
    _priceChangeController.clear();
    _newModelNameController.clear();
    _newModelPriceController.clear();

    _disposeSerialControllers();

    if (_formKey.currentState != null) {
      _formKey.currentState!.reset();
    }
  }

  void _openAddStockModal() {
    _resetAddStockForm();
    setState(() {
      _showAddStockModal = true;
    });
  }

  void _closeAddStockModal() {
    setState(() {
      _showAddStockModal = false;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _resetAddStockForm();
      }
    });
  }

  Future<void> _markAsSold(String tvId, Map<String, dynamic> tvData) async {
    try {
      setState(() => _isLoading = true);

      await _firestore.collection('tvStock').doc(tvId).update({
        'status': 'sold',
        'soldAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _selectedTvForAction = null;
      });

      _showSuccess('TV marked as sold successfully!');
    } catch (e) {
      _showError('Failed to mark as sold: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _transferToShop(
    String tvId,
    Map<String, dynamic> tvData,
    String newShopId,
    String newShopName,
  ) async {
    try {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      final currentShopId = tvData['shopId'] as String? ?? '';
      final currentShopName = tvData['shopName'] as String? ?? 'Unknown Shop';

      await _firestore.collection('tvStock').doc(tvId).update({
        'shopId': newShopId,
        'shopName': newShopName,
        'transferredBy': user?.email ?? user?.name ?? 'Unknown',
        'transferredById': user?.uid ?? '',
        'transferredAt': FieldValue.serverTimestamp(),
        'previousShopId': currentShopId,
        'previousShopName': currentShopName,
      });

      setState(() {
        _selectedTvForAction = null;
      });

      _showSuccess('TV transferred to $newShopName successfully!');
    } catch (e) {
      _showError('Failed to transfer TV: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _returnTv(String tvId, Map<String, dynamic> tvData) async {
    try {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      final returnData = {
        'tvId': tvId,
        'modelBrand': tvData['modelBrand'] ?? 'Unknown',
        'modelName': tvData['modelName'] ?? 'Unknown',
        'modelPrice': tvData['modelPrice'] ?? 0,
        'serialNumber': tvData['serialNumber'] ?? 'N/A',
        'originalShopId': tvData['shopId'] ?? '',
        'originalShopName': tvData['shopName'] ?? 'Unknown Shop',
        'returnedBy': user?.email ?? user?.name ?? 'Unknown',
        'returnedById': user?.uid ?? '',
        'returnedAt': FieldValue.serverTimestamp(),
        'reason': 'returned_to_inventory',
        'status': 'returned',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('tvReturns').add(returnData);

      await _firestore.collection('tvStock').doc(tvId).delete();

      setState(() {
        _selectedTvForAction = null;
      });

      _showSuccess('TV returned successfully!');
    } catch (e) {
      _showError('Failed to return TV: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      if (status.isDenied) {
        final result = await Permission.camera.request();
        return result.isGranted;
      }
      return status.isGranted;
    } catch (e) {
      print('Permission error: $e');
      return false;
    }
  }

  Future<void> _openScannerForSerialField(int index) async {
    if (!await _checkCameraPermission()) {
      _showError('Camera permission required for scanning');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => OptimizedSerialScanner(
        title: 'Scan Serial ${index + 1}',
        description: 'Scan barcode for Serial ${index + 1}',
        onScanComplete: (serial) {
          if (index < _serialNumbers.length) {
            setState(() {
              _serialNumbers[index] = serial;
              if (index < _serialControllers.length) {
                _serialControllers[index].text = serial;
              }
            });
          }
        },
      ),
    );
  }

  Future<void> _openScannerForSearch() async {
    if (!await _checkCameraPermission()) {
      _showError('Camera permission required for scanning');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => OptimizedSerialScanner(
        title: 'Search Serial',
        description: 'Scan serial number to search in stock',
        onScanComplete: (serial) async {
          setState(() {
            _searchController.text = serial;
            _searchQuery = serial.toLowerCase();
          });

          setState(() {
            _foundInSoldStock = null;
            _showingSoldStockWarning = false;
          });

          final soldItem = await _checkSerialInSoldStock(serial);
          if (soldItem != null && mounted) {
            setState(() {
              _foundInSoldStock = soldItem;
              _showingSoldStockWarning = true;
            });
          }
        },
      ),
    );
  }

  void _clearModalMessages() {
    setState(() {
      _modalError = null;
      _modalSuccess = null;
    });
  }

  void _showModalError(String message) {
    if (!mounted) return;
    setState(() {
      _modalError = message;
      _modalSuccess = null;
      _isLoading = false;
    });
  }

  void _showModalSuccess(String message) {
    if (!mounted) return;
    setState(() {
      _modalSuccess = message;
      _modalError = null;
    });
  }

  void _showError(String message) {
    if (!mounted) return;

    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatSerialForDisplay(String serial) {
    if (serial.isEmpty) return '';

    // Check if serial contains forward slash
    if (serial.contains('/')) {
      // Keep the original format with slash
      return serial;
    }

    if (serial.length >= 12) {
      return '${serial.substring(0, 4)}-${serial.substring(4, 8)}-${serial.substring(8)}';
    } else if (serial.length >= 8) {
      return '${serial.substring(0, 4)}-${serial.substring(4)}';
    }
    return serial;
  }

  bool _isValidSerial(String serial) {
    if (serial.isEmpty) return false;
    if (serial.length < 8 || serial.length > 20) return false;
    // UPDATED: Allow forward slash in validation
    if (!RegExp(r'^[A-Za-z0-9/]+$').hasMatch(serial)) return false;
    return true;
  }

  Widget _buildSoldStockWarning() {
    if (_foundInSoldStock == null) {
      return const SizedBox.shrink();
    }

    final soldItem = _foundInSoldStock!;
    final modelName = soldItem['modelName'] as String? ?? 'Unknown';
    final modelBrand = soldItem['modelBrand'] as String? ?? 'Unknown';
    final soldAt = soldItem['soldAt'];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: Colors.orange.shade700,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Serial Found in Sold Stock',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modelName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Brand: $modelBrand',
                      style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                    ),
                    if (soldAt != null)
                      Text(
                        'Sold: ${_formatDate(soldAt)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 16),
                onPressed: () {
                  _showSoldItemDetails(soldItem);
                },
                tooltip: 'View details',
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'This serial number is not available in current stock (it has been sold).',
            style: TextStyle(fontSize: 10, color: Colors.orange.shade600),
          ),
        ],
      ),
    );
  }

  void _showSoldItemDetails(Map<String, dynamic> soldItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final modelName = soldItem['modelName'] as String? ?? 'Unknown';
        final modelBrand = soldItem['modelBrand'] as String? ?? 'Unknown';
        final serial = soldItem['serialNumber'] as String? ?? 'N/A';
        final price = soldItem['modelPrice'];
        final soldAt = soldItem['soldAt'];
        final uploadedAt = soldItem['uploadedAt'];
        final uploadedBy = soldItem['uploadedBy'] ?? 'Unknown';

        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shopping_cart_checkout,
                        color: Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SOLD TV DETAILS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This TV was previously sold',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailItem('Model Name', modelName),
                _buildDetailItem('Brand', modelBrand),
                _buildDetailItem('Serial', _formatSerialForDisplay(serial)),
                _buildDetailItem('Price', _formatPrice(price)),
                if (uploadedAt != null)
                  _buildDetailItem('Added Date', _formatDate(uploadedAt)),
                if (soldAt != null)
                  _buildDetailItem('Sold Date', _formatDate(soldAt)),
                _buildDetailItem('Uploaded By', uploadedBy.toString()),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.black),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelList() {
    final brandHasNoModels =
        !_modelsByBrand.containsKey(_selectedBrand!) ||
        (_modelsByBrand[_selectedBrand!] ?? []).isEmpty;

    final searchHasNoResults =
        _modelSearchController.text.isNotEmpty && _filteredModels.isEmpty;

    final shouldShowAddNew = brandHasNoModels || searchHasNoResults;

    return ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _filteredModels.length + (shouldShowAddNew ? 1 : 0),
      itemBuilder: (context, index) {
        if (shouldShowAddNew && index == _filteredModels.length) {
          return _buildAddNewModelTile();
        }

        final model = _filteredModels[index];
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
            _handleModelSelection(modelName);
          },
          trailing: _selectedModel == modelName
              ? const Icon(Icons.check, color: Colors.green, size: 16)
              : null,
        );
      },
    );
  }

  Widget _buildAddNewModelTile() {
    String subtitleText = '';

    if (!_modelsByBrand.containsKey(_selectedBrand!) ||
        (_modelsByBrand[_selectedBrand!] ?? []).isEmpty) {
      subtitleText = 'No models found for this brand';
    } else if (_modelSearchController.text.isNotEmpty &&
        _filteredModels.isEmpty) {
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
        _handleModelSelection('add_new');
      },
    );
  }

  Widget _buildModelSearchDropdown() {
    if (_selectedBrand == null) return const SizedBox();

    if (_showAddModelForm) {
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

    final models = _modelsByBrand[_selectedBrand!] ?? [];
    final searchText = _modelSearchController.text.toLowerCase();

    if (searchText.isNotEmpty) {
      _filteredModels = models.where((model) {
        final modelName = model['modelName'] as String? ?? '';
        return modelName.toLowerCase().contains(searchText);
      }).toList();
    } else {
      _filteredModels = List.from(models);
    }

    return Column(
      children: [
        TextField(
          controller: _modelSearchController,
          decoration: InputDecoration(
            labelText: 'Search Model',
            labelStyle: const TextStyle(fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _selectedModel != null && _selectedModel!.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      setState(() {
                        _selectedModel = null;
                        _modelSearchController.clear();
                        _showPriceChangeOption = false;
                        _originalModelPrice = null;
                        _priceChangeController.clear();
                        _clearModalMessages();
                      });
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            hintText: _selectedModel ?? 'Search or select model',
          ),
          style: const TextStyle(fontSize: 12, color: Colors.black),
          onChanged: (value) {
            setState(() {
              if (_selectedModel != null && value != _selectedModel) {
                _selectedModel = null;
                _showPriceChangeOption = false;
                _originalModelPrice = null;
                _priceChangeController.clear();
              }
              _clearModalMessages();
            });
          },
          onTap: () {
            if (_selectedModel != null &&
                _modelSearchController.text == _selectedModel) {
              _modelSearchController.clear();
              setState(() {
                _clearModalMessages();
              });
            }
          },
        ),
        const SizedBox(height: 8),

        if (_modalSuccess != null && _modalSuccess!.contains('Model added'))
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
                    _modalSuccess!,
                    style: const TextStyle(fontSize: 11, color: Colors.green),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),

        if (_selectedModel == null || _modelSearchController.text.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildModelList(),
          ),

        if (_selectedModel != null && _modelSearchController.text.isEmpty)
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
                        _selectedModel!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_originalModelPrice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Price: ${_formatPrice(_originalModelPrice)}',
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
                    setState(() {
                      _selectedModel = null;
                      _showPriceChangeOption = false;
                      _originalModelPrice = null;
                      _priceChangeController.clear();
                      _modelSearchController.clear();
                    });
                  },
                  tooltip: 'Change model',
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSerialInputField(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: index < _serialControllers.length
                  ? _serialControllers[index]
                  : null,
              decoration: InputDecoration(
                labelText: 'Serial Number ${index + 1} *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.qr_code, size: 18),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index < _serialNumbers.length &&
                        _serialNumbers[index].isNotEmpty)
                      Icon(
                        _serialNumbers[index].length >= 8
                            ? Icons.check_circle
                            : Icons.warning,
                        color: _serialNumbers[index].length >= 8
                            ? Colors.green
                            : Colors.orange,
                        size: 16,
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      onPressed: () => _openScannerForSerialField(index),
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
                if (index < _serialNumbers.length) {
                  setState(() {
                    _serialNumbers[index] = value;
                    _clearModalMessages();
                  });
                }
              },
              // UPDATED: Validator now accepts forward slash
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
                // Updated regex to allow forward slash
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
              IconButton(
                icon: const Icon(Icons.content_copy, size: 18),
                onPressed: () {
                  if (index < _serialNumbers.length &&
                      _serialNumbers[index].isNotEmpty) {
                    Clipboard.setData(
                      ClipboardData(text: _serialNumbers[index]),
                    );
                    _showSuccess('Serial copied to clipboard');
                  }
                },
                tooltip: 'Copy Serial',
                color: Colors.grey,
              ),
              if (index > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: () {
                    if (index > 0) {
                      final temp = _serialNumbers[index];
                      _serialNumbers[index] = _serialNumbers[index - 1];
                      _serialNumbers[index - 1] = temp;

                      final tempCtrl = _serialControllers[index];
                      _serialControllers[index] = _serialControllers[index - 1];
                      _serialControllers[index - 1] = tempCtrl;

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

  Widget _buildAddStockModal() {
    return AddTvStockModal(
      formKey: _formKey,
      selectedBrand: _selectedBrand,
      selectedModel: _selectedModel,
      newModelName: _newModelName,
      newModelPrice: _newModelPrice,
      quantity: _quantity,
      serialNumbers: _serialNumbers,
      serialControllers: _serialControllers,
      brands: _brands,
      modelsByBrand: _modelsByBrand,
      isLoading: _isLoading,
      showAddModelForm: _showAddModelForm,
      showPriceChangeOption: _showPriceChangeOption,
      originalModelPrice: _originalModelPrice,
      modelSearchController: _modelSearchController,
      priceChangeController: _priceChangeController,
      searchController: _searchController,
      newModelNameController: _newModelNameController,
      newModelPriceController: _newModelPriceController,
      modalError: _modalError,
      modalSuccess: _modalSuccess,
      onBrandChanged: (value) {
        setState(() {
          _selectedBrand = value;
          _selectedModel = null;
          _showAddModelForm = false;
          _showPriceChangeOption = false;
          _newModelName = null;
          _newModelPrice = null;
          _modelSearchController.clear();
          _priceChangeController.clear();
          _newModelNameController.clear();
          _newModelPriceController.clear();
          _clearModalMessages();
        });
      },
      onModelSelected: (value) {
        _handleModelSelection(value);
      },
      onCancelAddNewModel: _cancelAddNewModel,
      onQuantityChanged: (value) {
        _handleQuantityChange(value);
      },
      onOpenScannerForSerialField: (index) {
        _openScannerForSerialField(index);
      },
      onClearModalMessages: _clearModalMessages,
      onCloseModal: _closeAddStockModal,
      onSaveStock: _saveStock,
      onSaveNewModel: _saveNewModel,
    );
  }

  Widget _buildActionModal() {
    if (_selectedTvForAction == null) return const SizedBox();

    final tv = _selectedTvForAction!;
    final modelName = tv['modelName'] as String? ?? 'Unknown';
    final modelBrand = tv['modelBrand'] as String? ?? 'Unknown';
    final serial = tv['serialNumber'] as String? ?? 'N/A';
    final price = tv['modelPrice'];
    final currentShopId = tv['shopId'] as String? ?? '';
    final currentShopName = tv['shopName'] as String? ?? 'Unknown Shop';
    final tvId = tv['id'] as String? ?? '';

    final filteredShops = _shops
        .where((shop) => shop['id'] != currentShopId)
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedAction == 'sell'
                        ? 'Sell TV'
                        : _selectedAction == 'transfer'
                        ? 'Transfer TV'
                        : 'Return TV',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() => _selectedTvForAction = null);
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modelName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Brand: $modelBrand',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Spacer(),
                        Text(
                          _formatPrice(price),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Serial: $serial',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current Shop: $currentShopName',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tvId.isNotEmpty)
                      Text(
                        'TV ID: ${tvId.substring(0, 8)}...',
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (_selectedAction == 'sell') ...[
                const Text(
                  'Are you sure you want to mark this TV as sold?',
                  style: TextStyle(fontSize: 12),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _selectedTvForAction = null);
                        },
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
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (tvId.isNotEmpty) {
                                  _markAsSold(tvId, tv);
                                } else {
                                  _showError(
                                    'TV ID not found. Please try again.',
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Sell',
                                style: TextStyle(fontSize: 12),
                              ),
                      ),
                    ),
                  ],
                ),
              ] else if (_selectedAction == 'transfer') ...[
                const Text(
                  'Select shop to transfer to:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                if (filteredShops.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No other shops available for transfer',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredShops.length,
                      itemBuilder: (context, index) {
                        final shop = filteredShops[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.store,
                            color: Colors.blue,
                            size: 18,
                          ),
                          title: Text(
                            shop['name'] as String? ?? 'Unknown Shop',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle:
                              shop['address'] != null &&
                                  (shop['address'] as String).isNotEmpty
                              ? Text(
                                  shop['address'] as String,
                                  style: const TextStyle(fontSize: 10),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: _isLoading
                              ? null
                              : () {
                                  if (tvId.isNotEmpty) {
                                    _transferToShop(
                                      tvId,
                                      tv,
                                      shop['id'] as String? ?? '',
                                      shop['name'] as String? ?? 'Unknown Shop',
                                    );
                                  } else {
                                    _showError(
                                      'TV ID not found. Please try again.',
                                    );
                                  }
                                },
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() => _selectedTvForAction = null);
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_selectedAction == 'return') ...[
                const Text(
                  'Are you sure you want to return this TV?',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will remove the TV from available stock and create a return record.',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _selectedTvForAction = null);
                        },
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
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (tvId.isNotEmpty) {
                                  _returnTv(tvId, tv);
                                } else {
                                  _showError(
                                    'TV ID not found. Please try again.',
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Return',
                                style: TextStyle(fontSize: 12),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            labelText: 'Search by Serial, Model, Brand',
            labelStyle: const TextStyle(fontSize: 13),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _foundInSoldStock = null;
                        _showingSoldStockWarning = false;
                      });
                      _searchFocusNode.unfocus();
                    },
                  ),
                Container(width: 1, height: 20, color: Colors.grey.shade300),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, size: 22),
                  onPressed: _openScannerForSearch,
                  tooltip: 'Scan Serial to search',
                  color: Colors.blue,
                ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _showingSoldStockWarning ? Colors.orange : Colors.blue,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _showingSoldStockWarning ? Colors.orange : Colors.blue,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: const TextStyle(fontSize: 13, color: Colors.black),
          onChanged: (value) async {
            setState(() => _searchQuery = value);

            if (_showingSoldStockWarning) {
              setState(() {
                _foundInSoldStock = null;
                _showingSoldStockWarning = false;
              });
            }

            if (value.length >= 8) {
              final soldItem = await _checkSerialInSoldStock(value);
              if (soldItem != null && mounted) {
                setState(() {
                  _foundInSoldStock = soldItem;
                  _showingSoldStockWarning = true;
                });
              }
            }
          },
          onSubmitted: (value) {
            _searchFocusNode.unfocus();
          },
        ),

        if (_showingSoldStockWarning && _foundInSoldStock != null)
          _buildSoldStockWarning(),
      ],
    );
  }

  Widget _buildQuickScanButton() {
    return FloatingActionButton.extended(
      onPressed: _openScannerForSearch,
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text('Scan'),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      elevation: 4,
    );
  }

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp == null) return 'N/A';
      if (timestamp is Timestamp) {
        return DateFormat('dd MMM yyyy').format(timestamp.toDate());
      }
      return timestamp.toString();
    } catch (e) {
      return 'Invalid date';
    }
  }

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

  Widget _buildStockList(String type) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final currentShopId = user?.shopId;

    if (type == 'returned') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tvReturns')
            .where('originalShopId', isEqualTo: currentShopId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 32),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Error loading returned TVs: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final returns = snapshot.data!.docs;

          if (returns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_return, size: 50, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'No returned TVs',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Shop: ${user?.shopName ?? 'Unknown'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          returns.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['returnedAt'];
            final bDate = bData['returnedAt'];

            if (aDate == null || bDate == null) return 0;
            if (aDate is Timestamp && bDate is Timestamp) {
              return bDate.compareTo(aDate);
            }
            return 0;
          });

          final filteredReturns = _filterStocksBySearch(returns);

          if (filteredReturns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 50, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text(
                    'No matching returned items',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try different search',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          double totalValue = 0;
          int totalTvs = 0;
          final Map<String, Map<String, dynamic>> brandStats = {};

          for (final data in filteredReturns) {
            final price = _parsePrice(data['modelPrice']);
            final brand = data['modelBrand'] as String? ?? 'Unknown';

            totalTvs++;
            totalValue += price;

            if (!brandStats.containsKey(brand)) {
              brandStats[brand] = {'count': 0, 'value': 0.0};
            }

            brandStats[brand]!['count'] = brandStats[brand]!['count'] + 1;
            brandStats[brand]!['value'] = brandStats[brand]!['value'] + price;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Returned Value',
                        _formatPrice(totalValue),
                        '$totalTvs TVs',
                        Colors.orange,
                        Icons.assignment_return,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        'Brands',
                        '${brandStats.length}',
                        'Varieties',
                        Colors.purple,
                        Icons.category,
                      ),
                    ),
                  ],
                ),
              ),

              if (brandStats.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Returned by Brand',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: brandStats.length,
                    itemBuilder: (context, index) {
                      final brand = brandStats.keys.toList()[index];
                      final stats = brandStats[brand]!;
                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              brand,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                              ),
                              maxLines: 1,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${stats['count']}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            Text(
                              _formatPrice(stats['value']),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Divider(),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Returned TVs: ${filteredReturns.length}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      'Shop: ${user?.shopName ?? 'Unknown'}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.1,
                  ),
                  itemCount: filteredReturns.length,
                  itemBuilder: (context, index) {
                    final returnData = filteredReturns[index];
                    final modelName =
                        returnData['modelName'] as String? ?? 'Unknown';
                    final modelBrand =
                        returnData['modelBrand'] as String? ?? 'Unknown';
                    final serial =
                        returnData['serialNumber'] as String? ?? 'N/A';
                    final price = returnData['modelPrice'];
                    final returnedAt = returnData['returnedAt'];
                    final returnedBy = returnData['returnedBy'] ?? 'Unknown';
                    final reason =
                        returnData['reason'] ?? 'returned_to_inventory';
                    final originalShopName =
                        returnData['originalShopName'] ?? 'Unknown Shop';

                    return _buildReturnedTvCard(
                      modelName: modelName,
                      modelBrand: modelBrand,
                      serial: serial,
                      price: price,
                      returnedAt: returnedAt,
                      returnedBy: returnedBy,
                      reason: reason,
                      originalShopName: originalShopName,
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    } else {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tvStock')
            .where('shopId', isEqualTo: currentShopId)
            .where('status', isEqualTo: type)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 32),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Error loading data: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stocks = snapshot.data!.docs;

          if (stocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type == 'available'
                        ? Icons.inventory_2
                        : Icons.shopping_cart_checkout,
                    size: 50,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    type == 'available' ? 'No available TVs' : 'No sold TVs',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  if (_showingSoldStockWarning && type == 'available')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'This serial was found in sold stock. Check the warning above for details.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    )
                  else if (type == 'available')
                    ElevatedButton.icon(
                      onPressed: _openAddStockModal,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Add First TV',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          stocks.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['uploadedAt'];
            final bDate = bData['uploadedAt'];

            if (aDate == null || bDate == null) return 0;
            if (aDate is Timestamp && bDate is Timestamp) {
              return bDate.compareTo(aDate);
            }
            return 0;
          });

          final filteredStocks = _filterStocksBySearch(stocks);

          if (filteredStocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 50, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text(
                    'No matching items',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  if (_showingSoldStockWarning && type == 'available')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'This serial was found in sold stock. Check the warning above for details.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    )
                  else
                    Text(
                      'Try different search',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            );
          }

          double totalValue = 0;
          int totalTvs = 0;
          final Map<String, Map<String, dynamic>> brandStats = {};

          for (final data in filteredStocks) {
            final price = _parsePrice(data['modelPrice']);
            final brand = data['modelBrand'] as String? ?? 'Unknown';

            totalTvs++;
            totalValue += price;

            if (!brandStats.containsKey(brand)) {
              brandStats[brand] = {'count': 0, 'value': 0.0};
            }

            brandStats[brand]!['count'] = brandStats[brand]!['count'] + 1;
            brandStats[brand]!['value'] = brandStats[brand]!['value'] + price;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        type == 'available' ? 'Available Value' : 'Sold Value',
                        _formatPrice(totalValue),
                        '$totalTvs TVs',
                        type == 'available' ? Colors.green : Colors.blue,
                        type == 'available'
                            ? Icons.inventory
                            : Icons.shopping_cart_checkout,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        'Brands',
                        '${brandStats.length}',
                        'Varieties',
                        Colors.purple,
                        Icons.category,
                      ),
                    ),
                  ],
                ),
              ),

              if (brandStats.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Brand-wise Summary',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: brandStats.length,
                    itemBuilder: (context, index) {
                      final brand = brandStats.keys.toList()[index];
                      final stats = brandStats[brand]!;
                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: type == 'available'
                              ? Colors.green.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: type == 'available'
                                ? Colors.green.shade200
                                : Colors.blue.shade200,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              brand,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${stats['count']}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: type == 'available'
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            ),
                            Text(
                              _formatPrice(stats['value']),
                              style: TextStyle(
                                fontSize: 9,
                                color: type == 'available'
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Divider(),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TVs: ${filteredStocks.length}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (type == 'available')
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        onPressed: _openScannerForSearch,
                        tooltip: 'Scan Serial to search',
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 200,
                  ),
                  itemCount: filteredStocks.length,
                  itemBuilder: (context, index) {
                    final stock = filteredStocks[index];
                    final modelName =
                        stock['modelName'] as String? ?? 'Unknown';
                    final modelBrand =
                        stock['modelBrand'] as String? ?? 'Unknown';
                    final serial = stock['serialNumber'] as String? ?? 'N/A';
                    final price = stock['modelPrice'];
                    final uploadedAt = stock['uploadedAt'];
                    final soldAt = stock['soldAt'];
                    final tvId = stock['id'] as String? ?? '';

                    return _buildTvCard(
                      modelName: modelName,
                      modelBrand: modelBrand,
                      serial: serial,
                      price: price,
                      uploadedAt: uploadedAt,
                      soldAt: soldAt,
                      status: type,
                      tvData: stock,
                      onSell: type == 'available'
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BillFormTvScreen(
                                    tvData: stock,
                                    serialNumber: serial,
                                    tvId: tvId,
                                  ),
                                ),
                              ).then((success) {
                                if (success == true) {
                                  setState(() {});
                                }
                              });
                            }
                          : null,
                      onTransfer: type == 'available'
                          ? () {
                              setState(() {
                                _selectedTvForAction = {...stock, 'id': tvId};
                                _selectedAction = 'transfer';
                              });
                            }
                          : null,
                      onReturn: type == 'available'
                          ? () {
                              setState(() {
                                _selectedTvForAction = {...stock, 'id': tvId};
                                _selectedAction = 'return';
                              });
                            }
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 9, color: color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildTvCard({
    required String modelName,
    required String modelBrand,
    required String serial,
    required dynamic price,
    required dynamic uploadedAt,
    dynamic soldAt,
    required String status,
    Map<String, dynamic>? tvData,
    VoidCallback? onSell,
    VoidCallback? onTransfer,
    VoidCallback? onReturn,
  }) {
    String displaySerial = _formatSerialForDisplay(serial);

    Color borderColor;
    Color bgColor;

    switch (status) {
      case 'available':
        borderColor = Colors.green.shade200;
        bgColor = Colors.white;
        break;
      case 'sold':
        borderColor = Colors.blue.shade200;
        bgColor = Colors.blue.shade50;
        break;
      default:
        borderColor = Colors.grey.shade300;
        bgColor = Colors.white;
    }

    final transferredBy = tvData?['transferredBy'] as String?;
    final transferredAt = tvData?['transferredAt'];
    final previousShopName = tvData?['previousShopName'] as String?;

    return Container(
      constraints: const BoxConstraints(minHeight: 200, maxHeight: 350),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: status == 'available'
                              ? Colors.green.shade100
                              : status == 'sold'
                              ? Colors.blue.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: status == 'available'
                                ? Colors.green
                                : status == 'sold'
                                ? Colors.blue
                                : Colors.grey,
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      SizedBox(
                        height: 32,
                        child: Text(
                          modelName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        _formatPrice(price),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 2),

                      Text(
                        modelBrand,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 2),

                      SizedBox(
                        height: 24,
                        child: Text(
                          'Serial: $displaySerial',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black,
                            fontFamily: 'Monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      if (transferredBy != null && transferredAt != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.swap_horiz,
                              size: 10,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Transfer by $transferredBy on ${_formatDate(transferredAt)}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      Text(
                        'Added: ${_formatDate(uploadedAt)} by ${tvData?['uploadedBy'] ?? 'Unknown'}',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (status == 'sold' && soldAt != null) ...[
                        Text(
                          'Sold: ${_formatDate(soldAt)}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (tvData?['soldBy'] != null)
                          Text(
                            'By: ${tvData?['soldBy']}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],

                      if (status == 'available' &&
                          (onSell != null ||
                              onTransfer != null ||
                              onReturn != null))
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 6),
                            const Divider(height: 1, color: Colors.grey),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (onSell != null)
                                  Expanded(
                                    child: SizedBox(
                                      height: 28,
                                      child: ElevatedButton(
                                        onPressed: onSell,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.zero,
                                          textStyle: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Sell'),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (onSell != null && onTransfer != null)
                                  const SizedBox(width: 4),
                                if (onTransfer != null)
                                  Expanded(
                                    child: SizedBox(
                                      height: 28,
                                      child: ElevatedButton(
                                        onPressed: onTransfer,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.zero,
                                          textStyle: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Transfer'),
                                        ),
                                      ),
                                    ),
                                  ),
                                if ((onSell != null || onTransfer != null) &&
                                    onReturn != null)
                                  const SizedBox(width: 4),
                                if (onReturn != null)
                                  Expanded(
                                    child: SizedBox(
                                      height: 28,
                                      child: ElevatedButton(
                                        onPressed: onReturn,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.zero,
                                          textStyle: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Return'),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReturnedTvCard({
    required String modelName,
    required String modelBrand,
    required String serial,
    required dynamic price,
    required dynamic returnedAt,
    required String returnedBy,
    required String reason,
    required String originalShopName,
  }) {
    String displaySerial = _formatSerialForDisplay(serial);

    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'RETURNED',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),

            const SizedBox(height: 4),

            SizedBox(
              height: 32,
              child: Text(
                modelName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              _formatPrice(price),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            Text(
              modelBrand,
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            SizedBox(
              height: 24,
              child: Text(
                'Serial: $displaySerial',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black,
                  fontFamily: 'Monospace',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            Text(
              'Returned: ${_formatDate(returnedAt)}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'By: $returnedBy',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Shop: $originalShopName',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Reason: ${reason.replaceAll('_', ' ').toLowerCase()}',
              style: TextStyle(fontSize: 9, color: Colors.orange.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  double _parsePrice(dynamic price) {
    try {
      if (price == null) return 0;
      if (price is int) return price.toDouble();
      if (price is double) return price;
      if (price is String) {
        final parsed = double.tryParse(price);
        return parsed ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final currentShopId = user?.shopId;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('TV Stock', style: TextStyle(fontSize: 16)),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                Container(
                  height: 40,
                  margin: const EdgeInsets.all(3),
                  alignment: Alignment.center,
                  child: ElevatedButton.icon(
                    onPressed: _openAddStockModal,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
              ],
              centerTitle: true,
              toolbarHeight: 56,
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : currentShopId == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 40),
                        SizedBox(height: 12),
                        Text(
                          'Shop not found',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        color: Colors.white,
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: TabBar(
                                controller: _tabController,
                                labelColor: Colors.blue,
                                unselectedLabelColor: Colors.grey,
                                indicatorColor: Colors.blue,
                                indicatorWeight: 3,
                                indicatorSize: TabBarIndicatorSize.tab,
                                labelStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                unselectedLabelStyle: const TextStyle(
                                  fontSize: 12,
                                ),
                                labelPadding: EdgeInsets.zero,
                                tabs: [
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.inventory, size: 18),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _tabTitles[0],
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.shopping_cart_checkout,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _tabTitles[1],
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.assignment_return,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _tabTitles[2],
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
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

                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.white,
                        child: _buildSearchField(),
                      ),
                      const SizedBox(height: 8),

                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildStockList('available'),
                            _buildStockList('sold'),
                            _buildStockList('returned'),
                          ],
                        ),
                      ),
                    ],
                  ),
            floatingActionButton: _buildQuickScanButton(),
          ),

          if (_showAddStockModal || _selectedTvForAction != null)
            Container(
              color: Colors.black.withOpacity(0.5),
              width: double.infinity,
              height: double.infinity,
            ),

          if (_showAddStockModal) _buildAddStockModal(),

          if (_selectedTvForAction != null) _buildActionModal(),
        ],
      ),
    );
  }
}

// FIXED: Scanner dialog class for serial numbers
class OptimizedSerialScanner extends StatefulWidget {
  final String title;
  final String description;
  final Function(String) onScanComplete;

  const OptimizedSerialScanner({
    super.key,
    required this.title,
    required this.description,
    required this.onScanComplete,
  });

  @override
  State<OptimizedSerialScanner> createState() => _OptimizedSerialScannerState();
}

class _OptimizedSerialScannerState extends State<OptimizedSerialScanner>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _isFlashAvailable = false;
  bool _isFlashOn = false;
  bool _isScanning = true;
  bool _isPaused = false;
  Timer? _pauseTimer;
  final Set<String> _scannedCodes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      final hasPermission = await Permission.camera.request().isGranted;
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission denied'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      setState(() {
        _controller = MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
          torchEnabled: _isFlashOn,
        );
      });

      // Set flash as available by default
      _isFlashAvailable = true;
    } catch (e) {
      print('Scanner init error: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
      _controller?.toggleTorch();
    });
  }

  void _pauseScanning() {
    setState(() {
      _isPaused = true;
      _isScanning = false;
    });

    _pauseTimer?.cancel();
    _pauseTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isPaused = false;
          _isScanning = true;
        });
      }
    });
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (!_isScanning || _isPaused) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.displayValue ?? barcode.rawValue;
      if (code != null && code.isNotEmpty && !_scannedCodes.contains(code)) {
        _scannedCodes.add(code);
        _pauseScanning();

        widget.onScanComplete(code);
        Navigator.pop(context);
        break;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _controller?.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _controller?.stop();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pauseTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _controller == null
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        MobileScanner(
                          controller: _controller!,
                          onDetect: _handleBarcode,
                        ),

                        if (_isPaused)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 50,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Code Scanned!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Processing...',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: FloatingActionButton(
                              onPressed: _isFlashAvailable
                                  ? _toggleFlash
                                  : null,
                              backgroundColor: _isFlashAvailable
                                  ? (_isFlashOn ? Colors.amber : Colors.blue)
                                  : Colors.grey,
                              child: Icon(
                                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Position barcode in the center',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
