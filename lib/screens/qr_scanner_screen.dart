import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/quota_model.dart';
import '../services/api_service.dart';
import '../services/quota_service.dart';
import '../widgets/custom_button.dart';
import 'fuel_log_screen.dart';

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

  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;
  bool _isAnalyzing = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  final GlobalKey _scannerKey = GlobalKey();

  // Track the active snackbar
  ScaffoldMessengerState? _messengerState;
  SnackBar? _activeSnackBar;

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
    // Close any active snackbar
    _activeSnackBar = null;
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (!_isScanning || _isProcessing || _isAnalyzing) return;

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
      _isAnalyzing = true;
      _lastScannedCode = rawValue;
      _lastScanTime = DateTime.now();
    });

    try {
      await HapticFeedback.mediumImpact();

      final passcode = _extractPasscode(rawValue);

      if (passcode == null) {
        _showError('Invalid QR code format');
        return;
      }

      await _verifyAndProceed(passcode);
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

  String? _extractPasscode(String rawValue) {
    try {
      // Handle JSON format
      if (rawValue.startsWith('{') && rawValue.endsWith('}')) {
        final decoded = jsonDecode(rawValue);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('passcode')) {
            return decoded['passcode'].toString();
          }
          if (decoded.containsKey('fuelPassCode')) {
            return decoded['fuelPassCode'].toString();
          }
          if (decoded.containsKey('code')) {
            return decoded['code'].toString();
          }
        }
      }

      // Handle fuelix:// URI format
      if (rawValue.toLowerCase().startsWith('fuelix://')) {
        final uri = Uri.parse(rawValue);
        final queryParams = uri.queryParameters;
        if (queryParams.containsKey('code')) {
          return queryParams['code'];
        }
        if (queryParams.containsKey('passcode')) {
          return queryParams['passcode'];
        }
      }

      // Handle pipe-delimited format
      if (rawValue.toUpperCase().startsWith('FUELIX|')) {
        final parts = rawValue.split('|');
        if (parts.length >= 2) {
          return parts[1];
        }
      }

      // Handle comma-delimited format
      if (rawValue.toUpperCase().startsWith('FUELIX,')) {
        final parts = rawValue.split(',');
        if (parts.length >= 2) {
          return parts[1];
        }
      }

      // Handle plain alphanumeric passcode
      if (RegExp(r'^[A-Za-z0-9]{8,16}$').hasMatch(rawValue)) {
        return rawValue;
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting passcode: $e');
      return null;
    }
  }

  Future<void> _verifyAndProceed(String passcode) async {
    try {
      final result = await _apiService.verifyVehiclePasscode(passcode);

      if (result['success'] && mounted) {
        final vehicleData = result['data'];

        final vehicleUserId = vehicleData['userId'] as int?;

        if (vehicleUserId == null) {
          _showError('Vehicle user information not found');
          return;
        }

        final userResult = await _apiService.getUserById(vehicleUserId);

        if (!userResult['success'] || mounted == false) {
          _showError('Failed to fetch user details');
          return;
        }

        final userData = userResult['data'];

        final vehicleOwner = UserModel(
          id: userData['id'],
          firstName: userData['firstName']?.toString() ?? '',
          lastName: userData['lastName']?.toString() ?? '',
          nic: userData['nic']?.toString() ?? '',
          mobile: userData['mobile']?.toString() ?? '',
          addressLine1: userData['addressLine1']?.toString() ?? '',
          addressLine2: userData['addressLine2']?.toString() ?? '',
          addressLine3: userData['addressLine3']?.toString() ?? '',
          district: userData['district']?.toString() ?? '',
          province: userData['province']?.toString() ?? '',
          postalCode: userData['postalCode']?.toString() ?? '',
          email: userData['email']?.toString() ?? '',
          password: '',
          role: userData['role']?.toString(),
          createdAt: userData['createdAt'] != null
              ? DateTime.tryParse(userData['createdAt'].toString())
              : null,
        );

        final vehicle = VehicleModel(
          id: vehicleData['id'],
          userId: vehicleUserId,
          type: vehicleData['type']?.toString() ?? 'Car',
          make: vehicleData['make']?.toString() ?? '',
          model: vehicleData['model']?.toString() ?? '',
          year: vehicleData['year']?.toString() ?? '',
          registrationNo: vehicleData['registrationNo']?.toString() ?? '',
          fuelType: vehicleData['fuelType']?.toString() ?? 'Petrol',
          engineCC: vehicleData['engineCC']?.toString() ?? '',
          color: vehicleData['color']?.toString() ?? '',
          fuelPassCode: passcode,
          qrGeneratedAt: vehicleData['qrGeneratedAt'] != null
              ? DateTime.tryParse(vehicleData['qrGeneratedAt'].toString())
              : null,
          createdAt: vehicleData['createdAt'] != null
              ? DateTime.tryParse(vehicleData['createdAt'].toString())
              : null,
        );

        final quotaResult = await _apiService.getCurrentQuota(
          vehicle.id!,
          vehicle.type,
        );

        double remainingQuota = 0;
        if (quotaResult['success']) {
          remainingQuota = (quotaResult['data']['remainingLitres'] as num)
              .toDouble();
        }

        double walletBalance = 0;
        final walletResult = await _apiService.getWallet(vehicleUserId);
        if (walletResult['success'] && mounted) {
          walletBalance = (walletResult['data']['balance'] as num).toDouble();
        }

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FuelLogScreen(
              user: vehicleOwner,
              vehicles: [vehicle],
              walletBalance: walletBalance,
              selectedVehicleId: vehicle.id,
              preScannedQuota: remainingQuota,
            ),
          ),
        );
      } else {
        _showError(result['error'] ?? 'Invalid Fuel Pass Code');
      }
    } catch (e) {
      _showError('Failed to verify passcode: ${e.toString()}');
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isScanning = false;
    });

    HapticFeedback.heavyImpact();

    // Close any existing snackbar first
    if (_activeSnackBar != null && _messengerState != null) {
      _messengerState!.removeCurrentSnackBar();
      _activeSnackBar = null;
    }

    // Store messenger state
    _messengerState = ScaffoldMessenger.of(context);

    // Create the snackbar
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Scan Again',
        textColor: Colors.white,
        onPressed: () {
          // Dismiss the snackbar first
          if (_messengerState != null) {
            _messengerState!.removeCurrentSnackBar();
            _activeSnackBar = null;
          }
          // Reset scanning state
          if (mounted) {
            setState(() {
              _isScanning = true;
              _errorMessage = null;
            });
            _scannerController.start();
          }
        },
      ),
    );

    _activeSnackBar = snackBar;
    _messengerState!.showSnackBar(snackBar).closed.then((reason) {
      // Snackbar closed, clear reference
      if (mounted && _activeSnackBar == snackBar) {
        _activeSnackBar = null;
      }
    });
  }

  void _resetScanner() {
    if (mounted) {
      setState(() {
        _isScanning = true;
        _errorMessage = null;
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
          'Scan Fuel Pass',
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
          IconButton(
            onPressed: _showScannerInfo,
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Scanner Info',
          ),
        ],
      ),
      body: Stack(
        children: [
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
                      'Verifying Fuel Pass...',
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
                          'Scan the Fuel Pass QR code on the vehicle',
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
                  'Fuel Pass Scanner',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              Icons.verified_rounded,
              'Passcode Verification',
              'Validates the vehicle\'s unique Fuel Pass code',
            ),
            _buildFeatureItem(
              Icons.local_gas_station_rounded,
              'Quota Check',
              'Shows available weekly fuel quota',
            ),
            _buildFeatureItem(
              Icons.directions_car_rounded,
              'Vehicle Details',
              'Displays registration and vehicle information',
            ),
            _buildFeatureItem(
              Icons.flashlight_on_rounded,
              'Torch Support',
              'Scan in low light conditions',
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
