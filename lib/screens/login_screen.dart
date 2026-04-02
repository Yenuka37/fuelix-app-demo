import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/custom_button.dart';
import 'onboarding_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nicController = TextEditingController();
  final _passwordController = TextEditingController();
  final _db = DbHelper();
  final _apiService = ApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _nicController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.login(
        _nicController.text.trim().toUpperCase(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (result['success']) {
        final userData = result['data'];

        // Create UserModel from API response
        final user = UserModel(
          id: userData['id'],
          firstName: userData['firstName'],
          lastName: userData['lastName'],
          nic: userData['nic'],
          mobile: userData['mobile'],
          addressLine1: userData['addressLine1'] ?? '',
          addressLine2: userData['addressLine2'] ?? '',
          addressLine3: userData['addressLine3'] ?? '',
          district: userData['district'] ?? '',
          province: userData['province'] ?? '',
          postalCode: userData['postalCode'] ?? '',
          email: userData['email'],
          password: _passwordController.text,
          createdAt: userData['createdAt'] != null
              ? DateTime.tryParse(userData['createdAt'])
              : null,
        );

        // Check if user exists in local DB, if not, save them
        final existingUser = await _db.getUserByNic(user.nic);
        if (existingUser == null) {
          await _db.insertUser(user);
        } else {
          // Update local user data if needed
          await _db.updateUser(user);
        }

        showAppSnackbar(
          context,
          message: 'Welcome back, ${user.firstName}!',
          isSuccess: true,
        );

        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        final onboardingSeen = await TutorialService.isSeen(
          TutorialKey.onboarding,
        );
        if (!mounted) return;

        if (!onboardingSeen) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => OnboardingScreen(user: user)),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/home', arguments: user);
        }
      } else {
        showAppSnackbar(context, message: result['error'], isError: true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(
          context,
          message: 'An error occurred. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              height: size.height - MediaQuery.of(context).padding.top,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 60),
                        // Logo + Brand
                        _buildBrandHeader(isDark),
                        const SizedBox(height: 48),
                        // Headline
                        Text(
                          'Welcome\nback.',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to your Fuelix account',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSub
                                    : AppColors.lightTextSub,
                              ),
                        ),
                        const SizedBox(height: 40),
                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              AppTextField(
                                label: 'NIC Number',
                                hint: 'e.g. 200012345678',
                                controller: _nicController,
                                prefixIcon: Icons.badge_outlined,
                                textCapitalization:
                                    TextCapitalization.characters,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'NIC is required';
                                  }
                                  final nic = v.trim().toUpperCase();
                                  final newNic = RegExp(
                                    r'^\d{12}$',
                                  ).hasMatch(nic);
                                  final oldNic = RegExp(
                                    r'^\d{9}[VX]$',
                                  ).hasMatch(nic);
                                  if (!newNic && !oldNic) {
                                    return 'Enter a valid NIC (e.g. 200012345678 or 990123456V)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
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
                              const SizedBox(height: 8),
                              // Forgot Password Link
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot Password?',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.ocean,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              GradientButton(
                                label: 'Sign In',
                                onPressed: _handleLogin,
                                isLoading: _isLoading,
                              ),
                            ],
                          ),
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
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
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
                        const SizedBox(height: 24),
                        // Sign up button
                        OutlinedAppButton(
                          label: 'Create new account',
                          icon: Icons.person_add_outlined,
                          onPressed: () {
                            Navigator.pushNamed(context, '/signup');
                          },
                        ),
                        const Spacer(),
                        // Footer
                        Center(
                          child: Text(
                            'Fuelix v1.0 · Secure & Encrypted',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader(bool isDark) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [AppColors.emerald, AppColors.ocean],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.emerald.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_gas_station_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.emerald, AppColors.ocean],
          ).createShader(bounds),
          child: Text(
            'FUELIX',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
        ),
      ],
    );
  }
}
