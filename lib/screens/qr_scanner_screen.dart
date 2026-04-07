import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../services/api_service.dart';
import '../widgets/custom_button.dart';

class QrScannerScreen extends StatefulWidget {
  final UserModel? user;

  const QrScannerScreen({super.key, required this.user});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late MobileScannerController _scannerController;
  bool _isScanning = true;
  bool _isProcessing = false;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  final ApiService _apiService = ApiService();

  // Features
  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;
  bool _isAnalyzing = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  final GlobalKey _scannerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScanner();
    _initAnimation();
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

  void _initAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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
    _animationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (!_isScanning || _isProcessing || _isAnalyzing) return;

    final barcode = capture.barcodes.first;
    final rawValue = barcode.rawValue;

    if (rawValue == null || rawValue.isEmpty) return;

    // Prevent duplicate scans within 2 seconds
    if (_lastScannedCode == rawValue &&
        _lastScanTime != null &&
        DateTime.now().difference(_lastScanTime!) <
            const Duration(seconds: 2)) {
      return;
    }

    setState(() {
      _isScanning = false;
      _isProcessing = true;
      _isAnalyzing = true;
      _lastScannedCode = rawValue;
      _lastScanTime = DateTime.now();
    });

    try {
      // Haptic feedback for better UX
      await HapticFeedback.mediumImpact();

      final qrData = _parseQrData(rawValue);

      if (qrData == null) {
        _showError('Invalid QR code format');
        return;
      }

      await _processQrData(qrData);
    } catch (e) {
      _showError('Failed to process QR code: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isAnalyzing = false;
        });
      }
    }
  }

  Map<String, dynamic>? _parseQrData(String rawValue) {
    try {
      if (rawValue.startsWith('{') && rawValue.endsWith('}')) {
        try {
          final decoded = jsonDecode(rawValue);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (e) {
          // Not JSON, continue
        }
      }

      if (rawValue.startsWith('fuelix://')) {
        final uri = Uri.parse(rawValue);
        final pathSegments = uri.pathSegments;

        if (pathSegments.isNotEmpty) {
          final type = pathSegments[0];
          if (type == 'vehicle' && pathSegments.length > 1) {
            return {'type': 'vehicle', 'vehicleId': pathSegments[1]};
          } else if (type == 'station' && pathSegments.length > 1) {
            return {'type': 'station', 'stationId': pathSegments[1]};
          }
        }
      }

      if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(rawValue)) {
        return {'type': 'vehicle', 'vehicleId': rawValue};
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _processQrData(Map<String, dynamic> qrData) async {
    final type = qrData['type'];

    switch (type) {
      case 'vehicle':
        await _handleVehicleQr(qrData['vehicleId']);
        break;
      case 'station':
        await _handleStationQr(qrData['stationId']);
        break;
      default:
        _showError('Unknown QR code type');
    }
  }

  Future<void> _handleVehicleQr(String vehicleId) async {
    try {
      final result = await _apiService.getVehicleDetails(vehicleId);

      if (result['success'] && mounted) {
        final vehicleData = result['data'];
        final vehicle = VehicleModel(
          id: vehicleData['id'],
          userId: vehicleData['userId'],
          type: vehicleData['type'] ?? '',
          make: vehicleData['make'] ?? '',
          model: vehicleData['model'] ?? '',
          year: vehicleData['year'] ?? 0,
          registrationNo: vehicleData['registrationNo'] ?? '',
          fuelType: vehicleData['fuelType'] ?? '',
          engineCC: vehicleData['engineCC']?.toString() ?? '',
          color: vehicleData['color'] ?? '',
          fuelPassCode: vehicleData['fuelPassCode'],
          qrGeneratedAt: vehicleData['qrGeneratedAt'] != null
              ? DateTime.tryParse(vehicleData['qrGeneratedAt'])
              : null,
          createdAt: vehicleData['createdAt'] != null
              ? DateTime.tryParse(vehicleData['createdAt'])
              : null,
        );

        await _showVehicleInfoDialog(vehicle);
      } else {
        _showError('Vehicle not found');
      }
    } catch (e) {
      _showError('Failed to fetch vehicle details');
    }
  }

  Future<void> _handleStationQr(String stationId) async {
    try {
      final result = await _apiService.getFuelStationDetails(stationId);

      if (result['success'] && mounted) {
        final stationData = result['data'];
        await _showStationInfoDialog(stationData);
      } else {
        _showError('Fuel station not found');
      }
    } catch (e) {
      _showError('Failed to fetch station details');
    }
  }

  Future<void> _showVehicleInfoDialog(VehicleModel vehicle) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.directions_car_rounded,
              color: AppColors.emerald,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              'Vehicle Details',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Registration', vehicle.registrationNo),
            const SizedBox(height: 12),
            _buildInfoRow('Make', vehicle.make),
            const SizedBox(height: 12),
            _buildInfoRow('Model', vehicle.model),
            const SizedBox(height: 12),
            _buildInfoRow('Year', vehicle.year.toString()),
            const SizedBox(height: 12),
            _buildInfoRow('Fuel Type', vehicle.fuelType),
            if (vehicle.color.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Color', vehicle.color),
            ],
            if (vehicle.engineCC.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Engine CC', vehicle.engineCC),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.emerald,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This vehicle is registered with Fuelix',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: AppColors.emerald,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Close',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (widget.user != null)
            GradientButton(
              label: 'Log Fuel',
              onPressed: () => Navigator.pop(ctx, true),
            ),
        ],
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _showStationInfoDialog(Map<String, dynamic> station) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.local_gas_station_rounded,
              color: AppColors.emerald,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                station['name'] ?? 'Fuel Station',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (station['address'] != null)
              _buildInfoRow('Address', station['address']),
            if (station['city'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('City', station['city']),
            ],
            if (station['fuelTypes'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Fuel Types', station['fuelTypes']),
            ],
            if (station['openingHours'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Hours', station['openingHours']),
            ],
            if (station['contactNumber'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Contact', station['contactNumber']),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.emerald,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Scan this QR at the station to log your fuel purchase',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: AppColors.emerald,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSub
                  : AppColors.lightTextSub,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });

    HapticFeedback.heavyImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _isScanning = true;
              _errorMessage = null;
            });
          },
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _errorMessage != null) {
        setState(() {
          _errorMessage = null;
          _isScanning = true;
        });
      }
    });
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
          'QR Scanner',
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
          // Torch button
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
          // Switch camera button
          IconButton(
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
            tooltip: 'Switch Camera',
          ),
          // Info button
          IconButton(
            onPressed: _showScannerInfo,
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Scanner Info',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview - full screen
          MobileScanner(
            key: _scannerKey,
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
                        onPressed: () {
                          _scannerController.start();
                          setState(() {
                            _isScanning = true;
                          });
                        },
                        height: 45,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Scanner overlay with transparent center
          CustomPaint(
            painter: ScannerOverlayPainter(
              scanAreaRect: Rect.fromLTWH(
                50,
                scanAreaTop,
                scanAreaSize,
                scanAreaSize,
              ),
            ),
            child: Container(width: double.infinity, height: double.infinity),
          ),

          // Scanning line animation
          if (_isScanning && !_isProcessing)
            AnimatedBuilder(
              animation: _scanLineAnimation,
              builder: (context, child) {
                return Positioned(
                  left: 50,
                  right: 50,
                  top: scanAreaTop + (_scanLineAnimation.value * scanAreaSize),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.emerald, AppColors.ocean],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Processing indicator
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

          // Bottom instructions panel
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
                    mainAxisAlignment: MainAxisAlignment.center,
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
                          'Position the QR code within the frame',
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
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTip(
                        icon: Icons.directions_car_rounded,
                        label: 'Vehicle QR',
                        color: AppColors.ocean,
                      ),
                      _buildTip(
                        icon: Icons.local_gas_station_rounded,
                        label: 'Station QR',
                        color: AppColors.emerald,
                      ),
                      _buildTip(
                        icon: Icons.payment_rounded,
                        label: 'Payment QR',
                        color: AppColors.amber,
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

  Widget _buildTip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showScannerInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.emerald,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Scanner Features',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              Icons.flashlight_on_rounded,
              'Torch Support',
              'Scan in low light conditions',
            ),
            _buildFeatureItem(
              Icons.cameraswitch_rounded,
              'Camera Switching',
              'Switch between front and back cameras',
            ),
            _buildFeatureItem(
              Icons.speed_rounded,
              'Fast Detection',
              'Fast QR code detection with anti-duplicate',
            ),
            _buildFeatureItem(
              Icons.vibration_rounded,
              'Haptic Feedback',
              'Vibration feedback on successful scan',
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Got it',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.emerald.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.emerald, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextSub
                        : AppColors.lightTextSub,
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

class ScannerOverlayPainter extends CustomPainter {
  final Rect scanAreaRect;

  ScannerOverlayPainter({required this.scanAreaRect});

  @override
  void paint(Canvas canvas, Size size) {
    // Create path for the overlay (darken everything except scan area)
    final Path overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(scanAreaRect)
      ..fillType = PathFillType.evenOdd;

    // Draw dark overlay
    final Paint overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, overlayPaint);

    // Draw scan area border with gradient
    final borderPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.emerald, AppColors.ocean],
      ).createShader(scanAreaRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(scanAreaRect, borderPaint);

    // Draw corner marks
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

    // Top-left corner
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

    // Top-right corner
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

    // Bottom-left corner
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

    // Bottom-right corner
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

    // Draw corner circle decorations
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
