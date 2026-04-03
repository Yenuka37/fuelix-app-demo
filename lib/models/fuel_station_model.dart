import 'dart:convert';

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

  factory FuelStation.fromJson(Map<String, dynamic> json) {
    // Parse availableFuels (can be List or JSON string)
    List<String> fuels = [];
    if (json['availableFuels'] != null) {
      if (json['availableFuels'] is List) {
        fuels = List<String>.from(json['availableFuels']);
      } else if (json['availableFuels'] is String) {
        // If stored as JSON string
        try {
          List<dynamic> list = List<dynamic>.from(
            jsonDecode(json['availableFuels']),
          );
          fuels = list.map((e) => e.toString()).toList();
        } catch (e) {
          fuels = [];
        }
      }
    }

    // Parse amenities
    List<String> amenitiesList = [];
    if (json['amenities'] != null) {
      if (json['amenities'] is List) {
        amenitiesList = List<String>.from(json['amenities']);
      } else if (json['amenities'] is String) {
        try {
          List<dynamic> list = List<dynamic>.from(
            jsonDecode(json['amenities']),
          );
          amenitiesList = list.map((e) => e.toString()).toList();
        } catch (e) {
          amenitiesList = [];
        }
      }
    }

    return FuelStation(
      id: json['id'] as int,
      name: json['name'] as String,
      brand: json['brand'] as String,
      address: json['address'] as String,
      district: json['district'] as String,
      province: json['province'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      availableFuels: fuels,
      isFuelixPartner: json['isFuelixPartner'] ?? false,
      is24Hours: json['is24Hours'] ?? false,
      operatingHours: json['operatingHours'] as String? ?? '',
      amenities: amenitiesList,
      distanceKm: 0.0,
      isOpen: json['isOpen'] ?? true,
    );
  }

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
