import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ─── Gradient Primary Button ─────────────────────────────────────────────────
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final List<Color>? colors;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.colors,
    this.height = 56,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.03,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? [AppColors.emerald, AppColors.ocean];
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedOpacity(
          opacity: widget.onPressed == null ? 0.6 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      widget.label,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Outlined Secondary Button ────────────────────────────────────────────────
class OutlinedAppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const OutlinedAppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: colorScheme.primary,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── App Text Field ───────────────────────────────────────────────────────────
class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final bool readOnly;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffixWidget,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.onChanged,
    this.readOnly = false,
    this.maxLines = 1,
    this.inputFormatters,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    // Multi-line fields should never be obscured
    final isMultiline = (widget.maxLines ?? 1) > 1;

    return TextFormField(
      controller: widget.controller,
      obscureText: (!isMultiline && widget.obscureText) ? _obscure : false,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      textCapitalization: widget.textCapitalization,
      focusNode: widget.focusNode,
      onChanged: widget.onChanged,
      readOnly: widget.readOnly,
      maxLines: widget.obscureText ? 1 : (widget.maxLines ?? 1),
      minLines: 1,
      inputFormatters: widget.inputFormatters,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        // Align prefix icon to top for multi-line fields
        prefixIconConstraints: isMultiline
            ? const BoxConstraints(minWidth: 48, minHeight: 48)
            : null,
        prefixIcon: widget.prefixIcon != null
            ? Padding(
                padding: isMultiline
                    ? const EdgeInsets.only(bottom: 0)
                    : EdgeInsets.zero,
                child: Align(
                  alignment: isMultiline
                      ? Alignment.topCenter
                      : Alignment.center,
                  widthFactor: 1,
                  heightFactor: isMultiline ? 1.6 : null,
                  child: Icon(widget.prefixIcon, size: 20),
                ),
              )
            : null,
        suffixIcon: (!isMultiline && widget.obscureText)
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : widget.suffixWidget,
      ),
    );
  }
}

// ─── Step Indicator ───────────────────────────────────────────────────────────
class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        final isDone = index < currentStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < totalSteps - 1 ? 6 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: isActive || isDone
                    ? LinearGradient(
                        colors: [AppColors.emerald, AppColors.ocean],
                      )
                    : null,
                color: isActive || isDone
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

// ─── Snackbar Helper ──────────────────────────────────────────────────────────
void showAppSnackbar(
  BuildContext context, {
  required String message,
  bool isError = false,
  bool isSuccess = false,
}) {
  final color = isError
      ? AppColors.error
      : isSuccess
      ? AppColors.emerald
      : AppColors.ocean;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline
                : isSuccess
                ? Icons.check_circle_outline
                : Icons.info_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ),
  );
}
