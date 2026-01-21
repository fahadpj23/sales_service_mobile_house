// imei_scanner.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';

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
                color: Colors.blue.shade700,
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
                        backgroundColor: Colors.blue,
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
