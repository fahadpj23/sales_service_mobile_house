import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this for clipboard functionality
import 'package:mobile_scanner/mobile_scanner.dart';

class CreatePurchaseScanner extends StatefulWidget {
  final int itemIndex;
  final int? imeiIndex;
  final String? currentSerial;

  const CreatePurchaseScanner({
    Key? key,
    required this.itemIndex,
    this.imeiIndex,
    this.currentSerial,
  }) : super(key: key);

  @override
  State<CreatePurchaseScanner> createState() => _CreatePurchaseScannerState();
}

class _CreatePurchaseScannerState extends State<CreatePurchaseScanner>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  MobileScannerController? _scannerController;
  final Color _primaryGreen = const Color(0xFF2E7D32);
  final Color _pink = const Color(0xFFE91E63);
  final Color _amber = const Color(0xFFFFB300);
  final Color _lightGreen = const Color(0xFF4CAF50);

  final TextEditingController _manualInputController = TextEditingController();
  bool _isManualInput = false;
  bool _isScanning = true;
  bool _torchEnabled = false;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  String? _lastScannedCode;

  // Animation for scanning effect
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize scan animation
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _scanAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _initializeScanner();
    _manualInputController.text = widget.currentSerial ?? '';
  }

  Future<void> _initializeScanner() async {
    try {
      setState(() {
        _isInitialized = false;
        _hasError = false;
        _errorMessage = '';
      });

      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        detectionTimeoutMs: 500,
        returnImage: false,
        formats: const [BarcodeFormat.all],
      );

      // Test camera availability
      await _scannerController?.start();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing scanner: $e');
      setState(() {
        _hasError = true;
        _errorMessage =
            'Camera initialization failed. Please use manual input.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeScanner();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _pauseScanner();
    }
  }

  void _pauseScanner() {
    if (!_isManualInput && _isInitialized && !_hasError) {
      _scannerController?.stop();
    }
  }

  void _resumeScanner() {
    if (!_isManualInput && _isInitialized && !_hasError && mounted) {
      _scannerController?.start();
    }
  }

  void _handleBarcodeDetect(BarcodeCapture capture) {
    if (!mounted || _lastScannedCode != null) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      final String? code = barcode.rawValue;

      if (code != null && code.isNotEmpty) {
        setState(() {
          _lastScannedCode = code;
        });

        // Haptic feedback
        HapticFeedback.mediumImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanned: $code'),
            duration: const Duration(milliseconds: 500),
            backgroundColor: _primaryGreen,
          ),
        );

        // Return after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.pop(context, code);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanAnimationController.dispose();
    _scannerController?.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  void _toggleTorch() {
    setState(() {
      _torchEnabled = !_torchEnabled;
    });
    _scannerController?.toggleTorch();
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _manualInputController.text = clipboardData.text!;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pasted from clipboard'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to paste'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isManualInput = true;
              });
            },
            child: const Text('Use Manual Input'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.imeiIndex != null
                  ? 'Scan Serial #${widget.imeiIndex! + 1}'
                  : 'Scan IMEI/Serial Number',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (widget.imeiIndex != null)
              Text(
                'Item ${widget.itemIndex + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Manual input toggle
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(
                _isManualInput ? Icons.qr_code_scanner : Icons.keyboard,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _isManualInput = !_isManualInput;
                  if (!_isManualInput && _isInitialized && !_hasError) {
                    _resumeScanner();
                  } else {
                    _pauseScanner();
                  }
                });
              },
              tooltip: _isManualInput
                  ? 'Switch to Scanner'
                  : 'Switch to Manual Input',
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_primaryGreen.withOpacity(0.05), Colors.white],
          ),
        ),
        child: _isManualInput ? _buildManualInput() : _buildScanner(),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Cancel button
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.grey.shade800,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Action button (Flash for scanner, Save for manual)
            Expanded(
              child: _isManualInput
                  ? ElevatedButton(
                      onPressed: () {
                        final serial = _manualInputController.text.trim();
                        if (serial.isNotEmpty) {
                          Navigator.pop(context, serial);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a serial number'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _torchEnabled ? null : _toggleTorch,
                      icon: Icon(
                        _torchEnabled ? Icons.flash_off : Icons.flash_on,
                        size: 18,
                      ),
                      label: Text(_torchEnabled ? 'Flash On' : 'Flash'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _torchEnabled
                            ? _pink
                            : _pink.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanner() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Camera Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isManualInput = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Use Manual Input Instead'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Scanner view
        MobileScanner(
          controller: _scannerController,
          onDetect: _handleBarcodeDetect,
          errorBuilder: (context, error, child) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Scanner error: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _initializeScanner,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
        ),

        // Scanning overlay
        if (_isInitialized) ...[
          // Darkened overlay
          Container(color: Colors.black.withOpacity(0.5)),

          // Scan window with animation
          Center(
            child: AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Scan window frame
                    Container(
                      width: 280,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),

                    // Scanning line animation
                    Positioned(
                      top: 20 + (_scanAnimation.value * 140),
                      child: Container(
                        width: 280,
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              _lightGreen,
                              _primaryGreen,
                              _lightGreen,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Corner indicators
                    Positioned(
                      top: 0,
                      left: 0,
                      child: _buildCorner(Alignment.topLeft),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _buildCorner(Alignment.topRight),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: _buildCorner(Alignment.bottomLeft),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _buildCorner(Alignment.bottomRight),
                    ),
                  ],
                );
              },
            ),
          ),

          // Instruction overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.center_focus_strong,
                        size: 20,
                        color: _lightGreen,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Position barcode within the frame',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (widget.imeiIndex != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Serial #${widget.imeiIndex! + 1} of Item ${widget.itemIndex + 1}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Recent scan indicator
          if (_lastScannedCode != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryGreen.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scanned: $_lastScannedCode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],

        // Loading indicator
        if (!_isInitialized && !_hasError)
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Initializing camera...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: alignment == Alignment.topLeft || alignment == Alignment.topRight
              ? BorderSide(color: _lightGreen, width: 3)
              : BorderSide.none,
          bottom:
              alignment == Alignment.bottomLeft ||
                  alignment == Alignment.bottomRight
              ? BorderSide(color: _lightGreen, width: 3)
              : BorderSide.none,
          left:
              alignment == Alignment.topLeft ||
                  alignment == Alignment.bottomLeft
              ? BorderSide(color: _lightGreen, width: 3)
              : BorderSide.none,
          right:
              alignment == Alignment.topRight ||
                  alignment == Alignment.bottomRight
              ? BorderSide(color: _lightGreen, width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildManualInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.keyboard, size: 50, color: _primaryGreen),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            'Enter Serial Number Manually',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _primaryGreen,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.imeiIndex != null
                  ? 'Serial #${widget.imeiIndex! + 1} of Item ${widget.itemIndex + 1}'
                  : 'For item ${widget.itemIndex + 1}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 24),

          // Input field
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _primaryGreen.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _manualInputController,
              maxLength: 30,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Enter IMEI/Serial number...',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _primaryGreen, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: Icon(Icons.smartphone, color: _primaryGreen),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context, value.trim());
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amber.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: _amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Format Guidelines',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• IMEI: 15 digits\n'
                        '• Serial: 3-30 characters\n'
                        '• Alphanumeric allowed\n'
                        '• No special characters',
                        style: TextStyle(
                          fontSize: 12,
                          color: _amber,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _manualInputController.clear();
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste, size: 18),
                  label: const Text('Paste'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryGreen,
                    side: BorderSide(color: _primaryGreen.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
