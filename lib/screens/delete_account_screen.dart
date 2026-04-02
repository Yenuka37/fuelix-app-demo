import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_button.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  final _nicController = TextEditingController();
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<String> _quickReasons = [
    'Cannot access my email/mobile',
    'No longer need the account',
    'Created account by mistake',
    'Privacy concerns',
    'Other',
  ];

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
    _nicController.dispose();
    _reasonController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _selectReason(String reason) {
    setState(() {
      _reasonController.text = reason;
    });
  }

  Future<void> _deleteAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _apiService.deleteAccount(
      _nicController.text.trim().toUpperCase(),
      _reasonController.text.trim(),
    );

    if (!mounted) return;

    if (result['success']) {
      showAppSnackbar(
        context,
        message: 'Account permanently deleted. We\'re sorry to see you go.',
        isSuccess: true,
      );
      // Navigate back to login screen
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } else {
      showAppSnackbar(context, message: result['error'], isError: true);
    }

    setState(() => _isLoading = false);
  }

  void _showConfirmationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.error.withOpacity(0.15),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Delete Account?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is PERMANENT and cannot be undone.',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Deleting your account will permanently remove:',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
            const SizedBox(height: 8),
            _bulletPoint('All your registered vehicles'),
            _bulletPoint('Fuel Pass QR codes'),
            _bulletPoint('Fuel consumption history'),
            _bulletPoint('Wallet balance and transactions'),
            _bulletPoint('All personal information'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.spaceGrotesk(
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAccount();
            },
            child: Text(
              'Delete Permanently',
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

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.close_rounded, size: 14, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 12))),
        ],
      ),
    );
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
                        Expanded(
                          child: Text(
                            'Delete Account',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Warning banner
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: AppColors.error.withOpacity(
                          isDark ? 0.12 : 0.08,
                        ),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.error,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This action is permanent and cannot be undone. All your data will be lost.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.error,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStepHeader(
                              icon: Icons.person_remove_outlined,
                              title: 'Verify Your Identity',
                              subtitle:
                                  'Enter your NIC number to confirm account ownership',
                              gradient: [AppColors.error, AppColors.ocean],
                              isDark: isDark,
                            ),
                            const SizedBox(height: 28),

                            AppTextField(
                              label: 'NIC Number',
                              hint: 'e.g. 200012345678 or 990123456V',
                              controller: _nicController,
                              prefixIcon: Icons.badge_outlined,
                              textCapitalization: TextCapitalization.characters,
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
                                  return 'Enter a valid NIC';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            _buildStepHeader(
                              icon: Icons.message_outlined,
                              title: 'Reason for Deletion',
                              subtitle:
                                  'Help us improve by sharing why you\'re leaving',
                              gradient: [AppColors.ocean, AppColors.emerald],
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),

                            // Quick reason chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _quickReasons.map((reason) {
                                final isSelected =
                                    _reasonController.text == reason;
                                return GestureDetector(
                                  onTap: () => _selectReason(reason),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: isSelected
                                          ? const LinearGradient(
                                              colors: [
                                                AppColors.error,
                                                AppColors.ocean,
                                              ],
                                            )
                                          : null,
                                      color: isSelected
                                          ? null
                                          : (isDark
                                                ? AppColors.darkSurfaceAlt
                                                : AppColors.lightSurfaceAlt),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.transparent
                                            : (isDark
                                                  ? AppColors.darkBorder
                                                  : AppColors.lightBorder),
                                      ),
                                    ),
                                    child: Text(
                                      reason,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark
                                                  ? AppColors.darkTextSub
                                                  : AppColors.lightTextSub),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            AppTextField(
                              label: 'Detailed Reason (Optional)',
                              hint: 'Tell us more about why you\'re leaving...',
                              controller: _reasonController,
                              prefixIcon: Icons.edit_note_outlined,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 28),

                            GradientButton(
                              label: 'Delete My Account',
                              onPressed: _showConfirmationDialog,
                              isLoading: _isLoading,
                              colors: [AppColors.error, AppColors.errorDark],
                            ),
                            const SizedBox(height: 16),

                            // Help text
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: AppColors.ocean.withOpacity(
                                  isDark ? 0.08 : 0.05,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.help_outline_rounded,
                                    size: 16,
                                    color: AppColors.ocean,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Need help? Contact support at support@fuelix.com',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.ocean,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
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
      ],
    );
  }
}
