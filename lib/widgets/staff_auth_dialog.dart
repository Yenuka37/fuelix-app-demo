import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_button.dart';

class StaffAuthDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onFailure;

  const StaffAuthDialog({
    super.key,
    required this.onSuccess,
    required this.onFailure,
  });

  @override
  State<StaffAuthDialog> createState() => _StaffAuthDialogState();
}

class _StaffAuthDialogState extends State<StaffAuthDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nicController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isAuthenticating = false;
  List<AuthStep> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializeSteps();
  }

  void _initializeSteps() {
    _steps = [
      AuthStep(
        id: 'auth',
        title: 'Authentication',
        subtitle: 'Verifying your credentials',
        status: AuthStatus.pending,
        icon: Icons.verified_user_rounded,
      ),
      AuthStep(
        id: 'role',
        title: 'Role Verification',
        subtitle: 'Checking staff permissions',
        status: AuthStatus.pending,
        icon: Icons.admin_panel_settings_rounded,
      ),
      AuthStep(
        id: 'staff',
        title: 'Staff Record',
        subtitle: 'Verifying staff membership',
        status: AuthStatus.pending,
        icon: Icons.badge_rounded,
      ),
      AuthStep(
        id: 'station',
        title: 'Station Details',
        subtitle: 'Loading station information',
        status: AuthStatus.pending,
        icon: Icons.local_gas_station_rounded,
      ),
      AuthStep(
        id: 'complete',
        title: 'Complete',
        subtitle: 'Authentication successful',
        status: AuthStatus.pending,
        icon: Icons.check_circle_rounded,
      ),
    ];
  }

  void _updateStep(String id, AuthStatus status, {String? message}) {
    if (!mounted) return;
    setState(() {
      final index = _steps.indexWhere((step) => step.id == id);
      if (index != -1) {
        _steps[index] = _steps[index].copyWith(
          status: status,
          message: message,
        );
      }
    });
  }

  Future<void> _handleAuthentication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isAuthenticating = true;
      _isLoading = true;
    });

    // Reset all steps to pending
    for (var step in _steps) {
      _updateStep(step.id, AuthStatus.pending);
    }

    final nic = _nicController.text.trim().toUpperCase();
    final password = _passwordController.text;

    try {
      // Step 1: Authenticate user
      _updateStep('auth', AuthStatus.loading);
      await Future.delayed(const Duration(milliseconds: 200));

      final authResult = await _apiService.authenticateStaff(nic, password);

      print('Auth Result: $authResult');

      if (!authResult['success']) {
        _updateStep(
          'auth',
          AuthStatus.failed,
          message: authResult['error'] ?? 'Authentication failed',
        );
        _showError(authResult['error'] ?? 'Invalid NIC or password');
        return;
      }

      _updateStep('auth', AuthStatus.completed, message: 'Verified: $nic');
      await Future.delayed(const Duration(milliseconds: 200));

      final data = authResult['data'];
      print('Auth Data: $data');

      // Step 2: Check role - Handle null role properly
      _updateStep('role', AuthStatus.loading);
      await Future.delayed(const Duration(milliseconds: 200));

      final userRole = data['role']?.toString().toUpperCase() ?? '';
      print('User Role from response: $userRole');

      if (userRole.isEmpty) {
        _updateStep(
          'role',
          AuthStatus.failed,
          message: 'Role information missing from server response',
        );
        _showError('Role information missing. Please contact support.');
        return;
      }

      if (userRole != 'STAFF') {
        _updateStep(
          'role',
          AuthStatus.failed,
          message: 'User role is $userRole, STAFF required',
        );
        _showError(
          'Access denied. Only staff members can use the QR scanner.\nYour role: $userRole',
        );
        return;
      }

      _updateStep('role', AuthStatus.completed, message: 'Staff role verified');
      await Future.delayed(const Duration(milliseconds: 200));

      // Step 3: Verify staff record
      _updateStep('staff', AuthStatus.loading);
      await Future.delayed(const Duration(milliseconds: 200));

      final staffId = data['staffId'];
      print('Staff ID: $staffId');

      if (staffId == null || staffId == 0) {
        _updateStep(
          'staff',
          AuthStatus.failed,
          message: 'Staff record not found',
        );
        _showError(
          'Staff record not found. Please contact your station owner.',
        );
        return;
      }

      _updateStep('staff', AuthStatus.completed, message: 'Staff ID: $staffId');
      await Future.delayed(const Duration(milliseconds: 200));

      // Step 4: Load station details
      _updateStep('station', AuthStatus.loading);
      await Future.delayed(const Duration(milliseconds: 200));

      final stationId = data['stationId'];
      final stationName = data['stationName'];
      final stationBrand = data['stationBrand'];

      print('Station ID: $stationId, Name: $stationName');

      if (stationId == null || stationId == 0) {
        _updateStep(
          'station',
          AuthStatus.failed,
          message: 'Station information not found',
        );
        _showError('Station information not found.');
        return;
      }

      _updateStep(
        'station',
        AuthStatus.completed,
        message: '$stationName (${stationBrand ?? 'Unknown'})',
      );
      await Future.delayed(const Duration(milliseconds: 200));

      // Step 5: Save data and complete
      _updateStep('complete', AuthStatus.loading);
      await Future.delayed(const Duration(milliseconds: 200));

      // Save staff data locally
      await _apiService.saveStaffData(data);

      // Save token using static method
      if (data['token'] != null && data['token'].toString().isNotEmpty) {
        await ApiService.saveToken(data['token']);
        print('Token saved successfully');
      }

      _updateStep(
        'complete',
        AuthStatus.completed,
        message: 'Welcome, ${data['staffName'] ?? 'Staff'}!',
      );
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _isLoading = false;
        });

        // Close dialog and call success callback
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (e, stackTrace) {
      print('Authentication error: $e');
      print('Stack trace: $stackTrace');

      _updateStep('auth', AuthStatus.failed, message: 'Error: ${e.toString()}');
      _showError('Authentication failed: ${e.toString()}');

      setState(() {
        _isAuthenticating = false;
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
      _isLoading = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Text(
              'Authentication Failed',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message, style: GoogleFonts.inter(fontSize: 14)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Close auth dialog
              widget.onFailure();
            },
            child: Text(
              'Dismiss',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                color: AppColors.ocean,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nicController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [AppColors.emerald, AppColors.ocean],
                ),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Staff Authentication',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please verify your credentials to access the QR scanner',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
            const SizedBox(height: 20),

            if (!_isAuthenticating) ...[
              // Login Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      label: 'NIC Number',
                      hint: 'e.g. 200012345678',
                      controller: _nicController,
                      prefixIcon: Icons.badge_outlined,
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'NIC is required';
                        }
                        final nic = v.trim().toUpperCase();
                        final newNic = RegExp(r'^\d{12}$').hasMatch(nic);
                        final oldNic = RegExp(r'^\d{9}[VX]$').hasMatch(nic);
                        if (!newNic && !oldNic) {
                          return 'Enter a valid NIC';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixWidget: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Verify & Continue',
                onPressed: _handleAuthentication,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 12),
              OutlinedAppButton(
                label: 'Cancel',
                onPressed: () {
                  Navigator.pop(context);
                  widget.onFailure();
                },
                icon: Icons.close_rounded,
              ),
            ] else ...[
              // Progress Steps
              Column(
                children: _steps
                    .map((step) => _buildStepWidget(step, isDark))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepWidget(AuthStep step, bool isDark) {
    Color getStatusColor() {
      switch (step.status) {
        case AuthStatus.completed:
          return AppColors.emerald;
        case AuthStatus.failed:
          return AppColors.error;
        case AuthStatus.loading:
          return AppColors.ocean;
        default:
          return isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
      }
    }

    IconData getStatusIcon() {
      switch (step.status) {
        case AuthStatus.completed:
          return Icons.check_circle_rounded;
        case AuthStatus.failed:
          return Icons.error_outline;
        case AuthStatus.loading:
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
            child: step.status == AuthStatus.loading
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
                    color: step.status == AuthStatus.failed
                        ? AppColors.error
                        : (isDark ? AppColors.darkText : AppColors.lightText),
                  ),
                ),
                Text(
                  step.message ?? step.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: step.status == AuthStatus.failed
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
}

enum AuthStatus { pending, loading, completed, failed }

class AuthStep {
  final String id;
  final String title;
  final String subtitle;
  final AuthStatus status;
  final IconData icon;
  final String? message;

  AuthStep({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
    this.message,
  });

  AuthStep copyWith({
    String? id,
    String? title,
    String? subtitle,
    AuthStatus? status,
    IconData? icon,
    String? message,
  }) {
    return AuthStep(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
      icon: icon ?? this.icon,
      message: message ?? this.message,
    );
  }
}
