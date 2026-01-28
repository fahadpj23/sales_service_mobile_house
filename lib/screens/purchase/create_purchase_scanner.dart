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

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 1000,
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
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
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
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
                    child: const Text(
                      'Position barcode within the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
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
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _scannerController?.toggleTorch();
                  },
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Toggle Flash'),
                  style: ElevatedButton.styleFrom(backgroundColor: _pink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
