class VehicleModel {
  final int? id;
  final int userId;
  final String type; // Car, Motorcycle, Van, Truck, Bus, Three-Wheeler
  final String make; // Toyota, Honda …
  final String model; // Corolla, Civic …
  final String year;
  final String registrationNo; // WP CAB-1234
  final String fuelType; // Petrol, Diesel, Electric, Hybrid
  final String engineCC; // 1500, 2000 …
  final String color;
  final DateTime? createdAt;

  VehicleModel({
    this.id,
    required this.userId,
    required this.type,
    required this.make,
    required this.model,
    required this.year,
    required this.registrationNo,
    required this.fuelType,
    this.engineCC = '',
    this.color = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'type': type,
    'make': make,
    'model': model,
    'year': year,
    'registration_no': registrationNo,
    'fuel_type': fuelType,
    'engine_cc': engineCC,
    'color': color,
    'created_at':
        createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
  };

  factory VehicleModel.fromMap(Map<String, dynamic> m) => VehicleModel(
    id: m['id'] as int?,
    userId: m['user_id'] as int,
    type: m['type'] as String,
    make: m['make'] as String,
    model: m['model'] as String,
    year: m['year'] as String,
    registrationNo: m['registration_no'] as String,
    fuelType: m['fuel_type'] as String,
    engineCC: m['engine_cc'] as String? ?? '',
    color: m['color'] as String? ?? '',
    createdAt: m['created_at'] != null
        ? DateTime.tryParse(m['created_at'] as String)
        : null,
  );

  VehicleModel copyWith({
    int? id,
    int? userId,
    String? type,
    String? make,
    String? model,
    String? year,
    String? registrationNo,
    String? fuelType,
    String? engineCC,
    String? color,
    DateTime? createdAt,
  }) => VehicleModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    type: type ?? this.type,
    make: make ?? this.make,
    model: model ?? this.model,
    year: year ?? this.year,
    registrationNo: registrationNo ?? this.registrationNo,
    fuelType: fuelType ?? this.fuelType,
    engineCC: engineCC ?? this.engineCC,
    color: color ?? this.color,
    createdAt: createdAt ?? this.createdAt,
  );

  String get displayName => '$make $model ($year)';
  String get shortDisplay => '$make $model';
}
