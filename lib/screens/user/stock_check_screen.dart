// lib/screens/inventory/stock_check_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

// Phone Stock Model
class PhoneStock {
  final String id;
  final String imei;
  final String productBrand;
  final String productName;
  final double productPrice;
  final String shopId;
  final String shopName;
  final String status;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String uploadedById;
  final DateTime createdAt;

  PhoneStock({
    required this.id,
    required this.imei,
    required this.productBrand,
    required this.productName,
    required this.productPrice,
    required this.shopId,
    required this.shopName,
    required this.status,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.uploadedById,
    required this.createdAt,
  });

  factory PhoneStock.fromFirestore(String id, Map<String, dynamic> data) {
    return PhoneStock(
      id: id,
      imei: data['imei'] ?? '',
      productBrand: data['productBrand'] ?? '',
      productName: data['productName'] ?? '',
      productPrice: (data['productPrice'] ?? 0).toDouble(),
      shopId: data['shopId'] ?? '',
      shopName: data['shopName'] ?? '',
      status: data['status'] ?? 'available',
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      uploadedBy: data['uploadedBy'] ?? '',
      uploadedById: data['uploadedById'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

// Stock Service
class StockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<PhoneStock>> getAllPhoneStock() async {
    try {
      final snapshot = await _firestore
          .collection('phoneStock')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PhoneStock.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching phone stock: $e');
      return [];
    }
  }

  Future<Map<String, int>> getStockCount() async {
    try {
      final allStock = await getAllPhoneStock();
      final available = allStock
          .where((item) => item.status == 'available')
          .length;
      final sold = allStock.where((item) => item.status == 'sold').length;

      return {'total': allStock.length, 'available': available, 'sold': sold};
    } catch (e) {
      return {'total': 0, 'available': 0, 'sold': 0};
    }
  }
}

// Main Stock Check Screen
class StockCheckScreen extends StatefulWidget {
  const StockCheckScreen({super.key});

  @override
  State<StockCheckScreen> createState() => _StockCheckScreenState();
}

class _StockCheckScreenState extends State<StockCheckScreen> {
  final StockService _stockService = StockService();
  List<PhoneStock> _allStock = [];
  List<PhoneStock> _filteredStock = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all';

  // Statistics
  int _totalCount = 0;
  int _availableCount = 0;
  int _soldCount = 0;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadStockData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadStockData() async {
    setState(() => _isLoading = true);

    try {
      _allStock = await _stockService.getAllPhoneStock();
      final stats = await _stockService.getStockCount();
      _totalCount = stats['total'] ?? 0;
      _availableCount = stats['available'] ?? 0;
      _soldCount = stats['sold'] ?? 0;
      _filteredStock = _allStock;
    } catch (e) {
      _showErrorSnackbar('Failed to load stock data');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applyFilters() {
    List<PhoneStock> result = _allStock;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((item) {
        return item.productName.toLowerCase().contains(query) ||
            item.productBrand.toLowerCase().contains(query) ||
            item.imei.contains(query) ||
            item.shopName.toLowerCase().contains(query);
      }).toList();
    }

    if (_statusFilter != 'all') {
      result = result.where((item) => item.status == _statusFilter).toList();
    }

    setState(() => _filteredStock = result);
  }

  // IMEI Helper Methods
  String _formatImeiForDisplay(String imei) {
    if (imei.isEmpty) return '';
    if (imei.length == 15) {
      return '${imei.substring(0, 6)} ${imei.substring(6, 12)} ${imei.substring(12)}';
    } else if (imei.length == 16) {
      return '${imei.substring(0, 8)} ${imei.substring(8)}';
    }
    return imei;
  }

  bool _isValidImei(String imei) {
    if (imei.isEmpty) return false;
    if (imei.length != 15 && imei.length != 16) return false;
    if (!RegExp(r'^[0-9]+$').hasMatch(imei)) return false;
    return true;
  }

  // Scanner Methods
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

  Future<void> _openScannerForSearch() async {
    if (!await _checkCameraPermission()) {
      _showErrorSnackbar('Camera permission required for scanning');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => OptimizedImeiScanner(
        title: 'Search IMEI',
        description: 'Scan IMEI to search in stock',
        onScanComplete: (imei) {
          setState(() {
            _searchController.text = imei;
            _searchQuery = imei.toLowerCase();
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: 'Search by IMEI, model, brand...',
        prefixIcon: const Icon(Icons.search, color: Colors.teal, size: 20),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                  _applyFilters();
                  _searchFocusNode.unfocus();
                },
              ),
            Container(width: 1, height: 20, color: Colors.grey.shade300),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, size: 22),
              onPressed: _openScannerForSearch,
              tooltip: 'Scan IMEI to search',
              color: Colors.teal,
            ),
          ],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.teal),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      style: const TextStyle(fontSize: 14, color: Colors.black),
      onChanged: (value) {
        setState(() => _searchQuery = value);
        _applyFilters();
      },
      onSubmitted: (value) {
        _searchFocusNode.unfocus();
      },
    );
  }

  void _showPhoneDetails(PhoneStock phone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildPhoneDetailsSheet(phone),
    );
  }

  Widget _buildPhoneDetailsSheet(PhoneStock phone) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with Status
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getStatusColor(phone.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.phone_iphone,
                    color: _getStatusColor(phone.status),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phone.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone.productBrand,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(phone.status),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _searchByImei(phone.imei);
                    },
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Search Similar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _copyImeiToClipboard(phone.imei);
                    },
                    icon: const Icon(Icons.content_copy, size: 16),
                    label: const Text('Copy IMEI'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Details Sections
            _buildDetailSection('Product Information', [
              _buildDetailRow(
                'IMEI',
                _formatImeiForDisplay(phone.imei),
                canCopy: true,
                onCopy: () => _copyImeiToClipboard(phone.imei),
              ),
              _buildDetailRow('Model', phone.productName),
              _buildDetailRow('Brand', phone.productBrand),
              _buildDetailRow(
                'Price',
                '₹${phone.productPrice.toStringAsFixed(0)}',
              ),
            ]),

            _buildDetailSection('Status & Location', [
              _buildDetailRow(
                'Status',
                phone.status.toUpperCase(),
                color: _getStatusColor(phone.status),
              ),
              _buildDetailRow('Shop', phone.shopName),
              _buildDetailRow('Shop ID', phone.shopId),
            ]),

            _buildDetailSection('Timestamps', [
              _buildDetailRow(
                'Created',
                DateFormat('dd MMM yyyy, HH:mm').format(phone.createdAt),
              ),
              _buildDetailRow(
                'Uploaded',
                DateFormat('dd MMM yyyy, HH:mm').format(phone.uploadedAt),
              ),
            ]),

            _buildDetailSection('Uploaded By', [
              _buildDetailRow('Name', phone.uploadedBy),
              _buildDetailRow('ID', phone.uploadedById),
            ]),

            const SizedBox(height: 20),

            // Scan Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openScannerForSearch();
                },
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Scan Another IMEI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? color,
    bool canCopy = false,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: color ?? Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (canCopy && onCopy != null)
                  IconButton(
                    icon: const Icon(Icons.content_copy, size: 16),
                    onPressed: onCopy,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copy to clipboard',
                    color: Colors.teal,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'sold':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusChip(String status) {
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: _getStatusColor(status),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  Widget _buildStatItem(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPhoneItem(PhoneStock phone) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _showPhoneDetails(phone),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status Indicator
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: _getStatusColor(phone.status),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phone.productName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.confirmation_number,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatImeiForDisplay(phone.imei),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone.shopName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Price and Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${phone.productPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildStatusChip(phone.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _searchByImei(String imei) {
    setState(() {
      _searchQuery = imei;
      _searchController.text = imei;
      _applyFilters();
    });
  }

  void _copyImeiToClipboard(String imei) {
    Clipboard.setData(ClipboardData(text: imei));
    _showSuccessSnackbar('IMEI copied to clipboard');
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _statusFilter = 'all';
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Check'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadStockData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text(
                    'Loading inventory...',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Search Section
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Search Bar with Scan Button
                      _buildSearchField(),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                // Results Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_filteredStock.length} items',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      if (_searchQuery.isNotEmpty || _statusFilter != 'all')
                        TextButton(
                          onPressed: _clearSearch,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.teal,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.clear_all, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Clear filters',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Stock List
                Expanded(
                  child: _filteredStock.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_outlined,
                                size: 60,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No matching items found'
                                    : 'No inventory items',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_searchQuery.isEmpty)
                                ElevatedButton.icon(
                                  onPressed: _loadStockData,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Refresh'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              if (_searchQuery.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _openScannerForSearch();
                                  },
                                  icon: const Icon(
                                    Icons.qr_code_scanner,
                                    size: 16,
                                  ),
                                  label: const Text('Scan to Search'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadStockData,
                          color: Colors.teal,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: _filteredStock.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _buildPhoneItem(_filteredStock[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

// Optimized IMEI Scanner Widget
class OptimizedImeiScanner extends StatefulWidget {
  final Function(String) onScanComplete;
  final String? initialImei;
  final String title;
  final String description;
  final bool autoCloseAfterScan;

  const OptimizedImeiScanner({
    super.key,
    required this.onScanComplete,
    this.initialImei,
    this.title = 'Scan IMEI',
    this.description = 'Align the barcode within the frame',
    this.autoCloseAfterScan = true,
  });

  @override
  State<OptimizedImeiScanner> createState() => _OptimizedImeiScannerState();
}

class _OptimizedImeiScannerState extends State<OptimizedImeiScanner>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _scannerController;
  bool _isScanning = true;
  bool _isTorchOn = false;
  bool _isScannerReady = false;
  Timer? _scanDebounceTimer;
  String? _lastScannedData;
  AnimationController? _animationController;
  Animation<double>? _scanAnimation;

  @override
  void initState() {
    super.initState();
    _initScanner();
    _initAnimation();
  }

  void _initScanner() async {
    try {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
        detectionTimeoutMs: 1000,
      );

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() => _isScannerReady = true);
      }
    } catch (e) {
      print('Scanner init error: $e');
    }
  }

  void _initAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );
  }

  void _handleBarcodeScan(BarcodeCapture capture) {
    if (!_isScanning || !_isScannerReady) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final scannedData = barcodes.first.rawValue ?? '';

    // Prevent multiple scans in quick succession
    if (_scanDebounceTimer != null && _scanDebounceTimer!.isActive) {
      return;
    }

    // Set debounce timer
    _scanDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isScanning = true);
      }
    });

    setState(() {
      _isScanning = false;
    });

    // Clean and validate IMEI
    final cleanImei = _cleanImei(scannedData);

    if (_isValidImei(cleanImei)) {
      _processValidImei(cleanImei);
    } else {
      _showError('Invalid IMEI: ${cleanImei.length} digits');
    }
  }

  String _cleanImei(String rawImei) {
    // Remove all non-numeric characters
    return rawImei.replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool _isValidImei(String imei) {
    // Standard IMEI length is 15 digits, some devices have 16
    if (imei.length < 15 || imei.length > 16) return false;

    // Check if all characters are digits
    if (!RegExp(r'^[0-9]+$').hasMatch(imei)) return false;

    // Optional: IMEI validation using Luhn algorithm
    return true;
  }

  void _processValidImei(String imei) {
    setState(() {
      _lastScannedData = '✓ Scanned: ${_formatImeiForDisplay(imei)}';
    });

    // Wait a moment to show success feedback
    Future.delayed(const Duration(milliseconds: 800), () {
      widget.onScanComplete(imei);

      if (widget.autoCloseAfterScan && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  String _formatImeiForDisplay(String imei) {
    if (imei.length == 15) {
      return '${imei.substring(0, 6)} ${imei.substring(6, 12)} ${imei.substring(12)}';
    } else if (imei.length == 16) {
      return '${imei.substring(0, 8)} ${imei.substring(8)}';
    }
    return imei;
  }

  void _showError(String message) {
    setState(() {
      _lastScannedData = '✗ $message';
    });

    // Reset after showing error
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _lastScannedData = null;
          _isScanning = true;
        });
      }
    });
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter IMEI Manually'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 16,
            decoration: const InputDecoration(
              hintText: 'Enter 15-16 digit IMEI',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final imei = controller.text.trim();
                if (_isValidImei(imei)) {
                  widget.onScanComplete(imei);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid IMEI (15-16 digits)'),
                    ),
                  );
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _scanDebounceTimer?.cancel();
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 25,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              widget.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scanner Area
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Scanner Preview
                  if (_isScannerReady && _scannerController != null)
                    MobileScanner(
                      controller: _scannerController!,
                      onDetect: _handleBarcodeScan,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      color: Colors.black,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'Initializing Scanner...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Scanner Frame with overlay
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.width * 0.8,
                    child: CustomPaint(
                      painter: _ScannerOverlayPainter(
                        _scanAnimation?.value ?? 0,
                      ),
                    ),
                  ),

                  // Status Message
                  if (_lastScannedData != null)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _lastScannedData!.startsWith('✓')
                              ? Colors.green.withOpacity(0.9)
                              : Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _lastScannedData!.startsWith('✓')
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _lastScannedData!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Torch Toggle
                  Positioned(
                    top: 20,
                    right: 20,
                    child: FloatingActionButton.small(
                      onPressed: () {
                        if (_scannerController != null) {
                          _scannerController!.toggleTorch();
                          setState(() => _isTorchOn = !_isTorchOn);
                        }
                      },
                      backgroundColor: Colors.black.withOpacity(0.5),
                      child: Icon(
                        _isTorchOn ? Icons.flash_off : Icons.flash_on,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Instructions
                  Positioned(
                    bottom: _lastScannedData != null ? 80 : 20,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Point camera at IMEI barcode',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!_isScanning)
                          const Text(
                            'Processing...',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Show manual entry dialog
                        _showManualEntryDialog();
                      },
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Manual Entry'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isScanning
                          ? null
                          : () {
                              setState(() {
                                _isScanning = true;
                                _lastScannedData = null;
                              });
                            },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Rescan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scanPosition;

  _ScannerOverlayPainter(this.scanPosition);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw corners
    final cornerLength = 20.0;

    // Top-left
    canvas.drawLine(Offset.zero, Offset(cornerLength, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, cornerLength), paint);

    // Top-right
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      paint,
    );

    // Scanning line
    final scanPaint = Paint()
      ..color = Colors.green.withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final scanY = size.height * scanPosition;
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), scanPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
