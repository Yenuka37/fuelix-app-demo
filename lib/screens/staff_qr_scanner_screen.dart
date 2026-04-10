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

  String _stationName = '';
  String _stationBrand = '';
  String? _extractedValue;
  bool _hasScanned = false;

  // Verification steps
  bool _isVerifying = false;
  List<VerificationStep> _verificationSteps = [];
  Map<String, dynamic>? _verifiedData;
  bool _verificationComplete = false;
  bool _verificationFailed = false;
  String? _verificationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScanner();
    _loadStationData();
    _initVerificationSteps();
  }

  void _initVerificationSteps() {
    _verificationSteps = [
      VerificationStep(
        id: 'step1',
        title: 'Fuel Pass Code',
        subtitle: 'Verifying vehicle passcode',
        status: VerificationStatus.pending,
        icon: Icons.qr_code_rounded,
      ),
      VerificationStep(
        id: 'step2',
        title: 'Quota Check',
        subtitle: 'Checking available fuel quota',
        status: VerificationStatus.pending,
        icon: Icons.local_gas_station_rounded,
      ),
      VerificationStep(
        id: 'step3',
        title: 'Wallet Balance',
        subtitle: 'Verifying wallet balance',
        status: VerificationStatus.pending,
        icon: Icons.account_balance_wallet_rounded,
      ),
      VerificationStep(
        id: 'step4',
        title: 'Load Data',
        subtitle: 'Loading vehicle information',
        status: VerificationStatus.pending,
        icon: Icons.cloud_download_rounded,
      ),
    ];
  }

  Future<void> _loadStationData() async {
    final staffData = await _apiService.getStaffData();
    if (staffData != null && mounted) {
      setState(() {
        _stationName = staffData['stationName'] ?? 'Fuel Station';
        _stationBrand = staffData['stationBrand'] ?? '';
      });
    }
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
    if (!_isScanning || _isProcessing || _hasScanned || _isVerifying) return;

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

      setState(() {
        _extractedValue = extractedValue;
        _hasScanned = true;
        _isProcessing = false;
        _isVerifying = true;
      });

      // Start verification
      await _verifyPasscode(extractedValue);
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

  Future<void> _verifyPasscode(String passcode) async {
    _updateStep('step1', VerificationStatus.loading);
    await Future.delayed(const Duration(milliseconds: 200));

    final result = await _apiService.staffVerifyPasscode(passcode);

    if (!result['success']) {
      _updateStep('step1', VerificationStatus.failed);
      _verificationFailed = true;
      _verificationError = result['error'] ?? 'Invalid Fuel Pass Code';
      setState(() {});
      return;
    }

    _updateStep('step1', VerificationStatus.completed);
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 2: Quota check
    _updateStep('step2', VerificationStatus.loading);
    await Future.delayed(const Duration(milliseconds: 300));

    if (result.containsKey('step2') && !result['step2']['success']) {
      _updateStep(
        'step2',
        VerificationStatus.failed,
        message: result['step2']['message'],
      );
      _verificationFailed = true;
      _verificationError = result['step2']['message'];
      setState(() {});
      return;
    }

    _updateStep(
      'step2',
      VerificationStatus.completed,
      message: 'Remaining: ${result['step2']['remainingQuota']} L',
    );
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 3: Wallet check
    _updateStep('step3', VerificationStatus.loading);
    await Future.delayed(const Duration(milliseconds: 300));

    if (result.containsKey('step3') && !result['step3']['success']) {
      _updateStep(
        'step3',
        VerificationStatus.failed,
        message: result['step3']['message'],
      );
      _verificationFailed = true;
      _verificationError = result['step3']['message'];
      setState(() {});
      return;
    }

    _updateStep(
      'step3',
      VerificationStatus.completed,
      message: 'Balance: LKR ${result['step3']['balance']}',
    );
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 4: Load data
    _updateStep('step4', VerificationStatus.loading);
    await Future.delayed(const Duration(milliseconds: 300));

    if (result.containsKey('step4') && result['step4']['success']) {
      _verifiedData = result['step4'];
      _updateStep(
        'step4',
        VerificationStatus.completed,
        message: 'Vehicle: ${_verifiedData?['registrationNo']}',
      );
      _verificationComplete = true;
    } else {
      _updateStep('step4', VerificationStatus.failed);
      _verificationFailed = true;
      _verificationError = 'Failed to load vehicle data';
    }

    setState(() {});
  }

  void _updateStep(String id, VerificationStatus status, {String? message}) {
    if (!mounted) return;
    setState(() {
      final index = _verificationSteps.indexWhere((step) => step.id == id);
      if (index != -1) {
        _verificationSteps[index] = _verificationSteps[index].copyWith(
          status: status,
          message: message,
        );
      }
    });
  }

  void _resetScanner() {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _isProcessing = false;
      _hasScanned = false;
      _extractedValue = null;
      _isVerifying = false;
      _verificationComplete = false;
      _verificationFailed = false;
      _verificationError = null;
      _verifiedData = null;
    });
    _initVerificationSteps();
    _scannerController.start();
  }

  void _exitToLogin() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.pushReplacementNamed(context, '/login');
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
      body: Column(
        children: [
          // Top Section - Station Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [AppColors.emerald, AppColors.ocean],
                    ),
                  ),
                  child: const Icon(
                    Icons.local_gas_station_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stationName,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      if (_stationBrand.isNotEmpty)
                        Text(
                          _stationBrand,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSub
                                : AppColors.lightTextSub,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.emerald.withOpacity(0.1),
                  ),
                  child: Text(
                    'STAFF',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Mid Section - Scanner, Verification, or Data Display
          Expanded(
            child: _isVerifying
                ? _buildVerificationScreen(isDark)
                : _verificationComplete && _verifiedData != null
                ? _buildDataDisplayScreen(isDark)
                : _hasScanned &&
                      _extractedValue != null &&
                      !_isVerifying &&
                      !_verificationComplete
                ? _buildExtractedValueScreen(isDark)
                : _buildScannerScreen(isDark, scanAreaTop, scanAreaSize),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildScannerScreen(
    bool isDark,
    double scanAreaTop,
    double scanAreaSize,
  ) {
    return Stack(
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
                    Icon(Icons.error_outline, color: AppColors.error, size: 48),
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
      ],
    );
  }

  Widget _buildExtractedValueScreen(bool isDark) {
    return Container(
      width: double.infinity,
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.emerald, AppColors.ocean],
                  ),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'QR Code Scanned',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Extracted Value:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSub
                      : AppColors.lightTextSub,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.emerald.withOpacity(0.1),
                      AppColors.ocean.withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.emerald.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: SelectableText(
                  _extractedValue ?? '',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verifying credentials...',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.ocean),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationScreen(bool isDark) {
    return Container(
      width: double.infinity,
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Verifying Fuel Pass',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 24),
            ..._verificationSteps.map(
              (step) => _buildVerificationStep(step, isDark),
            ),
            const SizedBox(height: 20),
            if (_verificationFailed)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.error.withOpacity(0.1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _verificationError ?? 'Verification failed',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.error,
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

  Widget _buildVerificationStep(VerificationStep step, bool isDark) {
    Color getStatusColor() {
      switch (step.status) {
        case VerificationStatus.completed:
          return AppColors.emerald;
        case VerificationStatus.failed:
          return AppColors.error;
        case VerificationStatus.loading:
          return AppColors.ocean;
        default:
          return isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
      }
    }

    IconData getStatusIcon() {
      switch (step.status) {
        case VerificationStatus.completed:
          return Icons.check_circle_rounded;
        case VerificationStatus.failed:
          return Icons.error_outline;
        case VerificationStatus.loading:
          return Icons.hourglass_empty_rounded;
        default:
          return step.icon;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: getStatusColor().withOpacity(0.1),
            ),
            child: step.status == VerificationStatus.loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        getStatusColor(),
                      ),
                    ),
                  )
                : Icon(getStatusIcon(), size: 18, color: getStatusColor()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: step.status == VerificationStatus.failed
                        ? AppColors.error
                        : (isDark ? AppColors.darkText : AppColors.lightText),
                  ),
                ),
                Text(
                  step.message ?? step.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: step.status == VerificationStatus.failed
                        ? AppColors.error
                        : (isDark
                              ? AppColors.darkTextSub
                              : AppColors.lightTextSub),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataDisplayScreen(bool isDark) {
    return Container(
      width: double.infinity,
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.emerald, AppColors.ocean],
                ),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Colors.white,
                size: 35,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Fuel Pass Verified',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.emerald,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark ? AppColors.darkSurface : Colors.white,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    Icons.directions_car_rounded,
                    'Registration No',
                    _verifiedData?['registrationNo'] ?? 'N/A',
                    isDark,
                  ),
                  const Divider(height: 16),
                  _buildInfoRow(
                    Icons.category_rounded,
                    'Vehicle Type',
                    '${_verifiedData?['make']} ${_verifiedData?['model']}',
                    isDark,
                  ),
                  const Divider(height: 16),
                  _buildInfoRow(
                    Icons.local_gas_station_rounded,
                    'Fuel Type',
                    _verifiedData?['fuelType'] ?? 'N/A',
                    isDark,
                  ),
                  const Divider(height: 16),
                  _buildInfoRow(
                    Icons.opacity_rounded,
                    'Available Quota',
                    '${(_verifiedData?['remainingQuota'] ?? 0).toStringAsFixed(1)} L',
                    isDark,
                  ),
                  const Divider(height: 16),
                  _buildInfoRow(
                    Icons.account_balance_wallet_rounded,
                    'Wallet Balance',
                    'LKR ${(_verifiedData?['balance'] ?? 0).toStringAsFixed(2)}',
                    isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
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
      child: SafeArea(
        child: _verificationComplete && _verifiedData != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Disabled Refill Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald.withOpacity(0.5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_gas_station_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Refill (Coming Soon)',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedAppButton(
                          label: 'Exit',
                          onPressed: _exitToLogin,
                          icon: Icons.exit_to_app_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GradientButton(
                          label: 'Next',
                          onPressed: _resetScanner,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : (_hasScanned && !_isVerifying && !_verificationComplete)
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedAppButton(
                      label: 'Cancel',
                      onPressed: _exitToLogin,
                      icon: Icons.close_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: 'Verify',
                      onPressed: () => _verifyPasscode(_extractedValue!),
                    ),
                  ),
                ],
              )
            : OutlinedAppButton(
                label: 'Cancel',
                onPressed: _exitToLogin,
                icon: Icons.close_rounded,
              ),
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
    final left = scanAreaRect.left,
        right = scanAreaRect.right,
        top = scanAreaRect.top,
        bottom = scanAreaRect.bottom;

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

enum VerificationStatus { pending, loading, completed, failed }

class VerificationStep {
  final String id;
  final String title;
  final String subtitle;
  final VerificationStatus status;
  final IconData icon;
  final String? message;

  VerificationStep({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
    this.message,
  });

  VerificationStep copyWith({
    String? id,
    String? title,
    String? subtitle,
    VerificationStatus? status,
    IconData? icon,
    String? message,
  }) {
    return VerificationStep(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
      icon: icon ?? this.icon,
      message: message ?? this.message,
    );
  }
}
