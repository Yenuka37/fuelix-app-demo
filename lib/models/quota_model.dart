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
    'vehicle_id': vehicleId,
    'week_start': weekStart.toIso8601String(),
    'week_end': weekEnd.toIso8601String(),
    'quota_litres': quotaLitres,
    'used_litres': usedLitres,
  };

  factory FuelQuotaModel.fromMap(Map<String, dynamic> m) => FuelQuotaModel(
    id: m['id'] as int?,
    vehicleId: m['vehicle_id'] as int,
    weekStart: DateTime.parse(m['week_start'] as String),
    weekEnd: DateTime.parse(m['week_end'] as String),
    quotaLitres: (m['quota_litres'] as num).toDouble(),
    usedLitres: (m['used_litres'] as num).toDouble(),
  );

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
