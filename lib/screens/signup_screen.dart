import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';
import '../widgets/custom_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final _db = DbHelper();

  // Part 1 controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nicController = TextEditingController();
  final _formKey1 = GlobalKey<FormState>();

  // Part 2 controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey2 = GlobalKey<FormState>();

  int _currentPage = 0;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nicController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _validateAndGoNext() async {
    if (!_formKey1.currentState!.validate()) return;

    // Check NIC exists
    setState(() => _isLoading = true);
    final nicExists = await _db.nicExists(
      _nicController.text.trim().toUpperCase(),
    );
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

    setState(() => _currentPage = 1);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleSignup() async {
    if (!_formKey2.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Check email exists
      final emailExists = await _db.emailExists(
        _emailController.text.trim().toLowerCase(),
      );

      if (!mounted) return;

      if (emailExists) {
        showAppSnackbar(
          context,
          message: 'This email is already registered.',
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
      }

      final newUser = UserModel(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        nic: _nicController.text.trim().toUpperCase(),
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
        createdAt: DateTime.now(),
      );

      final id = await _db.insertUser(newUser);

      if (!mounted) return;

      if (id > 0) {
        showAppSnackbar(
          context,
          message: 'Account created successfully! Please sign in.',
          isSuccess: true,
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        showAppSnackbar(
          context,
          message: 'Failed to create account. Please try again.',
          isError: true,
        );
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

  void _goBack() {
    if (_currentPage == 1) {
      setState(() => _currentPage = 0);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
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
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      _BackButton(onTap: _goBack, isDark: isDark),
                      const Spacer(),
                      // Step badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: isDark
                              ? AppColors.darkSurfaceAlt
                              : AppColors.lightSurfaceAlt,
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Text(
                          'Step ${_currentPage + 1} of 2',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSub
                                : AppColors.lightTextSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Step indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: StepIndicator(
                    currentStep: _currentPage,
                    totalSteps: 2,
                  ),
                ),
                const SizedBox(height: 32),
                // Page content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _Part1(
                        firstNameController: _firstNameController,
                        lastNameController: _lastNameController,
                        nicController: _nicController,
                        formKey: _formKey1,
                        isDark: isDark,
                        isLoading: _isLoading,
                        onNext: _validateAndGoNext,
                      ),
                      _Part2(
                        emailController: _emailController,
                        passwordController: _passwordController,
                        confirmPasswordController: _confirmPasswordController,
                        formKey: _formKey2,
                        isDark: isDark,
                        isLoading: _isLoading,
                        onSubmit: _handleSignup,
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

// ─── Part 1 Widget ────────────────────────────────────────────────────────────
class _Part1 extends StatelessWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController nicController;
  final GlobalKey<FormState> formKey;
  final bool isDark;
  final bool isLoading;
  final VoidCallback onNext;

  const _Part1({
    required this.firstNameController,
    required this.lastNameController,
    required this.nicController,
    required this.formKey,
    required this.isDark,
    required this.isLoading,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.person_outlined,
            title: 'Personal Info',
            subtitle: 'Tell us your name and ID details',
            isDark: isDark,
          ),
          const SizedBox(height: 32),
          Form(
            key: formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'First Name',
                        controller: firstNameController,
                        prefixIcon: Icons.person_outline,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          if (v.trim().length < 2) {
                            return 'Too short';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: 'Last Name',
                        controller: lastNameController,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          if (v.trim().length < 2) {
                            return 'Too short';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'NIC Number',
                  hint: 'e.g. 200012345678 or 990123456V',
                  controller: nicController,
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
                      return 'Enter valid NIC (12 digits or 9 digits + V/X)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
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

// ─── Part 2 Widget ────────────────────────────────────────────────────────────
class _Part2 extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final GlobalKey<FormState> formKey;
  final bool isDark;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _Part2({
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.formKey,
    required this.isDark,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.lock_outlined,
            title: 'Account Setup',
            subtitle: 'Set up your email and password',
            isDark: isDark,
          ),
          const SizedBox(height: 32),
          Form(
            key: formKey,
            child: Column(
              children: [
                AppTextField(
                  label: 'Email Address',
                  hint: 'you@example.com',
                  controller: emailController,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  controller: passwordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Password is required';
                    }
                    if (v.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (!RegExp(r'[A-Z]').hasMatch(v)) {
                      return 'Must contain at least one uppercase letter';
                    }
                    if (!RegExp(r'[0-9]').hasMatch(v)) {
                      return 'Must contain at least one number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Confirm Password',
                  controller: confirmPasswordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_reset_outlined,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (v != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password hints
                _PasswordHintBox(isDark: isDark),
                const SizedBox(height: 28),
                GradientButton(
                  label: 'Create Account',
                  onPressed: onSubmit,
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

// ─── Section Header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
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
            gradient: const LinearGradient(
              colors: [AppColors.emerald, AppColors.ocean],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Password Hint Box ────────────────────────────────────────────────────────
class _PasswordHintBox extends StatelessWidget {
  final bool isDark;
  const _PasswordHintBox({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.ocean.withOpacity(isDark ? 0.08 : 0.05),
        border: Border.all(color: AppColors.ocean.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.ocean),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Password must be at least 8 characters, include one uppercase letter and one number.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.ocean,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Back Button ─────────────────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _BackButton({required this.onTap, required this.isDark});

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
