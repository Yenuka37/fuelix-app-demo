import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/fuel_station_model.dart';

class StationDataService {
  static const String _fileName = 'stations_db.json';
  static const double MAX_DISTANCE_KM = 30.0;

  List<FuelStation> _allStations = [];

  /// Load stations from assets (first time) and cache to local storage
  Future<List<FuelStation>> loadStations() async {
    try {
      // Try to load from local storage first
      final localFile = await _getLocalFile();
      if (await localFile.exists()) {
        final jsonString = await localFile.readAsString();
        final Map<String, dynamic> data = json.decode(jsonString);
        _allStations = _parseStations(data['stations']);
        return _allStations;
      }

      // Load from assets if no local file
      final jsonString = await rootBundle.loadString(
        'assets/data/stations_db.json',
      );
      final Map<String, dynamic> data = json.decode(jsonString);
      _allStations = _parseStations(data['stations']);

      // Save to local storage for future use
      await _saveToLocal();

      return _allStations;
    } catch (e) {
      print('Error loading stations: $e');
      return [];
    }
  }

  /// Save current stations to local storage
  Future<void> _saveToLocal() async {
    try {
      final localFile = await _getLocalFile();
      final Map<String, dynamic> data = {
        'stations': _allStations.map((s) => s.toJson()).toList(),
      };
      await localFile.writeAsString(json.encode(data));
    } catch (e) {
      print('Error saving stations: $e');
    }
  }

  /// Get local file path
  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  /// Parse stations from JSON
  List<FuelStation> _parseStations(List<dynamic> stationsJson) {
    return stationsJson.map((json) => FuelStation.fromJson(json)).toList();
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
