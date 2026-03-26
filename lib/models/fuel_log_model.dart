/// Represents a single fuel refuel entry logged by the user.
class FuelLogModel {
  final int? id;
  final int userId;
  final int vehicleId;
  final double litres;
  final String fuelType; // Petrol, Diesel, Hybrid, Kerosene …
  final String
  fuelGrade; // Petrol 92, Petrol 95, Auto Diesel, Super Diesel, Kerosene
  final double pricePerLitre;
  final double totalCost;
  final String stationName;
  final DateTime loggedAt;

  FuelLogModel({
    this.id,
    required this.userId,
    required this.vehicleId,
    required this.litres,
    required this.fuelType,
    required this.fuelGrade,
    required this.pricePerLitre,
    required this.totalCost,
    this.stationName = '',
    DateTime? loggedAt,
  }) : loggedAt = loggedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'vehicle_id': vehicleId,
    'litres': litres,
    'fuel_type': fuelType,
    'fuel_grade': fuelGrade,
    'price_per_litre': pricePerLitre,
    'total_cost': totalCost,
    'station_name': stationName,
    'logged_at': loggedAt.toIso8601String(),
  };

  factory FuelLogModel.fromMap(Map<String, dynamic> m) => FuelLogModel(
    id: m['id'] as int?,
    userId: m['user_id'] as int,
    vehicleId: m['vehicle_id'] as int,
    litres: (m['litres'] as num).toDouble(),
    fuelType: m['fuel_type'] as String,
    fuelGrade: m['fuel_grade'] as String? ?? '',
    pricePerLitre: (m['price_per_litre'] as num).toDouble(),
    totalCost: (m['total_cost'] as num).toDouble(),
    stationName: m['station_name'] as String? ?? '',
    loggedAt: DateTime.parse(m['logged_at'] as String),
  );

  FuelLogModel copyWith({
    int? id,
    int? userId,
    int? vehicleId,
    double? litres,
    String? fuelType,
    String? fuelGrade,
    double? pricePerLitre,
    double? totalCost,
    String? stationName,
    DateTime? loggedAt,
  }) => FuelLogModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    vehicleId: vehicleId ?? this.vehicleId,
    litres: litres ?? this.litres,
    fuelType: fuelType ?? this.fuelType,
    fuelGrade: fuelGrade ?? this.fuelGrade,
    pricePerLitre: pricePerLitre ?? this.pricePerLitre,
    totalCost: totalCost ?? this.totalCost,
    stationName: stationName ?? this.stationName,
    loggedAt: loggedAt ?? this.loggedAt,
  );

  /// e.g. "25 Mar 2026"
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

  /// e.g. "14:35"
  String get formattedTime {
    final h = loggedAt.hour.toString().padLeft(2, '0');
    final m = loggedAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
