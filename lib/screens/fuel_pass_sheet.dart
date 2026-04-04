import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../models/vehicle_model.dart';
import '../models/quota_model.dart';
import '../database/db_helper.dart';
import '../services/quota_service.dart';

class FuelPassSheet extends StatefulWidget {
  final VehicleModel vehicle;
  final DbHelper db;

  const FuelPassSheet({super.key, required this.vehicle, required this.db});

  @override
  State<FuelPassSheet> createState() => _FuelPassSheetState();
}

class _FuelPassSheetState extends State<FuelPassSheet> {
  FuelQuotaModel? _quota;
  bool _loading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    if (widget.vehicle.id == null) {
      setState(() => _loading = false);
      return;
    }
    final q = await widget.db.getCurrentWeekQuota(
      widget.vehicle.id!,
      widget.vehicle.type,
    );
    if (mounted) {
      setState(() {
        _quota = q;
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime d) {
    const m = [
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
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  Color vehicleTypeColor(String type) {
    switch (type) {
      case 'Car':
        return AppColors.ocean;
      case 'Motorcycle':
        return AppColors.amber;
      case 'Van':
        return AppColors.emerald;
      case 'Truck':
        return const Color(0xFFEF4444);
      case 'Bus':
        return const Color(0xFF7C3AED);
      case 'Three-Wheeler':
        return const Color(0xFFF97316);
      default:
        return AppColors.emerald;
    }
  }

  IconData vehicleTypeIcon(String type) {
    switch (type) {
      case 'Car':
        return Icons.directions_car_rounded;
      case 'Motorcycle':
        return Icons.two_wheeler_rounded;
      case 'Van':
        return Icons.airport_shuttle_rounded;
      case 'Truck':
        return Icons.local_shipping_rounded;
      case 'Bus':
        return Icons.directions_bus_rounded;
      case 'Three-Wheeler':
        return Icons.electric_rickshaw_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = vehicleTypeColor(widget.vehicle.type);
    final code = widget.vehicle.fuelPassCode ?? '';
    final qrData =
        'FUELIX|${widget.vehicle.fuelPassCode}|${widget.vehicle.registrationNo}|'
        '${widget.vehicle.make} ${widget.vehicle.model}|${widget.vehicle.year}|${widget.vehicle.fuelType}';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            const SizedBox(height: 20),

            // Fuel Pass Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      accent,
                      accent.withOpacity(0.75),
                      AppColors.ocean.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withOpacity(0.2),
                            ),
                            child: Icon(
                              vehicleTypeIcon(widget.vehicle.type),
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FUEL PASS',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.75),
                                    letterSpacing: 2,
                                  ),
                                ),
                                Text(
                                  widget.vehicle.displayName,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white.withOpacity(0.15),
                            ),
                            child: Text(
                              'FUELIX',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // QR Code
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 22),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 175,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF111827),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFF3F4F6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  code.length >= 8
                                      ? '${code.substring(0, 4)} ${code.substring(4)}'
                                      : code,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF111827),
                                    letterSpacing: 4,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: code),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Code copied!'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: const Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Vehicle Details
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PassDetail(
                              label: 'REG NO',
                              value: widget.vehicle.registrationNo,
                            ),
                          ),
                          Expanded(
                            child: _PassDetail(
                              label: 'FUEL TYPE',
                              value: widget.vehicle.fuelType,
                            ),
                          ),
                          Expanded(
                            child: _PassDetail(
                              label: 'ISSUED',
                              value: widget.vehicle.qrGeneratedAt != null
                                  ? _formatDate(widget.vehicle.qrGeneratedAt!)
                                  : '—',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Quota Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: AppColors.emerald,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : _quota != null
                  ? _QuotaCard(
                      quota: _quota!,
                      vehicleType: widget.vehicle.type,
                      isDark: isDark,
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Notice 1
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _Notice(
                icon: Icons.info_outline_rounded,
                color: AppColors.ocean,
                isDark: isDark,
                text:
                    'Show this QR code at fuel stations to authorise refuelling. This pass is unique to this vehicle and cannot be transferred.',
              ),
            ),

            const SizedBox(height: 12),

            // Notice 2
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: _Notice(
                icon: Icons.lock_rounded,
                color: AppColors.amber,
                isDark: isDark,
                text:
                    'Vehicle details are locked. The Fuel Pass code cannot be regenerated.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassDetail extends StatelessWidget {
  final String label, value;
  const _PassDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.65),
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ],
  );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final String text;
  const _Notice({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: color.withOpacity(isDark ? 0.08 : 0.05),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 12, color: color, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class _QuotaCard extends StatefulWidget {
  final FuelQuotaModel quota;
  final String vehicleType;
  final bool isDark;

  const _QuotaCard({
    required this.quota,
    required this.vehicleType,
    required this.isDark,
  });

  @override
  State<_QuotaCard> createState() => _QuotaCardState();
}

class _QuotaCardState extends State<_QuotaCard> {
  late FuelQuotaModel _quota;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _quota = widget.quota;
    _checkForQuotaUpdate();
  }

  @override
  void didUpdateWidget(covariant _QuotaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quota.quotaLitres != widget.quota.quotaLitres) {
      setState(() {
        _quota = widget.quota;
      });
    }
  }

  Future<void> _checkForQuotaUpdate() async {
    final currentLimit = await QuotaService.getQuotaForVehicleType(
      widget.vehicleType,
    );
    if (_quota.quotaLitres != currentLimit && mounted) {
      setState(() {
        _quota = _quota.copyWith(quotaLitres: currentLimit);
        _isUpdating = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isUpdating = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _quota.remainingLitres;
    final used = _quota.usedLitres;
    final total = _quota.quotaLitres;
    final pct = _quota.usedPercent;
    final exhausted = _quota.isExhausted;

    Color gaugeColor;
    if (pct < 0.5) {
      gaugeColor = AppColors.emerald;
    } else if (pct < 0.85) {
      gaugeColor = AppColors.amber;
    } else {
      gaugeColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: widget.isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: exhausted
              ? AppColors.error.withOpacity(0.4)
              : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: exhausted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: exhausted
                        ? [AppColors.error, AppColors.error.withOpacity(0.7)]
                        : [AppColors.emerald, AppColors.ocean],
                  ),
                ),
                child: Icon(
                  exhausted
                      ? Icons.no_meals_rounded
                      : Icons.local_gas_station_rounded,
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Fuel Quota',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: widget.isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    Text(
                      QuotaService.weekLabel(_quota.weekStart),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: widget.isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isUpdating)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.emerald.withOpacity(0.15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.emerald,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Updating...',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: (exhausted ? AppColors.error : AppColors.emerald)
                        .withOpacity(widget.isDark ? 0.15 : 0.10),
                    border: Border.all(
                      color: (exhausted ? AppColors.error : AppColors.emerald)
                          .withOpacity(0.35),
                    ),
                  ),
                  child: Text(
                    exhausted
                        ? 'Exhausted'
                        : QuotaService.daysRemainingLabel(DateTime.now()),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: exhausted ? AppColors.error : AppColors.emerald,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              _QuotaStat(
                label: 'Remaining',
                value: '${remaining.toStringAsFixed(1)} L',
                color: exhausted ? AppColors.error : AppColors.emerald,
                isDark: widget.isDark,
                large: true,
              ),
              _vDivider(widget.isDark),
              _QuotaStat(
                label: 'Used',
                value: '${used.toStringAsFixed(1)} L',
                color: AppColors.amber,
                isDark: widget.isDark,
              ),
              _vDivider(widget.isDark),
              _QuotaStat(
                label: 'Weekly Total',
                value: '${total.toStringAsFixed(0)} L',
                color: AppColors.ocean,
                isDark: widget.isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 10,
                        backgroundColor: widget.isDark
                            ? AppColors.darkSurfaceAlt
                            : AppColors.lightSurfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}% used',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: widget.isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                        Text(
                          'Resets next Monday',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: widget.isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (exhausted) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.error.withOpacity(widget.isDark ? 0.12 : 0.07),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 15,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your weekly quota is exhausted. Balance resets every Monday.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.error,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vDivider(bool isDark) => Container(
    width: 1,
    height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
  );
}

class _QuotaStat extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark, large;
  const _QuotaStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: large ? 22 : 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    ),
  );
}
