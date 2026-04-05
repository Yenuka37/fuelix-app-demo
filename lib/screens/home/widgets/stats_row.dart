import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class StatsRow extends StatelessWidget {
  final Map<String, double> stats;
  final bool isDark;

  const StatsRow({super.key, required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final totalLogs = (stats['total_logs'] ?? 0).toInt();
    final totalLitres = stats['total_litres'] ?? 0.0;
    final totalSpent = stats['total_spent'] ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Logs',
            value: '$totalLogs',
            icon: Icons.list_alt_rounded,
            color: AppColors.emerald,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Fuel Used',
            value: '${totalLitres.toStringAsFixed(1)} L',
            icon: Icons.local_gas_station_rounded,
            color: AppColors.ocean,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Total Spent',
            value: 'Rs. ${totalSpent.toStringAsFixed(0)}',
            icon: Icons.payments_outlined,
            color: AppColors.amber,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
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
