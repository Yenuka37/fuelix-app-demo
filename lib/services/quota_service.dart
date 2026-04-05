import '../models/quota_model.dart';
import 'api_service.dart';

class QuotaService {
  QuotaService._();

  static final ApiService _apiService = ApiService();
  static Map<String, double> _cachedQuotaLimits = {};

  static Future<double> getQuotaForVehicleType(String vehicleType) async {
    if (_cachedQuotaLimits.containsKey(vehicleType)) {
      return _cachedQuotaLimits[vehicleType]!;
    }

    try {
      final result = await _apiService.getQuotaLimitByVehicleType(vehicleType);
      if (result['success']) {
        final quota = (result['data']['quotaLitres'] as num).toDouble();
        _cachedQuotaLimits[vehicleType] = quota;
        return quota;
      }
    } catch (e) {
      print('Error fetching quota from API: $e');
    }

    // No fallback mock data - throw error if API fails
    throw Exception(
      'Failed to load quota from server. Please check your connection.',
    );
  }

  static void updateCachedQuota(String vehicleType, double newQuota) {
    _cachedQuotaLimits[vehicleType] = newQuota;
    print('📊 Quota cache updated: $vehicleType -> $newQuota L');
  }

  static void clearCache() {
    _cachedQuotaLimits.clear();
  }

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

  static Future<FuelQuotaModel> newWeekQuota(
    int vehicleId,
    String vehicleType,
  ) async {
    final now = DateTime.now();
    final quotaLitres = await getQuotaForVehicleType(vehicleType);
    return FuelQuotaModel(
      vehicleId: vehicleId,
      weekStart: weekStart(now),
      weekEnd: weekEnd(now),
      quotaLitres: quotaLitres,
      usedLitres: 0.0,
    );
  }

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
