import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_button.dart';

class StaffQrScannerScreen extends StatefulWidget {
  const StaffQrScannerScreen({super.key});

  @override
  State<StaffQrScannerScreen> createState() => _StaffQrScannerScreenState();
}

class _StaffQrScannerScreenState extends State<StaffQrScannerScreen>
    with WidgetsBindingObserver {
  late MobileScannerController _scannerController;
  bool _isScanning = true;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScanner();
  }

  void _initScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: _cameraFacing,
      torchEnabled: _isTorchOn,
      autoStart: true,
      returnImage: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _scannerController.start();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        _scannerController.stop();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (!_isScanning || _isProcessing) return;

    final barcode = capture.barcodes.first;
    final rawValue = barcode.rawValue;

    if (rawValue == null || rawValue.isEmpty) return;

    if (_lastScannedCode == rawValue &&
        _lastScanTime != null &&
        DateTime.now().difference(_lastScanTime!) <
            const Duration(seconds: 2)) {
      return;
    }

    setState(() {
      _isScanning = false;
      _isProcessing = true;
      _lastScannedCode = rawValue;
      _lastScanTime = DateTime.now();
    });

    try {
      await HapticFeedback.mediumImpact();

      final extractedValue = _extractValue(rawValue);

      if (mounted) {
        // Show scanned value dialog
        _showScannedValueDialog(extractedValue);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to process QR code';
        _isProcessing = false;
      });
    }
  }

  String _extractValue(String rawValue) {
    try {
      if (rawValue.startsWith('{') && rawValue.endsWith('}')) {
        final decoded = jsonDecode(rawValue);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('passcode'))
            return decoded['passcode'].toString();
          if (decoded.containsKey('fuelPassCode'))
            return decoded['fuelPassCode'].toString();
          if (decoded.containsKey('code')) return decoded['code'].toString();
        }
        return rawValue;
      }

      if (rawValue.toLowerCase().startsWith('fuelix://')) {
        final uri = Uri.parse(rawValue);
        final queryParams = uri.queryParameters;
        if (queryParams.containsKey('code')) return queryParams['code']!;
        if (queryParams.containsKey('passcode'))
          return queryParams['passcode']!;
        return rawValue;
      }

      if (rawValue.toUpperCase().startsWith('FUELIX|')) {
        final parts = rawValue.split('|');
        if (parts.length >= 2) return parts[1];
      }

      if (rawValue.toUpperCase().startsWith('FUELIX,')) {
        final parts = rawValue.split(',');
        if (parts.length >= 2) return parts[1];
      }

      return rawValue;
    } catch (e) {
      debugPrint('Error extracting value: $e');
      return rawValue;
    }
  }

  void _showScannedValueDialog(String value) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.emerald,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'QR Code Scanned',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extracted Value:',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextSub
                    : AppColors.lightTextSub,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    AppColors.emerald.withOpacity(0.1),
                    AppColors.ocean.withOpacity(0.1),
                  ],
                ),
                border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
              ),
              child: SelectableText(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetScanner();
            },
            child: Text(
              'Scan Again',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                color: AppColors.ocean,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Close scanner
            },
            child: Text(
              'Close',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                color: AppColors.emerald,
              ),
            ),
          ),
        ],
      ),
    );
    setState(() => _isProcessing = false);
  }

  void _resetScanner() {
    if (mounted) {
      setState(() {
        _isScanning = true;
        _errorMessage = null;
        _isProcessing = false;
      });
      _scannerController.start();
    }
  }

  void _toggleTorch() {
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
    _scannerController.toggleTorch();
    HapticFeedback.lightImpact();
  }

  void _switchCamera() {
    HapticFeedback.mediumImpact();
    setState(() {
      _cameraFacing = _cameraFacing == CameraFacing.back
          ? CameraFacing.front
          : CameraFacing.back;
    });
    _scannerController.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final scanAreaSize = screenSize.width - 100;
    final scanAreaTop = screenSize.height * 0.2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Staff QR Scanner',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _toggleTorch,
            icon: Icon(
              _isTorchOn
                  ? Icons.flashlight_on_rounded
                  : Icons.flashlight_off_rounded,
              color: _isTorchOn ? AppColors.amber : null,
            ),
            tooltip: _isTorchOn ? 'Turn off torch' : 'Turn on torch',
          ),
          IconButton(
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
            errorBuilder: (context, error, child) {
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Camera Error',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      GradientButton(
                        label: 'Retry',
                        onPressed: _resetScanner,
                        height: 45,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          CustomPaint(
            painter: StaffScannerOverlayPainter(
              scanAreaRect: Rect.fromLTWH(
                50,
                scanAreaTop,
                scanAreaSize,
                scanAreaSize,
              ),
            ),
            child: Container(width: double.infinity, height: double.infinity),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.emerald,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Processing QR Code...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          color: AppColors.emerald,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Scan vehicle QR code to extract Fuel Pass',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedAppButton(
                          label: 'Cancel',
                          onPressed: () => Navigator.pop(context),
                          icon: Icons.close_rounded,
                        ),
                      ),
                    ],
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

class StaffScannerOverlayPainter extends CustomPainter {
  final Rect scanAreaRect;

  StaffScannerOverlayPainter({required this.scanAreaRect});

  @override
  void paint(Canvas canvas, Size size) {
    final Path overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(scanAreaRect)
      ..fillType = PathFillType.evenOdd;

    final Paint overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, overlayPaint);

    final borderPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.emerald, AppColors.ocean],
      ).createShader(scanAreaRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(scanAreaRect, borderPaint);

    final cornerPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.emerald, AppColors.ocean],
      ).createShader(scanAreaRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final cornerLength = 30.0;
    final left = scanAreaRect.left;
    final right = scanAreaRect.right;
    final top = scanAreaRect.top;
    final bottom = scanAreaRect.bottom;

    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + cornerLength, top),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right - cornerLength, top),
      Offset(right, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, top + cornerLength),
      Offset(right, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, bottom - cornerLength),
      Offset(left, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + cornerLength, bottom),
      Offset(left, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right - cornerLength, bottom),
      Offset(right, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, bottom - cornerLength),
      Offset(right, bottom),
      cornerPaint,
    );

    final circlePaint = Paint()
      ..color = AppColors.emerald
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(left + 10, top + 10), 3, circlePaint);
    canvas.drawCircle(Offset(right - 10, top + 10), 3, circlePaint);
    canvas.drawCircle(Offset(left + 10, bottom - 10), 3, circlePaint);
    canvas.drawCircle(Offset(right - 10, bottom - 10), 3, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
