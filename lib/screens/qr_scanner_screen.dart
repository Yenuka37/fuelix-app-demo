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

      await _verifyPasscode(passcode);
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

      // Handle pipe-delimited format: FUELIX|PASSCODE|REG_NO|MODEL|YEAR|FUEL_TYPE
      // Example: FUELIX|JG1O706LPCTA|BB-1231|Suzuki Access|2020|Petrol
      if (rawValue.toUpperCase().startsWith('FUELIX|')) {
        final parts = rawValue.split('|');
        if (parts.length >= 2) {
          // Passcode is the second element (index 1)
          return parts[1];
        }
      }

      // Handle comma-delimited format: FUELIX,PASSCODE,REG_NO,MODEL,YEAR,FUEL_TYPE
      if (rawValue.toUpperCase().startsWith('FUELIX,')) {
        final parts = rawValue.split(',');
        if (parts.length >= 2) {
          return parts[1];
        }
      }

      // Handle FUELIX prefixed formats with any delimiter
      if (rawValue.toUpperCase().startsWith('FUELIX')) {
        // Try to find the best delimiter
        final delimiter = rawValue.contains('|')
            ? '|'
            : rawValue.contains(',')
            ? ','
            : null;

        if (delimiter != null) {
          final parts = rawValue.split(delimiter);
          if (parts.length >= 2) {
            // Remove "FUELIX" prefix from first part if present
            String firstPart = parts[0].toUpperCase();
            if (firstPart == 'FUELIX' || firstPart.startsWith('FUELIX')) {
              return parts[1];
            }
          }
        }
      }

      // Handle plain 12-character alphanumeric passcode
      if (RegExp(r'^[A-Z0-9]{12}$').hasMatch(rawValue.toUpperCase())) {
        return rawValue.toUpperCase();
      }

      // Handle plain 8-16 character alphanumeric passcode (more flexible)
      if (RegExp(r'^[A-Za-z0-9]{8,16}$').hasMatch(rawValue)) {
        return rawValue;
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting passcode: $e');
      return null;
    }
  }

  Future<void> _verifyPasscode(String passcode) async {
    try {
      final result = await _apiService.verifyVehiclePasscode(passcode);

      if (result['success'] && mounted) {
        final vehicleData = result['data'];

        final quotaResult = await _apiService.getCurrentQuota(
          vehicleData['id'],
          vehicleData['type'] ?? 'Car',
        );

        FuelQuotaModel? quota;
        if (quotaResult['success']) {
          quota = FuelQuotaModel.fromMap(quotaResult['data']);
        }

        await _showVehicleDetailsDialog(vehicleData, quota);
      } else {
        _showError(result['error'] ?? 'Invalid Fuel Pass Code');
      }
    } catch (e) {
      _showError('Failed to verify passcode: ${e.toString()}');
    }
  }

  Future<void> _showVehicleDetailsDialog(
    Map<String, dynamic> vehicleData,
    FuelQuotaModel? quota,
  ) async {
    final registrationNo = vehicleData['registrationNo'] ?? 'N/A';
    final vehicleType = vehicleData['type'] ?? 'Car';
    final make = vehicleData['make'] ?? '';
    final model = vehicleData['model'] ?? '';
    final year = vehicleData['year'] ?? '';
    final fuelType = vehicleData['fuelType'] ?? 'Petrol';
    final remainingQuota = quota?.remainingLitres ?? 0.0;
    final usedLitres = quota?.usedLitres ?? 0.0;
    final totalQuota = quota?.quotaLitres ?? 0.0;
    final weekStart = quota?.weekStart;
    final weekEnd = quota?.weekEnd;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text(
              'Vehicle Verified',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.emerald,
                      AppColors.emerald.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      registrationNo.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$make $model ($year)',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        vehicleType,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildDetailRow('Fuel Type', fuelType, Icons.local_gas_station),
              if (vehicleData['color'] != null &&
                  vehicleData['color'].toString().isNotEmpty)
                _buildDetailRow('Color', vehicleData['color'], Icons.palette),
              if (vehicleData['engineCC'] != null &&
                  vehicleData['engineCC'].toString().isNotEmpty)
                _buildDetailRow(
                  'Engine CC',
                  vehicleData['engineCC'].toString(),
                  Icons.speed,
                ),

              const Divider(height: 24),

              Row(
                children: [
                  Icon(
                    Icons.local_gas_station_rounded,
                    color: AppColors.emerald,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Weekly Fuel Quota',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Remaining',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            color: AppColors.darkTextSub,
                          ),
                        ),
                        Text(
                          '${remainingQuota.toStringAsFixed(1)} L',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: remainingQuota > 0
                                ? AppColors.emerald
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: totalQuota > 0 ? usedLitres / totalQuota : 0,
                      backgroundColor: AppColors.emerald.withOpacity(0.2),
                      color: remainingQuota > 0
                          ? AppColors.emerald
                          : AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Used: ${usedLitres.toStringAsFixed(1)} L',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            color: AppColors.darkTextSub,
                          ),
                        ),
                        Text(
                          'Total: ${totalQuota.toStringAsFixed(1)} L',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            color: AppColors.darkTextSub,
                          ),
                        ),
                      ],
                    ),
                    if (weekStart != null && weekEnd != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ocean.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: AppColors.ocean,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Week: ${_formatDate(weekStart)} - ${_formatDate(weekEnd)}',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.ocean,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (remainingQuota <= 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Weekly quota exhausted. Please try next week.',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
          if (remainingQuota > 0 && widget.user != null)
            GradientButton(
              label: 'Proceed to Fuel',
              onPressed: () => Navigator.pop(ctx, {
                'vehicleId': vehicleData['id'],
                'registrationNo': registrationNo,
                'remainingQuota': remainingQuota,
              }),
            ),
        ],
      ),
    ).then((result) {
      if (result != null && mounted) {
        Navigator.pop(context, result);
      }
    });
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.darkTextSub),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: AppColors.darkTextSub,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
          label: 'Scan Again',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _isScanning = true;
              _errorMessage = null;
            });
            _scannerController.start();
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
        _scannerController.start();
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
