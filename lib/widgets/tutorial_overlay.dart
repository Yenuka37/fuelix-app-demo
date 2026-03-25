import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ─── Step data ────────────────────────────────────────────────────────────────
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

enum TooltipPosition { above, below }

// ═════════════════════════════════════════════════════════════════════════════
// SpotlightTour
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
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(
      begin: 0.92,
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
    final sz = box.size;
    if (mounted) {
      setState(() {
        _targetRect = Rect.fromLTWH(pos.dx, pos.dy, sz.width, sz.height);
        _visible = true;
      });
      _animCtrl.forward(from: 0);
    }
  }

  Future<void> _advance() async {
    await _animCtrl.reverse();
    if (!mounted) return;
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
    if (mounted) setState(() => _visible = false);
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

// ═════════════════════════════════════════════════════════════════════════════
// Overlay — dim + spotlight cutout + positioned tooltip
// ═════════════════════════════════════════════════════════════════════════════
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
    final screenSize = MediaQuery.of(context).size;
    final isLast = stepIndex == totalSteps - 1;

    // ── Decide whether card goes above or below target ────────────────────
    const hPad = 20.0; // horizontal screen padding
    const arrowH = 12.0; // arrow triangle height
    const vGap = 8.0; // gap between arrow and target

    // Space available above / below
    final spaceBelow = screenSize.height - targetRect.bottom - arrowH - vGap;
    final spaceAbove = targetRect.top - arrowH - vGap;

    // Place below unless position==above AND there's enough room above
    final bool placeBelow =
        (step.position == TooltipPosition.above && spaceAbove > 160)
        ? false
        : true;

    // Arrow tip X = center of target, clamped to card interior
    final cardLeft = hPad;
    final cardRight = screenSize.width - hPad;
    final arrowTipX = targetRect.center.dx.clamp(cardLeft + 24, cardRight - 24);

    return FadeTransition(
      opacity: fadeAnim,
      child: Stack(
        children: [
          // ── Full-screen dim with spotlight hole ────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _SpotlightPainter(
                spotlight: targetRect.inflate(6),
                dimColor: Colors.black.withOpacity(0.70),
              ),
            ),
          ),

          // ── Pulse ring around target ───────────────────────────────────
          Positioned(
            left: targetRect.left - 8,
            top: targetRect.top - 8,
            width: targetRect.width + 16,
            height: targetRect.height + 16,
            child: _PulseRing(color: step.gradient.first),
          ),

          // ── Tooltip card + arrow ───────────────────────────────────────
          Positioned(
            left: hPad,
            right: hPad,
            top: placeBelow ? targetRect.bottom + arrowH + vGap : null,
            bottom: placeBelow
                ? null
                : screenSize.height - targetRect.top + arrowH + vGap,
            child: ScaleTransition(
              scale: scaleAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Arrow pointing UP (card is below target)
                  if (placeBelow)
                    _Arrow(
                      up: true,
                      tipX: arrowTipX - hPad,
                      color: step.gradient.first,
                    ),

                  // Card
                  _TooltipCard(
                    step: step,
                    stepIndex: stepIndex,
                    totalSteps: totalSteps,
                    isDark: isDark,
                    isLast: isLast,
                    onNext: onNext,
                    onSkip: onSkip,
                  ),

                  // Arrow pointing DOWN (card is above target)
                  if (!placeBelow)
                    _Arrow(
                      up: false,
                      tipX: arrowTipX - hPad,
                      color: step.gradient.first,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tooltip card
// ═════════════════════════════════════════════════════════════════════════════
class _TooltipCard extends StatelessWidget {
  final TourStep step;
  final int stepIndex, totalSteps;
  final bool isDark, isLast;
  final VoidCallback onNext, onSkip;

  const _TooltipCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.isDark,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C2333) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: bg,
          border: Border.all(
            color: step.gradient.first.withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.18),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: step.gradient.first.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
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
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: step.gradient.first.withOpacity(0.13),
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

            // ── Body text ─────────────────────────────────────────────────
            Text(
              step.body,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.55,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
            const SizedBox(height: 16),

            // ── Dots + buttons ────────────────────────────────────────────
            Row(
              children: [
                // Progress dots
                ...List.generate(
                  totalSteps,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 5),
                    width: i == stepIndex ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == stepIndex
                          ? step.gradient.first
                          : step.gradient.first.withOpacity(0.22),
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
                        horizontal: 10,
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
                const SizedBox(width: 6),
                // Next / Done
                GestureDetector(
                  onTap: onNext,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
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
                          blurRadius: 8,
                          offset: const Offset(0, 3),
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
                        const SizedBox(width: 5),
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
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Arrow — tip aligned to target center
// ═════════════════════════════════════════════════════════════════════════════
class _Arrow extends StatelessWidget {
  /// [up] = true  → triangle points UP   (card is below target)
  /// [up] = false → triangle points DOWN (card is above target)
  final bool up;

  /// X offset of the arrow tip from the LEFT edge of the card.
  final double tipX;
  final Color color;

  const _Arrow({required this.up, required this.tipX, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 12,
      child: CustomPaint(
        painter: _ArrowPainter(up: up, tipX: tipX, color: color),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final bool up;
  final double tipX;
  final Color color;

  _ArrowPainter({required this.up, required this.tipX, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const hw = 14.0; // half-width of arrow base
    final cx = tipX.clamp(hw + 2, size.width - hw - 2);

    final path = Path();
    if (up) {
      // Tip points up
      path.moveTo(cx, 0);
      path.lineTo(cx - hw, size.height);
      path.lineTo(cx + hw, size.height);
    } else {
      // Tip points down
      path.moveTo(cx, size.height);
      path.lineTo(cx - hw, 0);
      path.lineTo(cx + hw, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) =>
      old.tipX != tipX || old.up != up;
}

// ═════════════════════════════════════════════════════════════════════════════
// Pulsing ring
// ═════════════════════════════════════════════════════════════════════════════
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
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.14,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween<double>(
      begin: 0.55,
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
            width: 2.5,
          ),
        ),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Spotlight painter
// ═════════════════════════════════════════════════════════════════════════════
class _SpotlightPainter extends CustomPainter {
  final Rect spotlight;
  final Color dimColor;

  _SpotlightPainter({required this.spotlight, required this.dimColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());

    // Dim layer
    canvas.drawRect(Offset.zero & size, Paint()..color = dimColor);

    // Cut out spotlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlight, const Radius.circular(14)),
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.spotlight != spotlight;
}
