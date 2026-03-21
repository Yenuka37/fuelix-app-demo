import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../services/tutorial_service.dart';

// ─── Onboarding slide data ────────────────────────────────────────────────────
class _Slide {
  final String title;
  final String body;
  final IconData icon;
  final List<Color> gradient;
  final List<_Bullet> bullets;

  const _Slide({
    required this.title,
    required this.body,
    required this.icon,
    required this.gradient,
    this.bullets = const [],
  });
}

class _Bullet {
  final IconData icon;
  final String text;
  const _Bullet(this.icon, this.text);
}

const _slides = [
  _Slide(
    title: 'Welcome to Fuelix',
    body:
        'Your all-in-one smart fuel management companion. '
        'Track fuel, manage vehicles, and never run out of quota.',
    icon: Icons.local_gas_station_rounded,
    gradient: [Color(0xFF00C896), Color(0xFF0A84FF)],
    bullets: [
      _Bullet(Icons.directions_car_rounded, 'Manage multiple vehicles'),
      _Bullet(Icons.qr_code_rounded, 'Fuel Pass for each vehicle'),
      _Bullet(Icons.account_balance_wallet_rounded, 'Wallet & top-up credits'),
    ],
  ),
  _Slide(
    title: 'Add Your Vehicles',
    body:
        'Register your car, motorcycle, van, or any other vehicle '
        'to get started with fuel tracking.',
    icon: Icons.directions_car_rounded,
    gradient: [Color(0xFF0A84FF), Color(0xFF00C896)],
    bullets: [
      _Bullet(Icons.add_rounded, 'Tap "My Vehicles" → Add'),
      _Bullet(Icons.info_outline_rounded, 'Enter make, model, year & reg'),
      _Bullet(Icons.local_gas_station_rounded, 'Choose your fuel type'),
    ],
  ),
  _Slide(
    title: 'Get Your Fuel Pass',
    body:
        'Generate a unique QR Fuel Pass for each vehicle. '
        'Show it at any Fuelix-partnered station to refuel.',
    icon: Icons.qr_code_rounded,
    gradient: [Color(0xFF7C3AED), Color(0xFF0A84FF)],
    bullets: [
      _Bullet(Icons.lock_rounded, 'One QR per vehicle — permanent'),
      _Bullet(Icons.verified_rounded, 'Unique 8-character pass code'),
      _Bullet(Icons.block_rounded, 'Details locked after generation'),
    ],
  ),
  _Slide(
    title: 'Weekly Fuel Quota',
    body:
        'Each vehicle gets a weekly fuel allocation based on type. '
        'Quota resets every Monday.',
    icon: Icons.local_gas_station_rounded,
    gradient: [Color(0xFFFF9F0A), Color(0xFF00C896)],
    bullets: [
      _Bullet(Icons.directions_car_rounded, 'Car / Van — 25 L/week'),
      _Bullet(Icons.two_wheeler_rounded, 'Motorcycle — 2 L/week'),
      _Bullet(Icons.local_shipping_rounded, 'Truck 20 L · Bus 45 L · 3W 15 L'),
    ],
  ),
  _Slide(
    title: 'Top Up Your Wallet',
    body:
        'Add Fuelix Credits to your wallet via Card, Bank Transfer '
        'or Mobile Pay. Use credits to pay at partner stations.',
    icon: Icons.account_balance_wallet_rounded,
    gradient: [Color(0xFF7C3AED), Color(0xFFFF9F0A)],
    bullets: [
      _Bullet(Icons.credit_card_rounded, 'Credit / Debit Card'),
      _Bullet(Icons.account_balance_rounded, 'Bank Transfer'),
      _Bullet(Icons.phone_android_rounded, 'Mobile Pay'),
    ],
  ),
];

// ═════════════════════════════════════════════════════════════════════════════
// OnboardingScreen
// ═════════════════════════════════════════════════════════════════════════════
class OnboardingScreen extends StatefulWidget {
  final UserModel user;
  const OnboardingScreen({super.key, required this.user});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _current = 0;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_current < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  Future<void> _finish() async {
    await TutorialService.markSeen(TutorialKey.onboarding);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home', arguments: widget.user);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slide = _slides[_current];
    final isLast = _current == _slides.length - 1;

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
          child: Column(
            children: [
              // ── Skip ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Step badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                        '${_current + 1} / ${_slides.length}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSub
                              : AppColors.lightTextSub,
                        ),
                      ),
                    ),
                    // Skip button
                    if (!isLast)
                      GestureDetector(
                        onTap: _skip,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
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
                            'Skip',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSub
                                  : AppColors.lightTextSub,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Page content ──────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) {
                    setState(() => _current = i);
                    _slideCtrl.forward(from: 0);
                  },
                  itemCount: _slides.length,
                  itemBuilder: (_, i) => _SlidePage(
                    slide: _slides[i],
                    isDark: isDark,
                    slideAnim: i == _current ? _slideAnim : null,
                    fadeAnim: i == _current ? _fadeAnim : null,
                  ),
                ),
              ),

              // ── Dot indicators ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final active = i == _current;
                    final color = _slides[i].gradient.first;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: active
                            ? color
                            : color.withOpacity(isDark ? 0.25 : 0.2),
                      ),
                    );
                  }),
                ),
              ),

              // ── CTA buttons ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  children: [
                    // Primary CTA
                    GestureDetector(
                      onTap: _next,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: slide.gradient,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: slide.gradient.first.withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isLast ? 'Get Started' : 'Next',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isLast
                                    ? Icons.rocket_launch_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Back button (not on first slide)
                    if (_current > 0) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _pageCtrl.previousPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        ),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Back',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextSub
                                    : AppColors.lightTextSub,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Single slide page ────────────────────────────────────────────────────────
class _SlidePage extends StatelessWidget {
  final _Slide slide;
  final bool isDark;
  final Animation<Offset>? slideAnim;
  final Animation<double>? fadeAnim;

  const _SlidePage({
    required this.slide,
    required this.isDark,
    this.slideAnim,
    this.fadeAnim,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon hero
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: slide.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: slide.gradient.first.withOpacity(0.35),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Icon(slide.icon, size: 52, color: Colors.white),
          ),
          const SizedBox(height: 36),

          // Title
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: slide.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              slide.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Body
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.65,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
          const SizedBox(height: 32),

          // Bullet list
          if (slide.bullets.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: slide.bullets.asMap().entries.map((e) {
                  final isLast = e.key == slide.bullets.length - 1;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              gradient: LinearGradient(
                                colors: slide.gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              e.value.icon,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              e.value.text,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isLast) ...[
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );

    if (slideAnim != null && fadeAnim != null) {
      return FadeTransition(
        opacity: fadeAnim!,
        child: SlideTransition(position: slideAnim!, child: content),
      );
    }
    return content;
  }
}
