// File: lib/models/vehicle_model.dart

class VehicleModel {
  final int? id;
  final int userId;
  final String type;
  final String make;
  final String model;
  final String year;
  final String registrationNo;
  final String fuelType;
  final String engineCC;
  final String color;
  final String?
  fuelPassCode; // This will contain the DECRYPTED code from backend
  final DateTime? qrGeneratedAt;
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
    this.fuelPassCode,
    this.qrGeneratedAt,
    this.createdAt,
  });

  bool get hasQr => fuelPassCode != null && fuelPassCode!.isNotEmpty;

  bool get isLocked => hasQr;

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
    'fuel_pass_code': fuelPassCode, // Store decrypted code locally
    'qr_generated_at': qrGeneratedAt?.toIso8601String(),
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
    fuelPassCode: m['fuel_pass_code'] as String?,
    qrGeneratedAt: m['qr_generated_at'] != null
        ? DateTime.tryParse(m['qr_generated_at'] as String)
        : null,
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
    String? fuelPassCode,
    DateTime? qrGeneratedAt,
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
    fuelPassCode: fuelPassCode ?? this.fuelPassCode,
    qrGeneratedAt: qrGeneratedAt ?? this.qrGeneratedAt,
    createdAt: createdAt ?? this.createdAt,
  );

  String get displayName => '$make $model ($year)';
  String get shortDisplay => '$make $model';
}
