import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class QuickActions extends StatelessWidget {
  final bool isDark;
  final VoidCallback onLogHistory;
  final VoidCallback onAnalytics;
  final VoidCallback onFuelStations;
  final VoidCallback onTopUp;
  final Key? logHistoryKey;

  const QuickActions({
    super.key,
    required this.isDark,
    required this.onLogHistory,
    required this.onAnalytics,
    required this.onFuelStations,
    required this.onTopUp,
    this.logHistoryKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.history_rounded,
                label: 'Log History',
                sublabel: 'View fuel records',
                gradient: [AppColors.emerald, AppColors.emeraldDark],
                isDark: isDark,
                onTap: onLogHistory,
                key: logHistoryKey,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _ActionCard(
                icon: Icons.bar_chart_rounded,
                label: 'Analytics',
                sublabel: 'View reports',
                gradient: [AppColors.ocean, AppColors.oceanDark],
                isDark: isDark,
                onTap: onAnalytics,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.local_gas_station_outlined,
                label: 'Fuel Stations',
                sublabel: 'Find nearby',
                gradient: [AppColors.amber, AppColors.amberDark],
                isDark: isDark,
                onTap: onFuelStations,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _ActionCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Top Up',
                sublabel: 'Add fuel credits',
                gradient: [const Color(0xFF7C3AED), const Color(0xFF0A84FF)],
                isDark: isDark,
                onTap: onTopUp,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String label, sublabel;
  final List<Color> gradient;
  final bool isDark;
  final VoidCallback onTap;
  final Color? labelColor, sublabelColor, iconColor;
  final Key? customKey;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.isDark,
    required this.onTap,
    this.labelColor,
    this.sublabelColor,
    this.iconColor,
    this.customKey,
    super.key,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isColored = widget.labelColor == null;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isColored
                ? LinearGradient(
                    colors: widget.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isColored
                ? null
                : (widget.isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface),
            border: !isColored
                ? Border.all(
                    color: widget.isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  )
                : null,
            boxShadow: isColored
                ? [
                    BoxShadow(
                      color: widget.gradient.first.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isColored
                      ? Colors.white.withOpacity(0.2)
                      : widget.gradient.first.withOpacity(0.12),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color:
                      widget.iconColor ??
                      (isColored ? Colors.white : widget.gradient.first),
                ),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: widget.labelColor ?? Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.sublabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color:
                          widget.sublabelColor ??
                          Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
