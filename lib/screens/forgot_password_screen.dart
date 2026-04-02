import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_button.dart';
import 'delete_account_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();

  // Step tracking: 0=email, 1=otp, 2=reset password
  int _currentStep = 0;

  // Controllers
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // Form keys
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  // State variables
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _resendSeconds = 0;
  Timer? _resendTimer;
  String? _resetToken;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    _resendTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendResetOTP() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _apiService.sendPasswordResetOTP(
      _emailCtrl.text.trim(),
    );

    if (!mounted) return;

    if (result['success']) {
      _startResendTimer();
      setState(() => _currentStep = 1);
      showAppSnackbar(
        context,
        message: 'OTP sent to ${_maskEmail(_emailCtrl.text.trim())}',
        isSuccess: true,
      );
    } else {
      showAppSnackbar(context, message: result['error'], isError: true);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _verifyOTP() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      showAppSnackbar(context, message: 'Enter 6-digit OTP', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.verifyPasswordResetOTP(
      _emailCtrl.text.trim(),
      otp,
    );

    if (!mounted) return;

    if (result['success']) {
      _resetToken = result['resetToken'];
      setState(() => _currentStep = 2);
      showAppSnackbar(
        context,
        message: 'OTP verified! Set your new password.',
        isSuccess: true,
      );
    } else {
      showAppSnackbar(context, message: result['error'], isError: true);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _apiService.resetPassword(
      _emailCtrl.text.trim(),
      _otpCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;

    if (result['success']) {
      showAppSnackbar(
        context,
        message: 'Password reset successful! Please login.',
        isSuccess: true,
      );
      Navigator.pop(context);
    } else {
      showAppSnackbar(context, message: result['error'], isError: true);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _resendOTP() async {
    if (_resendSeconds > 0) return;

    setState(() => _isLoading = true);

    final result = await _apiService.sendPasswordResetOTP(
      _emailCtrl.text.trim(),
    );

    if (!mounted) return;

    if (result['success']) {
      _startResendTimer();
      showAppSnackbar(
        context,
        message: 'OTP resent to ${_maskEmail(_emailCtrl.text.trim())}',
        isSuccess: true,
      );
    } else {
      showAppSnackbar(context, message: result['error'], isError: true);
    }

    setState(() => _isLoading = false);
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0], domain = parts[1];
    if (name.length <= 2) return '**@$domain';
    return name[0] +
        ('*' * (name.length - 2)) +
        name[name.length - 1] +
        '@' +
        domain;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0D1117), const Color(0xFF0A1628)]
                : [const Color(0xFFF0FDF8), const Color(0xFFEFF6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isDark
                                  ? AppColors.darkSurfaceAlt
                                  : AppColors.lightSurfaceAlt,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextSub
                                  : AppColors.lightTextSub,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Reset Password',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Step indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        _StepCircle(
                          number: 1,
                          active: _currentStep >= 0,
                          completed: _currentStep > 0,
                          isDark: isDark,
                        ),
                        _StepLine(active: _currentStep > 0, isDark: isDark),
                        _StepCircle(
                          number: 2,
                          active: _currentStep >= 1,
                          completed: _currentStep > 1,
                          isDark: isDark,
                        ),
                        _StepLine(active: _currentStep > 1, isDark: isDark),
                        _StepCircle(
                          number: 3,
                          active: _currentStep >= 2,
                          completed: false,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_currentStep == 0) ...[
                            _buildStepHeader(
                              icon: Icons.email_outlined,
                              title: 'Forgot Password?',
                              subtitle:
                                  'Enter your registered email address to receive a verification code.',
                              gradient: [AppColors.ocean, AppColors.emerald],
                              isDark: isDark,
                            ),
                            const SizedBox(height: 28),
                            Form(
                              key: _emailFormKey,
                              child: Column(
                                children: [
                                  AppTextField(
                                    label: 'Email Address',
                                    hint: 'you@example.com',
                                    controller: _emailCtrl,
                                    prefixIcon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Email is required';
                                      }
                                      if (!RegExp(
                                        r'^[^@]+@[^@]+\.[^@]+',
                                      ).hasMatch(v.trim())) {
                                        return 'Enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 28),
                                  GradientButton(
                                    label: 'Send Reset Code',
                                    onPressed: _sendResetOTP,
                                    isLoading: _isLoading,
                                    colors: [
                                      AppColors.ocean,
                                      AppColors.emerald,
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // Divider
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: isDark
                                              ? AppColors.darkBorder
                                              : AppColors.lightBorder,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          'or',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: isDark
                                              ? AppColors.darkBorder
                                              : AppColors.lightBorder,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Delete Account option
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const DeleteAccountScreen(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        color: AppColors.error.withOpacity(
                                          isDark ? 0.08 : 0.05,
                                        ),
                                        border: Border.all(
                                          color: AppColors.error.withOpacity(
                                            0.3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              color: AppColors.error
                                                  .withOpacity(0.15),
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppColors.error,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Can\'t access your email?',
                                                  style:
                                                      GoogleFonts.spaceGrotesk(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isDark
                                                            ? AppColors.darkText
                                                            : AppColors
                                                                  .lightText,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Permanently delete your account',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: AppColors.error,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 14,
                                            color: AppColors.error,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (_currentStep == 1) ...[
                            _buildStepHeader(
                              icon: Icons.verified_outlined,
                              title: 'Verify Your Identity',
                              subtitle:
                                  'Enter the 6-digit code sent to ${_maskEmail(_emailCtrl.text)}',
                              gradient: [AppColors.emerald, AppColors.ocean],
                              isDark: isDark,
                            ),
                            const SizedBox(height: 28),
                            Form(
                              key: _otpFormKey,
                              child: Column(
                                children: [
                                  _OtpInputField(
                                    controller: _otpCtrl,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_resendSeconds > 0)
                                        Text(
                                          'Resend in ${_resendSeconds}s',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        )
                                      else
                                        GestureDetector(
                                          onTap: _resendOTP,
                                          child: Text(
                                            'Resend Code',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: AppColors.ocean,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 28),
                                  GradientButton(
                                    label: 'Verify & Continue',
                                    onPressed: _verifyOTP,
                                    isLoading: _isLoading,
                                    colors: [
                                      AppColors.emerald,
                                      AppColors.ocean,
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (_currentStep == 2) ...[
                            _buildStepHeader(
                              icon: Icons.lock_reset_outlined,
                              title: 'Create New Password',
                              subtitle: 'Enter your new password below',
                              gradient: [AppColors.emerald, AppColors.ocean],
                              isDark: isDark,
                            ),
                            const SizedBox(height: 28),
                            Form(
                              key: _resetFormKey,
                              child: Column(
                                children: [
                                  AppTextField(
                                    label: 'New Password',
                                    controller: _passwordCtrl,
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
                                      if (v.length < 8) {
                                        return 'At least 8 characters';
                                      }
                                      if (!RegExp(r'[A-Z]').hasMatch(v)) {
                                        return 'Include one uppercase letter';
                                      }
                                      if (!RegExp(r'[0-9]').hasMatch(v)) {
                                        return 'Include one number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  AppTextField(
                                    label: 'Confirm Password',
                                    controller: _confirmPassCtrl,
                                    obscureText: _obscureConfirmPassword,
                                    prefixIcon: Icons.lock_reset_outlined,
                                    suffixWidget: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Please confirm password';
                                      }
                                      if (v != _passwordCtrl.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: AppColors.ocean.withOpacity(
                                        isDark ? 0.08 : 0.05,
                                      ),
                                      border: Border.all(
                                        color: AppColors.ocean.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 16,
                                          color: AppColors.ocean,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Min 8 chars · 1 uppercase letter · 1 number',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppColors.ocean,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  GradientButton(
                                    label: 'Reset Password',
                                    onPressed: _resetPassword,
                                    isLoading: _isLoading,
                                    colors: [
                                      AppColors.emerald,
                                      AppColors.ocean,
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int number;
  final bool active;
  final bool completed;
  final bool isDark;

  const _StepCircle({
    required this.number,
    required this.active,
    required this.completed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    if (completed) {
      bgColor = AppColors.emerald;
    } else if (active) {
      bgColor = AppColors.ocean;
    } else {
      bgColor = isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(
          color: active || completed
              ? Colors.transparent
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1.5,
        ),
      ),
      child: Center(
        child: completed
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : Text(
                '$number',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active || completed
                      ? Colors.white
                      : (isDark
                            ? AppColors.darkTextSub
                            : AppColors.lightTextSub),
                ),
              ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  final bool isDark;

  const _StepLine({required this.active, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1),
          color: active
              ? AppColors.emerald
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
    );
  }
}

class _OtpInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;

  const _OtpInputField({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 8,
        color: isDark ? AppColors.darkText : AppColors.lightText,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '------',
        hintStyle: GoogleFonts.spaceGrotesk(
          fontSize: 28,
          letterSpacing: 8,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.emerald, width: 2),
        ),
      ),
    );
  }
}
