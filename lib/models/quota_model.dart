/// Represents one weekly fuel quota record for a vehicle.
class FuelQuotaModel {
  final int? id;
  final int vehicleId;
  final DateTime weekStart; // always Monday 00:00:00 local
  final DateTime weekEnd; // always Sunday 23:59:59 local
  final double quotaLitres; // allocated quota for this week
  final double usedLitres; // fuel drawn so far this week

  FuelQuotaModel({
    this.id,
    required this.vehicleId,
    required this.weekStart,
    required this.weekEnd,
    required this.quotaLitres,
    this.usedLitres = 0.0,
  });

  double get remainingLitres =>
      (quotaLitres - usedLitres).clamp(0.0, quotaLitres);

  double get usedPercent =>
      quotaLitres > 0 ? (usedLitres / quotaLitres).clamp(0.0, 1.0) : 0.0;

  bool get isExhausted => remainingLitres <= 0;

  Map<String, dynamic> toMap() => {
    'id': id,
    'vehicleId': vehicleId,
    'weekStart': weekStart.toIso8601String(),
    'weekEnd': weekEnd.toIso8601String(),
    'quotaLitres': quotaLitres,
    'usedLitres': usedLitres,
  };

  factory FuelQuotaModel.fromMap(Map<String, dynamic> m) {
    // Safe integer parsing
    int getInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      if (value is double) return value.toInt();
      if (value is num) return value.toInt();
      return defaultValue;
    }

    // Safe double parsing
    double getDouble(dynamic value, {double defaultValue = 0.0}) {
      if (value == null) return defaultValue;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      if (value is num) return value.toDouble();
      return defaultValue;
    }

    // Safe DateTime parsing
    DateTime getDateTime(dynamic value, {DateTime? defaultValue}) {
      if (value == null) {
        return defaultValue ?? DateTime.now();
      }
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return defaultValue ?? DateTime.now();
        }
      }
      return defaultValue ?? DateTime.now();
    }

    // Try to get values with both snake_case and camelCase keys
    final id = m['id'] ?? m['ID'];
    final vehicleId = m['vehicleId'] ?? m['vehicle_id'] ?? m['vehicleid'];
    final weekStart = m['weekStart'] ?? m['week_start'];
    final weekEnd = m['weekEnd'] ?? m['week_end'];
    final quotaLitres =
        m['quotaLitres'] ?? m['quota_litres'] ?? m['quotaLitres'];
    final usedLitres = m['usedLitres'] ?? m['used_litres'] ?? 0.0;

    return FuelQuotaModel(
      id: getInt(id),
      vehicleId: getInt(vehicleId),
      weekStart: getDateTime(weekStart),
      weekEnd: getDateTime(weekEnd),
      quotaLitres: getDouble(quotaLitres),
      usedLitres: getDouble(usedLitres),
    );
  }

  // Alternative constructor for backend response with different key names
  factory FuelQuotaModel.fromBackendResponse(Map<String, dynamic> response) {
    // If response has nested 'data'
    final data =
        response.containsKey('data') && response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;

    return FuelQuotaModel.fromMap(data);
  }

  FuelQuotaModel copyWith({
    int? id,
    int? vehicleId,
    DateTime? weekStart,
    DateTime? weekEnd,
    double? quotaLitres,
    double? usedLitres,
  }) => FuelQuotaModel(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    weekStart: weekStart ?? this.weekStart,
    weekEnd: weekEnd ?? this.weekEnd,
    quotaLitres: quotaLitres ?? this.quotaLitres,
    usedLitres: usedLitres ?? this.usedLitres,
  );
}
