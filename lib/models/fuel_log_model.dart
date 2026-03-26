/// Represents a single fuel refuel entry logged by the user.
class FuelLogModel {
  final int? id;
  final int userId;
  final int vehicleId;
  final double litres;
  final double odometerKm;
  final String fuelType;
  final double pricePerLitre;
  final double totalCost;
  final String stationName;
  final String notes;
  final DateTime loggedAt;

  FuelLogModel({
    this.id,
    required this.userId,
    required this.vehicleId,
    required this.litres,
    this.odometerKm = 0.0,
    required this.fuelType,
    this.pricePerLitre = 0.0,
    this.totalCost = 0.0,
    this.stationName = '',
    this.notes = '',
    DateTime? loggedAt,
  }) : loggedAt = loggedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'vehicle_id': vehicleId,
    'litres': litres,
    'odometer_km': odometerKm,
    'fuel_type': fuelType,
    'price_per_litre': pricePerLitre,
    'total_cost': totalCost,
    'station_name': stationName,
    'notes': notes,
    'logged_at': loggedAt.toIso8601String(),
  };

  factory FuelLogModel.fromMap(Map<String, dynamic> m) => FuelLogModel(
    id: m['id'] as int?,
    userId: m['user_id'] as int,
    vehicleId: m['vehicle_id'] as int,
    litres: (m['litres'] as num).toDouble(),
    odometerKm: (m['odometer_km'] as num).toDouble(),
    fuelType: m['fuel_type'] as String,
    pricePerLitre: (m['price_per_litre'] as num).toDouble(),
    totalCost: (m['total_cost'] as num).toDouble(),
    stationName: m['station_name'] as String? ?? '',
    notes: m['notes'] as String? ?? '',
    loggedAt: DateTime.parse(m['logged_at'] as String),
  );

  FuelLogModel copyWith({
    int? id,
    int? userId,
    int? vehicleId,
    double? litres,
    double? odometerKm,
    String? fuelType,
    double? pricePerLitre,
    double? totalCost,
    String? stationName,
    String? notes,
    DateTime? loggedAt,
  }) => FuelLogModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    vehicleId: vehicleId ?? this.vehicleId,
    litres: litres ?? this.litres,
    odometerKm: odometerKm ?? this.odometerKm,
    fuelType: fuelType ?? this.fuelType,
    pricePerLitre: pricePerLitre ?? this.pricePerLitre,
    totalCost: totalCost ?? this.totalCost,
    stationName: stationName ?? this.stationName,
    notes: notes ?? this.notes,
    loggedAt: loggedAt ?? this.loggedAt,
  );

  /// Formatted date string e.g. "25 Mar 2026"
  String get formattedDate {
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
    return '${loggedAt.day} ${months[loggedAt.month - 1]} ${loggedAt.year}';
  }

  /// Formatted time string e.g. "14:35"
  String get formattedTime {
    final h = loggedAt.hour.toString().padLeft(2, '0');
    final m = loggedAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
