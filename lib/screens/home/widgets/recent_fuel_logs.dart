import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/fuel_log_model.dart';
import '../../../services/api_service.dart';

class RecentFuelLogs extends StatefulWidget {
  final List<FuelLogModel> recentLogs;
  final List<VehicleModel> vehicles;
  final bool isDark;
  final VoidCallback onRefresh;

  const RecentFuelLogs({
    super.key,
    required this.recentLogs,
    required this.vehicles,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  State<RecentFuelLogs> createState() => _RecentFuelLogsState();
}

class _RecentFuelLogsState extends State<RecentFuelLogs> {
  final ApiService _apiService = ApiService();
  bool _isDeleting = false;

  Future<void> _deleteLog(FuelLogModel log) async {
    if (log.id == null) return;

    setState(() => _isDeleting = true);

    final result = await _apiService.deleteFuelLog(log.id!);

    if (result['success']) {
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Log deleted'),
            backgroundColor: AppColors.emerald,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    setState(() => _isDeleting = false);
  }

  void _showDeleteConfirm(FuelLogModel log) {
    final isDark = widget.isDark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        title: Text(
          'Delete Log',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Text(
          'Remove this fuel log entry?',
          style: Theme.of(context).textTheme.bodyMedium,
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
              _deleteLog(log);
            },
            child: Text(
              'Delete',
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Fuel Logs',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Column(
          children: widget.recentLogs.take(5).map((log) {
            final vehicle = widget.vehicles.firstWhere(
              (v) => v.id == log.vehicleId,
              orElse: () => VehicleModel(
                userId: log.userId,
                type: 'Car',
                make: 'Unknown',
                model: '',
                year: '',
                registrationNo: '',
                fuelType: log.fuelType,
              ),
            );
            return _FuelLogTile(
              log: log,
              vehicle: vehicle,
              isDark: widget.isDark,
              onDelete: () => _showDeleteConfirm(log),
              isDeleting: _isDeleting,
            );
          }).toList(),
        ),
      ],
    );
  }
}

Color _gradeColor(String grade) {
  if (grade.contains('95')) return const Color(0xFF7C3AED);
  if (grade.contains('92')) return AppColors.ocean;
  if (grade.contains('Super')) return AppColors.amber;
  if (grade.contains('Auto')) return const Color(0xFFF97316);
  if (grade.contains('Kerosene')) return const Color(0xFF6B7280);
  return AppColors.emerald;
}

class _FuelLogTile extends StatelessWidget {
  final FuelLogModel log;
  final VehicleModel vehicle;
  final bool isDark;
  final VoidCallback onDelete;
  final bool isDeleting;

  const _FuelLogTile({
    required this.log,
    required this.vehicle,
    required this.isDark,
    required this.onDelete,
    this.isDeleting = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _gradeColor(log.fuelGrade);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: isDeleting ? null : onDelete,
        child: Opacity(
          opacity: isDeleting ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: accent.withOpacity(isDark ? 0.14 : 0.10),
                  ),
                  child: Icon(
                    Icons.local_gas_station_rounded,
                    size: 22,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vehicle.shortDisplay,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${log.litres.toStringAsFixed(1)} L',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: accent.withOpacity(isDark ? 0.15 : 0.10),
                            ),
                            child: Text(
                              log.fuelGrade,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              log.stationName.isNotEmpty
                                  ? log.stationName
                                  : 'Unknown station',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSub
                                    : AppColors.lightTextSub,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            log.totalCost > 0
                                ? 'Rs. ${log.totalCost.toStringAsFixed(0)}'
                                : '',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${log.formattedDate} · ${log.formattedTime}',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
