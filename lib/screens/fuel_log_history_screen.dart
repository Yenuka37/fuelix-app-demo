import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/fuel_log_model.dart';
import '../services/api_service.dart';
import '../widgets/custom_button.dart';

class FuelLogHistoryScreen extends StatefulWidget {
  final UserModel user;
  final List<VehicleModel> vehicles;

  const FuelLogHistoryScreen({
    super.key,
    required this.user,
    required this.vehicles,
  });

  @override
  State<FuelLogHistoryScreen> createState() => _FuelLogHistoryScreenState();
}

class _FuelLogHistoryScreenState extends State<FuelLogHistoryScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<FuelLogModel> _allLogs = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Grouped logs: Map<MonthYear, List<FuelLogModel>>
  Map<String, List<FuelLogModel>> _groupedLogs = {};
  List<String> _sortedMonths = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadFuelLogs();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadFuelLogs() async {
    setState(() => _isLoading = true);

    try {
      final result = await _apiService.getUserFuelLogs(widget.user.id!);

      if (result['success'] && mounted) {
        List<dynamic> logsJson = result['data'];
        List<FuelLogModel> logs = logsJson
            .map(
              (json) => FuelLogModel(
                id: json['id'],
                userId: json['userId'],
                vehicleId: json['vehicleId'],
                litres: (json['litres'] as num).toDouble(),
                fuelType: json['fuelType'],
                fuelGrade: json['fuelGrade'],
                pricePerLitre: (json['pricePerLitre'] as num).toDouble(),
                totalCost: (json['totalCost'] as num).toDouble(),
                stationName: json['stationName'] ?? '',
                loggedAt: DateTime.parse(json['loggedAt']),
              ),
            )
            .toList();

        // Sort by date (latest first)
        logs.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

        setState(() {
          _allLogs = logs;
          _groupLogsByMonth();
        });
      }
    } catch (e) {
      print('Error loading fuel logs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load fuel history'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _groupLogsByMonth() {
    final Map<String, List<FuelLogModel>> grouped = {};

    for (final log in _allLogs) {
      final monthYear = _getMonthYearKey(log.loggedAt);
      if (!grouped.containsKey(monthYear)) {
        grouped[monthYear] = [];
      }
      grouped[monthYear]!.add(log);
    }

    // Sort months in descending order (latest first)
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    setState(() {
      _groupedLogs = grouped;
      _sortedMonths = sortedKeys;
    });
  }

  String _getMonthYearKey(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getMonthShort(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[date.month - 1];
  }

  Future<void> _deleteLog(FuelLogModel log) async {
    if (log.id == null) return;

    setState(() => _isDeleting = true);

    final result = await _apiService.deleteFuelLog(log.id!);

    if (result['success'] && mounted) {
      // Remove from local list
      setState(() {
        _allLogs.removeWhere((l) => l.id == log.id);
        _groupLogsByMonth();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log deleted successfully'),
          backgroundColor: AppColors.emerald,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to delete log'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    setState(() => _isDeleting = false);
  }

  void _showDeleteConfirm(FuelLogModel log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

  String _getVehicleName(int vehicleId) {
    final vehicle = widget.vehicles.firstWhere(
      (v) => v.id == vehicleId,
      orElse: () => VehicleModel(
        userId: widget.user.id!,
        type: 'Car',
        make: 'Unknown',
        model: '',
        year: '',
        registrationNo: '',
        fuelType: '',
      ),
    );
    return vehicle.registrationNo.isNotEmpty
        ? vehicle.registrationNo.toUpperCase()
        : vehicle.shortDisplay;
  }

  Color _getGradeColor(String grade) {
    if (grade.contains('95')) return const Color(0xFF7C3AED);
    if (grade.contains('92')) return AppColors.ocean;
    if (grade.contains('Super')) return AppColors.amber;
    if (grade.contains('Auto')) return const Color(0xFFF97316);
    if (grade.contains('Kerosene')) return const Color(0xFF6B7280);
    return AppColors.emerald;
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
                // App Bar
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
                          'Fuel Log History',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      GestureDetector(
                        onTap: _loadFuelLogs,
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
                            Icons.refresh_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.darkTextSub
                                : AppColors.lightTextSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  height: 1,
                ),
                // Body
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.emerald,
                          ),
                        )
                      : _allLogs.isEmpty
                      ? _buildEmptyState(isDark)
                      : RefreshIndicator(
                          onRefresh: _loadFuelLogs,
                          color: AppColors.emerald,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                            itemCount: _sortedMonths.length,
                            itemBuilder: (context, index) {
                              final monthKey = _sortedMonths[index];
                              final logs = _groupedLogs[monthKey] ?? [];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Month Header
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                            gradient: const LinearGradient(
                                              colors: [
                                                AppColors.emerald,
                                                AppColors.ocean,
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          monthKey,
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppColors.darkText
                                                : AppColors.lightText,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            color: AppColors.emerald
                                                .withOpacity(0.15),
                                          ),
                                          child: Text(
                                            '${logs.length}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.emerald,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Logs for this month
                                  ...logs.map(
                                    (log) => _buildLogTile(log, isDark),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogTile(FuelLogModel log, bool isDark) {
    final accent = _getGradeColor(log.fuelGrade);
    final vehicleName = _getVehicleName(log.vehicleId);
    final day = log.loggedAt.day;
    final weekday = _getWeekdayShort(log.loggedAt.weekday);

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
        onLongPress: _isDeleting ? null : () => _showDeleteConfirm(log),
        child: Opacity(
          opacity: _isDeleting ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Date Badge
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withOpacity(0.15),
                        accent.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(color: accent.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day.toString(),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                      Text(
                        weekday,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Log Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vehicleName,
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
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
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
                          if (log.stationName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: isDark
                                    ? AppColors.darkSurfaceAlt
                                    : AppColors.lightSurfaceAlt,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 10,
                                    color: isDark
                                        ? AppColors.darkTextSub
                                        : AppColors.lightTextSub,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    log.stationName.length > 20
                                        ? '${log.stationName.substring(0, 20)}...'
                                        : log.stationName,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: isDark
                                          ? AppColors.darkTextSub
                                          : AppColors.lightTextSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            log.formattedTime,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.currency_rupee_rounded,
                            size: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            log.totalCost.toStringAsFixed(2),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSub
                                  : AppColors.lightTextSub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete indicator (on long press)
                if (_isDeleting)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getWeekdayShort(int weekday) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return weekdays[weekday - 1];
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.emerald.withOpacity(0.15),
                  AppColors.ocean.withOpacity(0.15),
                ],
              ),
            ),
            child: Icon(
              Icons.history_rounded,
              size: 38,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Fuel Logs Found',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your fuel refill history will appear here',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
        ],
      ),
    );
  }
}
