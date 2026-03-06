import 'package:flutter/material.dart';
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

class _CreatePurchaseScannerState extends State<CreatePurchaseScanner> {
  MobileScannerController? _scannerController;
  final Color _primaryGreen = const Color(0xFF2E7D32);
  final Color _pink = const Color(0xFFE91E63);
  final Color _amber = const Color(0xFFFFB300);
  final TextEditingController _manualInputController = TextEditingController();
  bool _isManualInput = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 1000,
    );
    _manualInputController.text = widget.currentSerial ?? '';
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.imeiIndex != null
              ? 'Scan Serial ${widget.imeiIndex! + 1}'
              : 'Scan IMEI/Serial Number',
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _isManualInput ? Icons.camera_alt : Icons.keyboard,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _isManualInput = !_isManualInput;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isManualInput ? _buildManualInput() : _buildScanner(),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                if (!_isManualInput)
                  ElevatedButton.icon(
                    onPressed: () {
                      _scannerController?.toggleTorch();
                    },
                    icon: const Icon(Icons.flash_on, size: 16),
                    label: const Text('Flash'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pink,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                if (_isManualInput)
                  ElevatedButton.icon(
                    onPressed: () {
                      final serial = _manualInputController.text.trim();
                      if (serial.isNotEmpty) {
                        Navigator.pop(context, serial);
                      }
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final barcode = barcodes.first;
              if (barcode.rawValue != null) {
                Navigator.pop(context, barcode.rawValue!);
              }
            }
          },
        ),
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text(
                  'Position barcode within the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.imeiIndex != null
                      ? 'Serial ${widget.imeiIndex! + 1}'
                      : 'Scan IMEI/Serial',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: Container(
            width: 250,
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: _primaryGreen, width: 3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.keyboard, size: 60, color: _primaryGreen),
          const SizedBox(height: 20),
          Text(
            'Enter Serial Number Manually',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.imeiIndex != null
                ? 'Serial ${widget.imeiIndex! + 1} for item'
                : 'For quantity: 1 unit',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _manualInputController,
            maxLength: 30,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter IMEI/Serial number...',
              hintStyle: const TextStyle(fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _primaryGreen),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _primaryGreen, width: 2),
              ),
              prefixIcon: Icon(Icons.smartphone, color: _primaryGreen),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: _amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Format: IMEI (15 digits) or Serial Number (3-30 characters)',
                    style: TextStyle(fontSize: 10, color: _amber),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
