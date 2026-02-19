import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'add_inventory_screen.dart';
import '../services/services.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController();
  bool isFlashOn = false;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      controller.stop();
    }
  }

  Future<void> _startCamera() async {
    try {
      await controller.start();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to start camera: ${e.toString()}', Colors.red);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _processScannedCode(String code) async {
    setState(() => isProcessing = true);
    controller.stop();

    try {
      final exists = await SupabaseService.checkImeiExists(code);
      
      if (!mounted) return;

      if (exists) {
        _showExistsDialog(code);
      } else {
        final added = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddInventoryScreen(imei: code),
          ),
        );
        
        if (added == true && mounted) {
          Navigator.pop(context, code);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
      }
    }
  }

  void _showExistsDialog(String imei) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.warning, color: Colors.orange, size: 48),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'IMEI Already Exists',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('IMEI: $imei'),
            const SizedBox(height: 8),
            const Text('This IMEI is already in your inventory.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => isProcessing = false);
              controller.start();
            },
            child: const Text('Scan Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, imei);
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan IMEI'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: isFlashOn ? Colors.yellow : null,
            ),
            onPressed: () {
              setState(() => isFlashOn = !isFlashOn);
              controller.toggleTorch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: controller.switchCamera,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (isProcessing) return;
              final code = capture.barcodes.first.rawValue;
              if (code != null && code.isNotEmpty) {
                _processScannedCode(code);
              }
            },
            errorBuilder: (context, error, child) {
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Camera error: ${error.toString()}',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _startCamera,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Scanner Overlay
          CustomPaint(
            painter: ScannerOverlayPainter(),
            child: Container(),
          ),

          // Instructions
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Position IMEI barcode within the frame',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Loading Overlay
          if (isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Checking IMEI...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final scanArea = Rect.fromLTWH(
      size.width * 0.1,
      size.height * 0.2,
      size.width * 0.8,
      size.height * 0.3,
    );

    canvas.drawRect(
      scanArea,
      Paint()..color = Colors.transparent..blendMode = BlendMode.clear,
    );

    final cornerPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(Offset(scanArea.left, scanArea.top + 30), Offset(scanArea.left, scanArea.top), cornerPaint);
    canvas.drawLine(Offset(scanArea.left, scanArea.top), Offset(scanArea.left + 30, scanArea.top), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(scanArea.right - 30, scanArea.top), Offset(scanArea.right, scanArea.top), cornerPaint);
    canvas.drawLine(Offset(scanArea.right, scanArea.top), Offset(scanArea.right, scanArea.top + 30), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(scanArea.left, scanArea.bottom - 30), Offset(scanArea.left, scanArea.bottom), cornerPaint);
    canvas.drawLine(Offset(scanArea.left, scanArea.bottom), Offset(scanArea.left + 30, scanArea.bottom), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(scanArea.right - 30, scanArea.bottom), Offset(scanArea.right, scanArea.bottom), cornerPaint);
    canvas.drawLine(Offset(scanArea.right, scanArea.bottom - 30), Offset(scanArea.right, scanArea.bottom), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}