import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ─── A single step in a spotlight tour ───────────────────────────────────────
class TourStep {
  final GlobalKey targetKey;
  final String title;
  final String body;
  final IconData icon;
  final List<Color> gradient;
  final TooltipPosition position;

  const TourStep({
    required this.targetKey,
    required this.title,
    required this.body,
    required this.icon,
    this.gradient = const [AppColors.emerald, AppColors.ocean],
    this.position = TooltipPosition.below,
  });
}

enum TooltipPosition { above, below, left, right }

// ═════════════════════════════════════════════════════════════════════════════
// SpotlightTour — wraps a screen, drives through steps one-by-one
// ═════════════════════════════════════════════════════════════════════════════
class SpotlightTour extends StatefulWidget {
  final List<TourStep> steps;
  final Widget child;
  final VoidCallback onComplete;

  const SpotlightTour({
    super.key,
    required this.steps,
    required this.child,
    required this.onComplete,
  });

  @override
  State<SpotlightTour> createState() => _SpotlightTourState();
}

class _SpotlightTourState extends State<SpotlightTour>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  Rect? _targetRect;
  bool _visible = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _measure() {
    if (_step >= widget.steps.length) return;
    final ctx = widget.steps[_step].targetKey.currentContext;
    if (ctx == null) {
      _advance();
      return;
    }
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) {
      _advance();
      return;
    }
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    setState(() {
      _targetRect = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);
      _visible = true;
    });
    _animCtrl.forward(from: 0);
  }

  Future<void> _advance() async {
    await _animCtrl.reverse();
    if (_step < widget.steps.length - 1) {
      setState(() {
        _step++;
        _targetRect = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    } else {
      setState(() => _visible = false);
      widget.onComplete();
    }
  }

  void _skip() {
    setState(() => _visible = false);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible && _targetRect != null)
          _SpotlightOverlay(
            step: widget.steps[_step],
            stepIndex: _step,
            totalSteps: widget.steps.length,
            targetRect: _targetRect!,
            fadeAnim: _fadeAnim,
            scaleAnim: _scaleAnim,
            onNext: _advance,
            onSkip: _skip,
          ),
      ],
    );
  }
}

// ─── The actual overlay ───────────────────────────────────────────────────────
class _SpotlightOverlay extends StatelessWidget {
  final TourStep step;
  final int stepIndex, totalSteps;
  final Rect targetRect;
  final Animation<double> fadeAnim, scaleAnim;
  final VoidCallback onNext, onSkip;

  const _SpotlightOverlay({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.targetRect,
    required this.fadeAnim,
    required this.scaleAnim,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isLast = stepIndex == totalSteps - 1;

    // Determine tooltip Y position
    const padding = 16.0;
    const cardH = 210.0;
    const arrowH = 14.0;
    double cardTop;
    bool arrowUp; // true = arrow points up (tooltip is below target)

    if (step.position == TooltipPosition.above ||
        targetRect.top - cardH - arrowH - padding < 0) {
      // Below target
      cardTop = targetRect.bottom + arrowH + padding;
      arrowUp = true;
    } else {
      // Above target
      cardTop = targetRect.top - cardH - arrowH - padding;
      arrowUp = false;
    }

    // Clamp to screen
    cardTop = cardTop.clamp(padding, size.height - cardH - padding);

    return FadeTransition(
      opacity: fadeAnim,
      child: Stack(
        children: [
          // Dim overlay with spotlight cutout
          CustomPaint(
            size: size,
            painter: _SpotlightPainter(
              spotlight: targetRect.inflate(8),
              color: Colors.black.withOpacity(0.72),
            ),
          ),

          // Tooltip card
          Positioned(
            top: cardTop,
            left: padding,
            right: padding,
            child: ScaleTransition(
              scale: scaleAnim,
              child: _TooltipCard(
                step: step,
                stepIndex: stepIndex,
                totalSteps: totalSteps,
                arrowUp: arrowUp,
                targetRect: targetRect,
                isDark: isDark,
                isLast: isLast,
                onNext: onNext,
                onSkip: onSkip,
              ),
            ),
          ),

          // Pulsing ring around target
          Positioned(
            left: targetRect.left - 8,
            top: targetRect.top - 8,
            width: targetRect.width + 16,
            height: targetRect.height + 16,
            child: _PulseRing(color: step.gradient.first),
          ),
        ],
      ),
    );
  }
}

// ─── Tooltip card ─────────────────────────────────────────────────────────────
class _TooltipCard extends StatelessWidget {
  final TourStep step;
  final int stepIndex, totalSteps;
  final bool arrowUp, isDark, isLast;
  final Rect targetRect;
  final VoidCallback onNext, onSkip;

  const _TooltipCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.arrowUp,
    required this.targetRect,
    required this.isDark,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C2333) : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!arrowUp) _Arrow(up: false, color: step.gradient.first),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: bg,
            boxShadow: [
              BoxShadow(
                color: step.gradient.first.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: step.gradient.first.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: LinearGradient(
                        colors: step.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(step.icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                  ),
                  // Step counter
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: step.gradient.first.withOpacity(0.12),
                    ),
                    child: Text(
                      '${stepIndex + 1}/$totalSteps',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: step.gradient.first,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                step.body,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.55,
                  color: isDark
                      ? AppColors.darkTextSub
                      : AppColors.lightTextSub,
                ),
              ),
              const SizedBox(height: 16),
              // Dots + buttons row
              Row(
                children: [
                  // Progress dots
                  Row(
                    children: List.generate(
                      totalSteps,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 5),
                        width: i == stepIndex ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i == stepIndex
                              ? step.gradient.first
                              : step.gradient.first.withOpacity(0.25),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Skip
                  if (!isLast)
                    GestureDetector(
                      onTap: onSkip,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Next / Done
                  GestureDetector(
                    onTap: onNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: step.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: step.gradient.first.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLast ? 'Done' : 'Next',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isLast
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (arrowUp) _Arrow(up: true, color: step.gradient.first),
      ],
    );
  }
}

// ─── Arrow pointer ────────────────────────────────────────────────────────────
class _Arrow extends StatelessWidget {
  final bool up;
  final Color color;
  const _Arrow({required this.up, required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(24, 14),
    painter: _ArrowPainter(up: up, color: color),
  );
}

class _ArrowPainter extends CustomPainter {
  final bool up;
  final Color color;
  _ArrowPainter({required this.up, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (up) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Pulsing ring around spotlight target ─────────────────────────────────────
class _PulseRing extends StatefulWidget {
  final Color color;
  const _PulseRing({required this.color});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _scale = Tween<double>(
      begin: 0.9,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Transform.scale(
      scale: _scale.value,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.color.withOpacity(_opacity.value),
            width: 3,
          ),
        ),
      ),
    ),
  );
}

// ─── Spotlight CustomPainter ──────────────────────────────────────────────────
class _SpotlightPainter extends CustomPainter {
  final Rect spotlight;
  final Color color;
  _SpotlightPainter({required this.spotlight, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final full = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(spotlight, const Radius.circular(14));

    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, paint);
    canvas.drawRRect(rrect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.spotlight != spotlight;
}
