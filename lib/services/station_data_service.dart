import 'dart:math';
import '../models/fuel_station_model.dart';
import 'api_service.dart';

class StationDataService {
  static const double MAX_DISTANCE_KM = 30.0;

  final ApiService _apiService = ApiService();
  List<FuelStation> _allStations = [];

  /// Load stations from backend API
  Future<List<FuelStation>> loadStations() async {
    try {
      final result = await _apiService.getAllFuelStations();

      if (result['success'] && result['data'] != null) {
        List<dynamic> stationsJson = result['data'];
        _allStations = stationsJson
            .map((json) => FuelStation.fromJson(json))
            .toList();
        return _allStations;
      } else {
        print('Failed to load stations from API: ${result['error']}');
        return [];
      }
    } catch (e) {
      print('Error loading stations: $e');
      return [];
    }
  }

  /// Get stations within 30km radius of user location
  List<FuelStation> getStationsWithinRadius(double userLat, double userLon) {
    return _allStations
        .map((station) {
          final distance = _calculateDistance(
            userLat,
            userLon,
            station.latitude,
            station.longitude,
          );
          return station.copyWith(distanceKm: distance);
        })
        .where((station) => station.distanceKm <= MAX_DISTANCE_KM)
        .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  }

  /// Get all stations (no distance filter)
  List<FuelStation> getAllStations() {
    return List.from(_allStations);
  }

  /// Refresh stations from backend
  Future<void> refreshStations() async {
    await loadStations();
  }

  /// Calculate distance using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // Earth's radius in km
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final dLon = (lon2 - lon1) * 3.141592653589793 / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * 3.141592653589793 / 180) *
            cos(lat2 * 3.141592653589793 / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}
