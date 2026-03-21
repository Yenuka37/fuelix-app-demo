import '../models/quota_model.dart';

/// Pure business-logic service — no DB dependency.
class QuotaService {
  QuotaService._();

  // ── Weekly quotas per vehicle type (litres) ───────────────────────────────
  static const Map<String, double> weeklyQuota = {
    'Car': 25.0,
    'Van': 25.0,
    'Motorcycle': 2.0,
    'Truck': 20.0,
    'Bus': 45.0,
    'Three-Wheeler': 15.0,
  };

  static double quotaFor(String vehicleType) => weeklyQuota[vehicleType] ?? 0.0;

  // ── Week boundary helpers (Mon–Sun) ───────────────────────────────────────
  static DateTime weekStart(DateTime date) {
    final d = date.toLocal();
    return DateTime(d.year, d.month, d.day - (d.weekday - 1));
  }

  static DateTime weekEnd(DateTime date) {
    final s = weekStart(date);
    return DateTime(s.year, s.month, s.day + 6, 23, 59, 59, 999);
  }

  static bool isCurrentWeek(FuelQuotaModel q, DateTime date) {
    final d = date.toLocal();
    return !d.isBefore(q.weekStart) && !d.isAfter(q.weekEnd);
  }

  // ── New week record (quota resets — balance does NOT carry over) ──────────
  static FuelQuotaModel newWeekQuota(int vehicleId, String vehicleType) {
    final now = DateTime.now();
    return FuelQuotaModel(
      vehicleId: vehicleId,
      weekStart: weekStart(now),
      weekEnd: weekEnd(now),
      quotaLitres: quotaFor(vehicleType),
      usedLitres: 0.0,
    );
  }

  // ── Display helpers ───────────────────────────────────────────────────────
  static String daysRemainingLabel(DateTime now) {
    final diff = weekEnd(now).difference(now.toLocal());
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    if (days > 0) return '$days day${days == 1 ? '' : 's'} left';
    if (hours > 0) return '$hours hr${hours == 1 ? '' : 's'} left';
    return 'Resets tonight';
  }

  static String weekLabel(DateTime weekStartDate) {
    const mo = [
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
    final s = weekStartDate;
    final e = s.add(const Duration(days: 6));
    return '${s.day} ${mo[s.month - 1]} – ${e.day} ${mo[e.month - 1]}';
  }
}
