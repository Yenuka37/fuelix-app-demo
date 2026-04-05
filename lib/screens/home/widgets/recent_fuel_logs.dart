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
  final VoidCallback onAddLog;

  const RecentFuelLogs({
    super.key,
    required this.recentLogs,
    required this.vehicles,
    required this.isDark,
    required this.onAddLog,
  });

  @override
  State<RecentFuelLogs> createState() => _RecentFuelLogsState();
}

class _RecentFuelLogsState extends State<RecentFuelLogs> {
  final ApiService _apiService = ApiService();

  Future<void> _deleteLog(FuelLogModel log) async {
    if (log.id == null) return;
    final result = await _apiService.deleteFuelLog(log.id!);
    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Log deleted'),
            backgroundColor: AppColors.emerald,
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
        Row(
          children: [
            Text(
              'Recent Fuel Logs',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            if (widget.recentLogs.isNotEmpty)
              GestureDetector(
                onTap: widget.onAddLog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.emerald.withOpacity(
                      widget.isDark ? 0.12 : 0.08,
                    ),
                    border: Border.all(
                      color: AppColors.emerald.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 13,
                        color: AppColors.emerald,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add Log',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.recentLogs.isEmpty)
          _EmptyActivity(isDark: widget.isDark, onTap: widget.onAddLog)
        else
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

  const _FuelLogTile({
    required this.log,
    required this.vehicle,
    required this.isDark,
    required this.onDelete,
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
        onLongPress: onDelete,
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
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _EmptyActivity({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: AppColors.emerald.withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emerald.withOpacity(isDark ? 0.12 : 0.08),
              ),
              child: const Icon(
                Icons.local_gas_station_rounded,
                size: 26,
                color: AppColors.emerald,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No fuel logs yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap here to log your first refuel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [AppColors.emerald, AppColors.ocean],
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'Add Fuel Log',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
