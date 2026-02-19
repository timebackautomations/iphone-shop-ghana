import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:digital_twin_shop/services/supabase_service.dart';
import 'package:digital_twin_shop/screens/add_inventory_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool isFlashOn = false;
  String? scannedCode;
  bool isChecking = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _checkImei(String imei) async {
    setState(() => isChecking = true);
    
    try {
      final exists = await SupabaseService.checkImeiExists(imei);
      
      if (!mounted) return;
      
      if (exists) {
        // IMEI already exists
        _showExistsDialog(imei);
      } else {
        // New IMEI - go to add screen
        final added = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddInventoryScreen(imei: imei),
          ),
        );
        
        if (added == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Product added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, imei);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isChecking = false);
      }
    }
  }

  void _showExistsDialog(String imei) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IMEI Already Exists'),
        content: Text('IMEI: $imei\n\nThis IMEI is already in your inventory.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                scannedCode = null;
              });
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
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (isChecking) return;
              final code = capture.barcodes.first.rawValue;
              if (code != null && code.isNotEmpty) {
                setState(() => scannedCode = code);
                controller.stop();
                _checkImei(code);
              }
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
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Loading Overlay
          if (isChecking)
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
                      style: TextStyle(color: Colors.white),
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

    // Draw corners (top-left, top-right, bottom-left, bottom-right)
    canvas.drawLine(Offset(scanArea.left, scanArea.top + 30), Offset(scanArea.left, scanArea.top), cornerPaint);
    canvas.drawLine(Offset(scanArea.left, scanArea.top), Offset(scanArea.left + 30, scanArea.top), cornerPaint);
    canvas.drawLine(Offset(scanArea.right - 30, scanArea.top), Offset(scanArea.right, scanArea.top), cornerPaint);
    canvas.drawLine(Offset(scanArea.right, scanArea.top), Offset(scanArea.right, scanArea.top + 30), cornerPaint);
    canvas.drawLine(Offset(scanArea.left, scanArea.bottom - 30), Offset(scanArea.left, scanArea.bottom), cornerPaint);
    canvas.drawLine(Offset(scanArea.left, scanArea.bottom), Offset(scanArea.left + 30, scanArea.bottom), cornerPaint);
    canvas.drawLine(Offset(scanArea.right - 30, scanArea.bottom), Offset(scanArea.right, scanArea.bottom), cornerPaint);
    canvas.drawLine(Offset(scanArea.right, scanArea.bottom - 30), Offset(scanArea.right, scanArea.bottom), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}