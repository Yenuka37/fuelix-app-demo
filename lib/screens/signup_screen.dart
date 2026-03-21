import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';
import '../widgets/custom_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sri Lanka data
// ─────────────────────────────────────────────────────────────────────────────
const List<String> _kProvinces = [
  'Western',
  'Central',
  'Southern',
  'Northern',
  'Eastern',
  'North Western',
  'North Central',
  'Uva',
  'Sabaragamuwa',
];

const Map<String, List<String>> _kDistrictsByProvince = {
  'Western': ['Colombo', 'Gampaha', 'Kalutara'],
  'Central': ['Kandy', 'Matale', 'Nuwara Eliya'],
  'Southern': ['Galle', 'Matara', 'Hambantota'],
  'Northern': ['Jaffna', 'Kilinochchi', 'Mannar', 'Mullaitivu', 'Vavuniya'],
  'Eastern': ['Ampara', 'Batticaloa', 'Trincomalee'],
  'North Western': ['Kurunegala', 'Puttalam'],
  'North Central': ['Anuradhapura', 'Polonnaruwa'],
  'Uva': ['Badulla', 'Monaragala'],
  'Sabaragamuwa': ['Kegalle', 'Ratnapura'],
};

// ─────────────────────────────────────────────────────────────────────────────
// Main SignupScreen
// ─────────────────────────────────────────────────────────────────────────────
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _db = DbHelper();

  // ── Step 1 ─────────────────────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _nicCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _formKey1 = GlobalKey<FormState>();

  // ── Step 2 ─────────────────────────────────────────────────────────────────
  final _addr1Ctrl = TextEditingController();
  final _addr2Ctrl = TextEditingController();
  final _addr3Ctrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  String? _selectedProvince;
  String? _selectedDistrict;
  final _formKey2 = GlobalKey<FormState>();

  // ── Step 3 ─────────────────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _formKey3 = GlobalKey<FormState>();

  // ── Step 4 – OTP ───────────────────────────────────────────────────────────
  // otpPhase: 0=mobile pending, 1=email pending, 2=complete
  int _otpPhase = 0;
  String _mobileOtp = '';
  String _emailOtp = '';
  bool _mobileVerified = false;
  bool _emailVerified = false;

  int _currentPage = 0;
  bool _isLoading = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _nicCtrl.dispose();
    _mobileCtrl.dispose();
    _addr1Ctrl.dispose();
    _addr2Ctrl.dispose();
    _addr3Ctrl.dispose();
    _postalCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────
  void _goBack() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _nextPage() {
    setState(() => _currentPage++);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // ── Step 1 validate ────────────────────────────────────────────────────────
  Future<void> _step1Next() async {
    if (!_formKey1.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final nicExists = await _db.nicExists(_nicCtrl.text.trim().toUpperCase());
    final mobileExists = await _db.mobileExists(_mobileCtrl.text.trim());
    setState(() => _isLoading = false);
    if (!mounted) return;

    if (nicExists) {
      showAppSnackbar(
        context,
        message: 'This NIC is already registered.',
        isError: true,
      );
      return;
    }
    if (mobileExists) {
      showAppSnackbar(
        context,
        message: 'This mobile number is already registered.',
        isError: true,
      );
      return;
    }
    _nextPage();
  }

  // ── Step 2 validate ────────────────────────────────────────────────────────
  void _step2Next() {
    if (!_formKey2.currentState!.validate()) return;
    _nextPage();
  }

  // ── Step 3 validate ────────────────────────────────────────────────────────
  Future<void> _step3Next() async {
    if (!_formKey3.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final emailExists = await _db.emailExists(
      _emailCtrl.text.trim().toLowerCase(),
    );
    setState(() => _isLoading = false);
    if (!mounted) return;

    if (emailExists) {
      showAppSnackbar(
        context,
        message: 'This email is already registered.',
        isError: true,
      );
      return;
    }

    // Generate mobile OTP first — email OTP generated after mobile is verified
    _mobileOtp = _generateOtp();
    setState(() {
      _otpPhase = 0;
      _mobileVerified = false;
      _emailVerified = false;
    });

    // Demo: show OTP in snackbar (production → SMS gateway)
    showAppSnackbar(context, message: 'Mobile OTP sent → $_mobileOtp');
    _nextPage();
  }

  // Called by _Step4 when mobile OTP is confirmed — generate & send email OTP
  void _onMobileVerified() {
    _emailOtp = _generateOtp();
    setState(() {
      _otpPhase = 1;
      _mobileVerified = true;
    });
    // Demo: show OTP in snackbar (production → email gateway)
    showAppSnackbar(context, message: 'Email OTP sent → $_emailOtp');
  }

  void _onEmailVerified() {
    setState(() {
      _otpPhase = 2;
      _emailVerified = true;
    });
  }

  // Resend current-phase OTP
  void _resendOtp() {
    if (_otpPhase == 0) {
      _mobileOtp = _generateOtp();
      showAppSnackbar(context, message: 'Mobile OTP resent → $_mobileOtp');
    } else if (_otpPhase == 1) {
      _emailOtp = _generateOtp();
      showAppSnackbar(context, message: 'Email OTP resent → $_emailOtp');
    }
    setState(() {});
  }

  // ── Step 4 – final signup ──────────────────────────────────────────────────
  Future<void> _finalSignup() async {
    setState(() => _isLoading = true);
    try {
      final user = UserModel(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        nic: _nicCtrl.text.trim().toUpperCase(),
        mobile: _mobileCtrl.text.trim(),
        addressLine1: _addr1Ctrl.text.trim(),
        addressLine2: _addr2Ctrl.text.trim(),
        addressLine3: _addr3Ctrl.text.trim(),
        district: _selectedDistrict ?? '',
        province: _selectedProvince ?? '',
        postalCode: _postalCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passwordCtrl.text,
        createdAt: DateTime.now(),
      );

      final id = await _db.insertUser(user);
      if (!mounted) return;

      if (id > 0) {
        showAppSnackbar(
          context,
          message: 'Account created! Please sign in.',
          isSuccess: true,
        );
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      } else {
        showAppSnackbar(
          context,
          message: 'Failed to create account. Try again.',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted)
        showAppSnackbar(context, message: 'An error occurred.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _generateOtp() => (100000 + Random().nextInt(900000)).toString();

  // ── Build ──────────────────────────────────────────────────────────────────
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
            child: Column(
              children: [
                // ── Top bar ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      _BackBtn(onTap: _goBack, isDark: isDark),
                      const Spacer(),
                      _StepBadge(
                        current: _currentPage + 1,
                        total: 4,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ── Step indicator ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _StepDots(current: _currentPage, total: 4),
                ),
                const SizedBox(height: 28),
                // ── Pages ────────────────────────────────────────────────────
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _Step1(
                        firstNameCtrl: _firstNameCtrl,
                        lastNameCtrl: _lastNameCtrl,
                        nicCtrl: _nicCtrl,
                        mobileCtrl: _mobileCtrl,
                        formKey: _formKey1,
                        isDark: isDark,
                        isLoading: _isLoading,
                        onNext: _step1Next,
                      ),
                      _Step2(
                        addr1Ctrl: _addr1Ctrl,
                        addr2Ctrl: _addr2Ctrl,
                        addr3Ctrl: _addr3Ctrl,
                        postalCtrl: _postalCtrl,
                        province: _selectedProvince,
                        district: _selectedDistrict,
                        onProvince: (v) => setState(() {
                          _selectedProvince = v;
                          _selectedDistrict = null;
                        }),
                        onDistrict: (v) =>
                            setState(() => _selectedDistrict = v),
                        formKey: _formKey2,
                        isDark: isDark,
                        isLoading: _isLoading,
                        onNext: _step2Next,
                      ),
                      _Step3(
                        emailCtrl: _emailCtrl,
                        passwordCtrl: _passwordCtrl,
                        confirmPassCtrl: _confirmPassCtrl,
                        formKey: _formKey3,
                        isDark: isDark,
                        isLoading: _isLoading,
                        onNext: _step3Next,
                      ),
                      _Step4(
                        mobile: _mobileCtrl.text,
                        email: _emailCtrl.text,
                        mobileOtp: _mobileOtp,
                        emailOtp: _emailOtp,
                        otpPhase: _otpPhase,
                        mobileVerified: _mobileVerified,
                        emailVerified: _emailVerified,
                        isDark: isDark,
                        isLoading: _isLoading,
                        onMobileVerified: _onMobileVerified,
                        onEmailVerified: _onEmailVerified,
                        onResend: _resendOtp,
                        onSubmit: _finalSignup,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STEP 1 – Personal Information
// ═════════════════════════════════════════════════════════════════════════════
class _Step1 extends StatelessWidget {
  final TextEditingController firstNameCtrl, lastNameCtrl, nicCtrl, mobileCtrl;
  final GlobalKey<FormState> formKey;
  final bool isDark, isLoading;
  final VoidCallback onNext;

  const _Step1({
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.nicCtrl,
    required this.mobileCtrl,
    required this.formKey,
    required this.isDark,
    required this.isLoading,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            icon: Icons.person_outline_rounded,
            title: 'Personal Info',
            subtitle: 'Your name, NIC and mobile number',
            gradient: [AppColors.emerald, AppColors.ocean],
          ),
          const SizedBox(height: 28),
          Form(
            key: formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'First Name',
                        controller: firstNameCtrl,
                        prefixIcon: Icons.person_outline,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.trim().length < 2) return 'Too short';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: 'Last Name',
                        controller: lastNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.trim().length < 2) return 'Too short';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'NIC Number',
                  hint: '200012345678 or 990123456V',
                  controller: nicCtrl,
                  prefixIcon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'NIC is required';
                    final n = v.trim().toUpperCase();
                    if (!RegExp(r'^\d{12}$').hasMatch(n) &&
                        !RegExp(r'^\d{9}[VX]$').hasMatch(n)) {
                      return 'Invalid NIC format';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Mobile Number',
                  hint: '0771234567',
                  controller: mobileCtrl,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Mobile is required';
                    if (!RegExp(r'^0[1-9]\d{8}$').hasMatch(v.trim())) {
                      return 'Enter a valid 10-digit number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                GradientButton(
                  label: 'Continue',
                  onPressed: onNext,
                  isLoading: isLoading,
                  colors: [AppColors.emerald, AppColors.ocean],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STEP 2 – Address Information
// ═════════════════════════════════════════════════════════════════════════════
class _Step2 extends StatelessWidget {
  final TextEditingController addr1Ctrl, addr2Ctrl, addr3Ctrl, postalCtrl;
  final String? province, district;
  final ValueChanged<String?> onProvince, onDistrict;
  final GlobalKey<FormState> formKey;
  final bool isDark, isLoading;
  final VoidCallback onNext;

  const _Step2({
    required this.addr1Ctrl,
    required this.addr2Ctrl,
    required this.addr3Ctrl,
    required this.postalCtrl,
    required this.province,
    required this.district,
    required this.onProvince,
    required this.onDistrict,
    required this.formKey,
    required this.isDark,
    required this.isLoading,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final districts = province != null
        ? (_kDistrictsByProvince[province!] ?? <String>[])
        : <String>[];

    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fillColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final labelColor = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            icon: Icons.location_on_outlined,
            title: 'Address',
            subtitle: 'Where are you located?',
            gradient: [AppColors.ocean, AppColors.emeraldLight],
          ),
          const SizedBox(height: 28),
          Form(
            key: formKey,
            child: Column(
              children: [
                // Address line 1
                AppTextField(
                  label: 'Address Line 1',
                  hint: 'House No / Street',
                  controller: addr1Ctrl,
                  prefixIcon: Icons.home_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Address line 1 is required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Address line 2 (optional)
                AppTextField(
                  label: 'Address Line 2 (optional)',
                  hint: 'Village / Town',
                  controller: addr2Ctrl,
                  prefixIcon: Icons.signpost_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                // Address line 3 (optional)
                AppTextField(
                  label: 'Address Line 3 (optional)',
                  hint: 'Area / Suburb',
                  controller: addr3Ctrl,
                  prefixIcon: Icons.location_city_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                // Province dropdown
                _AppDropdown(
                  label: 'Province',
                  value: province,
                  items: _kProvinces,
                  prefixIcon: Icons.map_outlined,
                  isDark: isDark,
                  onChanged: onProvince,
                  validator: (v) => v == null ? 'Select a province' : null,
                ),
                const SizedBox(height: 14),
                // District dropdown
                _AppDropdown(
                  label: 'District',
                  value: district,
                  items: districts,
                  prefixIcon: Icons.place_outlined,
                  isDark: isDark,
                  onChanged: province != null ? onDistrict : null,
                  validator: (v) => v == null ? 'Select a district' : null,
                  hint: province == null
                      ? 'Select province first'
                      : 'Select district',
                ),
                const SizedBox(height: 14),
                // Postal code
                AppTextField(
                  label: 'Postal Code',
                  hint: '00100',
                  controller: postalCtrl,
                  prefixIcon: Icons.markunread_mailbox_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Postal code is required';
                    if (v.trim().length != 5) return 'Must be 5 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                GradientButton(
                  label: 'Continue',
                  onPressed: onNext,
                  isLoading: isLoading,
                  colors: [AppColors.ocean, AppColors.emerald],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STEP 3 – Account Information
// ═════════════════════════════════════════════════════════════════════════════
class _Step3 extends StatelessWidget {
  final TextEditingController emailCtrl, passwordCtrl, confirmPassCtrl;
  final GlobalKey<FormState> formKey;
  final bool isDark, isLoading;
  final VoidCallback onNext;

  const _Step3({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.confirmPassCtrl,
    required this.formKey,
    required this.isDark,
    required this.isLoading,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            icon: Icons.lock_outline_rounded,
            title: 'Account Setup',
            subtitle: 'Create your login credentials',
            gradient: [AppColors.amber, AppColors.emerald],
          ),
          const SizedBox(height: 28),
          Form(
            key: formKey,
            child: Column(
              children: [
                AppTextField(
                  label: 'Email Address',
                  hint: 'you@example.com',
                  controller: emailCtrl,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Email is required';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  controller: passwordCtrl,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 8) return 'At least 8 characters';
                    if (!RegExp(r'[A-Z]').hasMatch(v))
                      return 'Include one uppercase letter';
                    if (!RegExp(r'[0-9]').hasMatch(v))
                      return 'Include one number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Confirm Password',
                  controller: confirmPassCtrl,
                  obscureText: true,
                  prefixIcon: Icons.lock_reset_outlined,
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return 'Please confirm password';
                    if (v != passwordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password hint box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.ocean.withOpacity(isDark ? 0.08 : 0.05),
                    border: Border.all(color: AppColors.ocean.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                  label: 'Send OTP',
                  onPressed: onNext,
                  isLoading: isLoading,
                  colors: [AppColors.amber, AppColors.emerald],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STEP 4 – Sequential OTP Verification  (mobile first → then email)
// ═════════════════════════════════════════════════════════════════════════════
class _Step4 extends StatefulWidget {
  final String mobile, email, mobileOtp, emailOtp;
  final int otpPhase; // 0=mobile, 1=email, 2=done
  final bool mobileVerified, emailVerified, isDark, isLoading;
  final VoidCallback onMobileVerified, onEmailVerified, onResend, onSubmit;

  const _Step4({
    required this.mobile,
    required this.email,
    required this.mobileOtp,
    required this.emailOtp,
    required this.otpPhase,
    required this.mobileVerified,
    required this.emailVerified,
    required this.isDark,
    required this.isLoading,
    required this.onMobileVerified,
    required this.onEmailVerified,
    required this.onResend,
    required this.onSubmit,
  });

  @override
  State<_Step4> createState() => _Step4State();
}

class _Step4State extends State<_Step4> {
  final _mobileOtpCtrl = TextEditingController();
  final _emailOtpCtrl = TextEditingController();

  // Resend cooldown — shared for both phases
  // Resend interval: 60 s (1st resend), 90 s (2nd), 120 s (3rd+)
  static const _intervals = [60, 90, 120];
  int _resendCount = 0;
  int _secondsLeft = 60;
  bool _canResend = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown(60);
  }

  @override
  void didUpdateWidget(_Step4 old) {
    super.didUpdateWidget(old);
    // When phase changes (mobile done → email phase) restart countdown
    if (old.otpPhase != widget.otpPhase) {
      _resendCount = 0;
      _emailOtpCtrl.clear();
      _startCountdown(60);
    }
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() {
      _secondsLeft = seconds;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        t.cancel();
        setState(() {
          _secondsLeft = 0;
          _canResend = true;
        });
      }
    });
  }

  void _handleResend() {
    if (!_canResend) return;
    widget.onResend();
    // Clear the input for the current phase
    if (widget.otpPhase == 0) _mobileOtpCtrl.clear();
    if (widget.otpPhase == 1) _emailOtpCtrl.clear();
    _resendCount++;
    final next = _intervals[_resendCount.clamp(0, _intervals.length - 1)];
    _startCountdown(next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mobileOtpCtrl.dispose();
    _emailOtpCtrl.dispose();
    super.dispose();
  }

  // ── Verify helpers ─────────────────────────────────────────────────────────
  void _verifyMobile() {
    final entered = _mobileOtpCtrl.text.trim();
    if (entered.length != 6) {
      showAppSnackbar(context, message: 'Enter the 6-digit OTP', isError: true);
      return;
    }
    if (entered == widget.mobileOtp) {
      widget.onMobileVerified(); // triggers email OTP generation
    } else {
      showAppSnackbar(
        context,
        message: 'Incorrect OTP. Try again.',
        isError: true,
      );
    }
  }

  void _verifyEmail() {
    final entered = _emailOtpCtrl.text.trim();
    if (entered.length != 6) {
      showAppSnackbar(context, message: 'Enter the 6-digit OTP', isError: true);
      return;
    }
    if (entered == widget.emailOtp) {
      widget.onEmailVerified();
    } else {
      showAppSnackbar(
        context,
        message: 'Incorrect OTP. Try again.',
        isError: true,
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final phase = widget.otpPhase;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            icon: Icons.verified_outlined,
            title: 'Verify Identity',
            subtitle: phase == 0
                ? 'Enter the OTP sent to your mobile'
                : phase == 1
                ? 'Mobile verified! Now check your email'
                : 'Both channels verified ✓',
            gradient: [const Color(0xFF7C3AED), AppColors.ocean],
          ),
          const SizedBox(height: 28),

          // ── Phase progress bar ───────────────────────────────────────────
          _PhaseProgress(phase: phase, isDark: isDark),
          const SizedBox(height: 24),

          // ── Mobile OTP card ──────────────────────────────────────────────
          _OtpCard(
            icon: Icons.phone_outlined,
            type: 'Mobile',
            maskedTarget: _maskMobile(widget.mobile),
            controller: _mobileOtpCtrl,
            isVerified: widget.mobileVerified,
            isActive: phase == 0,
            isDark: isDark,
            onVerify: _verifyMobile,
            accentColor: AppColors.emerald,
          ),
          const SizedBox(height: 14),

          // ── Email OTP card (locked until mobile is done) ─────────────────
          _OtpCard(
            icon: Icons.email_outlined,
            type: 'Email',
            maskedTarget: _maskEmail(widget.email),
            controller: _emailOtpCtrl,
            isVerified: widget.emailVerified,
            isActive: phase == 1,
            isLocked: phase == 0,
            isDark: isDark,
            onVerify: _verifyEmail,
            accentColor: AppColors.ocean,
          ),
          const SizedBox(height: 24),

          // ── Resend row ───────────────────────────────────────────────────
          if (phase < 2)
            _ResendRow(
              canResend: _canResend,
              secondsLeft: _secondsLeft,
              resendCount: _resendCount,
              isDark: isDark,
              onResend: _handleResend,
            ),

          if (phase < 2) const SizedBox(height: 28),

          // ── Create Account (only when both verified) ─────────────────────
          if (phase == 2) ...[
            _AllVerifiedBanner(isDark: isDark),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Create Account',
              onPressed: widget.onSubmit,
              isLoading: widget.isLoading,
              colors: [const Color(0xFF7C3AED), AppColors.ocean],
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  String _maskMobile(String m) {
    if (m.length < 4) return m;
    return '${m.substring(0, 3)}****${m.substring(m.length - 3)}';
  }

  String _maskEmail(String e) {
    final parts = e.split('@');
    if (parts.length != 2) return e;
    final name = parts[0], domain = parts[1];
    if (name.length <= 2) return '**@$domain';
    return name[0] +
        ('*' * (name.length - 2)) +
        name[name.length - 1] +
        '@' +
        domain;
  }
}

// ─── Phase Progress ───────────────────────────────────────────────────────────
class _PhaseProgress extends StatelessWidget {
  final int phase; // 0=mobile, 1=email, 2=done
  final bool isDark;
  const _PhaseProgress({required this.phase, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PhaseDot(
          label: 'Mobile',
          done: phase > 0,
          active: phase == 0,
          isDark: isDark,
          color: AppColors.emerald,
        ),
        _PhaseConnector(filled: phase > 0, isDark: isDark),
        _PhaseDot(
          label: 'Email',
          done: phase > 1,
          active: phase == 1,
          isDark: isDark,
          color: AppColors.ocean,
        ),
        _PhaseConnector(filled: phase > 1, isDark: isDark),
        _PhaseDot(
          label: 'Done',
          done: phase > 1,
          active: phase == 2,
          isDark: isDark,
          color: const Color(0xFF7C3AED),
        ),
      ],
    );
  }
}

class _PhaseDot extends StatelessWidget {
  final String label;
  final bool done, active, isDark;
  final Color color;
  const _PhaseDot({
    required this.label,
    required this.done,
    required this.active,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = done || active
        ? color
        : (isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt);
    final border = done || active
        ? color
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: border, width: 2),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : active
                ? Icon(
                    Icons.circle,
                    size: 8,
                    color: Colors.white.withOpacity(0.9),
                  )
                : Icon(
                    Icons.circle,
                    size: 8,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: done || active
                ? color
                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
        ),
      ],
    );
  }
}

class _PhaseConnector extends StatelessWidget {
  final bool filled, isDark;
  const _PhaseConnector({required this.filled, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            gradient: filled
                ? const LinearGradient(
                    colors: [AppColors.emerald, AppColors.ocean],
                  )
                : null,
            color: filled
                ? null
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
      ),
    );
  }
}

// ─── OTP Card ─────────────────────────────────────────────────────────────────
class _OtpCard extends StatelessWidget {
  final IconData icon;
  final String type, maskedTarget;
  final TextEditingController controller;
  final bool isVerified, isActive, isDark;
  final bool isLocked;
  final VoidCallback onVerify;
  final Color accentColor;

  const _OtpCard({
    required this.icon,
    required this.type,
    required this.maskedTarget,
    required this.controller,
    required this.isVerified,
    required this.isActive,
    required this.isDark,
    required this.onVerify,
    required this.accentColor,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isVerified
        ? AppColors.emerald.withOpacity(0.6)
        : isActive
        ? accentColor.withOpacity(0.5)
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isLocked ? 0.45 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: borderColor,
            width: isVerified || isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : isVerified
              ? [
                  BoxShadow(
                    color: AppColors.emerald.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isLocked
                        ? (isDark
                              ? AppColors.darkSurfaceAlt
                              : AppColors.lightSurfaceAlt)
                        : accentColor.withOpacity(isDark ? 0.15 : 0.08),
                  ),
                  child: Icon(
                    isLocked ? Icons.lock_outline_rounded : icon,
                    size: 17,
                    color: isLocked
                        ? (isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted)
                        : accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$type OTP',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      Text(
                        isLocked
                            ? 'Verify mobile first'
                            : isVerified
                            ? 'Sent to $maskedTarget'
                            : 'Sent to $maskedTarget',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                if (isVerified)
                  _VerifiedBadge()
                else if (isActive)
                  _PendingBadge(color: accentColor),
              ],
            ),

            // ── OTP input (only when active & not verified) ──────────────
            if (isActive && !isVerified) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _OtpInputField(
                      controller: controller,
                      isDark: isDark,
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onVerify,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [accentColor, accentColor.withOpacity(0.75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Verify',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.emerald.withOpacity(0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 13,
            color: AppColors.emerald,
          ),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.emerald,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final Color color;
  const _PendingBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pending_outlined, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            'Pending',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── OTP Input Field ──────────────────────────────────────────────────────────
class _OtpInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final Color accentColor;

  const _OtpInputField({
    required this.controller,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 8,
        color: isDark ? AppColors.darkText : AppColors.lightText,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '------',
        hintStyle: GoogleFonts.spaceGrotesk(
          fontSize: 22,
          letterSpacing: 8,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurfaceAlt
            : AppColors.lightSurfaceAlt,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
      ),
    );
  }
}

// ─── Resend Row ───────────────────────────────────────────────────────────────
class _ResendRow extends StatelessWidget {
  final bool canResend, isDark;
  final int secondsLeft, resendCount;
  final VoidCallback onResend;

  const _ResendRow({
    required this.canResend,
    required this.isDark,
    required this.secondsLeft,
    required this.resendCount,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: canResend
          ? GestureDetector(
              onTap: onResend,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.ocean.withOpacity(isDark ? 0.12 : 0.07),
                  border: Border.all(color: AppColors.ocean.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      size: 15,
                      color: AppColors.ocean,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      resendCount == 0 ? 'Resend OTP' : 'Resend again',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ocean,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Resend in ${secondsLeft}s',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── All Verified Banner ──────────────────────────────────────────────────────
class _AllVerifiedBanner extends StatelessWidget {
  final bool isDark;
  const _AllVerifiedBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.emerald.withOpacity(isDark ? 0.1 : 0.07),
        border: Border.all(color: AppColors.emerald.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.emerald.withOpacity(0.15),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppColors.emerald,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Identity Verified',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emerald,
                  ),
                ),
                Text(
                  'Mobile and email verified. You\'re all set!',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.emerald.withOpacity(0.8),
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

// ═════════════════════════════════════════════════════════════════════════════
// Shared UI helpers
// ═════════════════════════════════════════════════════════════════════════════

// ─── Step Header ──────────────────────────────────────────────────────────────
class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final List<Color> gradient;

  const _StepHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
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

// ─── Step Badge ───────────────────────────────────────────────────────────────
class _StepBadge extends StatelessWidget {
  final int current, total;
  final bool isDark;
  const _StepBadge({
    required this.current,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Text(
        'Step $current of $total',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
        ),
      ),
    );
  }
}

// ─── Step Dots (segmented bar) ────────────────────────────────────────────────
class _StepDots extends StatelessWidget {
  final int current, total;
  const _StepDots({required this.current, required this.total});

  static const _gradients = [
    [AppColors.emerald, AppColors.ocean],
    [AppColors.ocean, AppColors.emeraldLight],
    [AppColors.amber, AppColors.emerald],
    [Color(0xFF7C3AED), AppColors.ocean],
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isDone = i < current;
        final isActive = i == current;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: (isDone || isActive)
                    ? LinearGradient(colors: _gradients[i % _gradients.length])
                    : null,
                color: (isDone || isActive)
                    ? null
                    : (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Back Button ──────────────────────────────────────────────────────────────
class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  const _BackBtn({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 16,
          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
        ),
      ),
    );
  }
}

// ─── Dropdown ─────────────────────────────────────────────────────────────────
class _AppDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData prefixIcon;
  final bool isDark;
  final ValueChanged<String?>? onChanged;
  final String? Function(String?)? validator;
  final String? hint;

  const _AppDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.prefixIcon,
    required this.isDark,
    required this.onChanged,
    this.validator,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fillColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final hintColor = isDark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;

    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: hintColor),
      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      style: GoogleFonts.inter(fontSize: 14, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? 'Select $label',
        prefixIcon: Icon(
          prefixIcon,
          size: 20,
          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.emerald, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: GoogleFonts.inter(fontSize: 14, color: textColor),
              ),
            ),
          )
          .toList(),
    );
  }
}
