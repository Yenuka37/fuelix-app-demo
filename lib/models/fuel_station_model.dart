class FuelStation {
  final int id;
  final String name;
  final String brand;
  final String address;
  final String district;
  final String province;
  final double latitude;
  final double longitude;
  final List<String> availableFuels;
  final bool isFuelixPartner;
  final bool is24Hours;
  final String operatingHours;
  final List<String> amenities;
  double distanceKm;
  final bool isOpen;

  FuelStation({
    required this.id,
    required this.name,
    required this.brand,
    required this.address,
    required this.district,
    required this.province,
    required this.latitude,
    required this.longitude,
    required this.availableFuels,
    required this.isFuelixPartner,
    required this.is24Hours,
    required this.operatingHours,
    required this.amenities,
    required this.distanceKm,
    required this.isOpen,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'address': address,
    'district': district,
    'province': province,
    'latitude': latitude,
    'longitude': longitude,
    'availableFuels': availableFuels,
    'isFuelixPartner': isFuelixPartner,
    'is24Hours': is24Hours,
    'operatingHours': operatingHours,
    'amenities': amenities,
    'isOpen': isOpen,
  };

  factory FuelStation.fromJson(Map<String, dynamic> json) => FuelStation(
    id: json['id'] as int,
    name: json['name'] as String,
    brand: json['brand'] as String,
    address: json['address'] as String,
    district: json['district'] as String,
    province: json['province'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    availableFuels: List<String>.from(json['availableFuels']),
    isFuelixPartner: json['isFuelixPartner'] as bool,
    is24Hours: json['is24Hours'] as bool,
    operatingHours: json['operatingHours'] as String,
    amenities: List<String>.from(json['amenities']),
    distanceKm: 0.0,
    isOpen: json['isOpen'] as bool,
  );

  FuelStation copyWith({double? distanceKm}) => FuelStation(
    id: id,
    name: name,
    brand: brand,
    address: address,
    district: district,
    province: province,
    latitude: latitude,
    longitude: longitude,
    availableFuels: availableFuels,
    isFuelixPartner: isFuelixPartner,
    is24Hours: is24Hours,
    operatingHours: operatingHours,
    amenities: amenities,
    distanceKm: distanceKm ?? this.distanceKm,
    isOpen: isOpen,
  );
}
