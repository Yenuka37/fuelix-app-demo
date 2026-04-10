import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StaffCacheService {
  static const String _staffCacheKey = 'staff_auth_cache';
  static const String _staffCacheTimestampKey = 'staff_auth_timestamp';
  static const int _cacheExpiryDays = 7;

  // Save staff data to cache with timestamp
  Future<void> saveStaffCache(Map<String, dynamic> staffData) async {
    final prefs = await SharedPreferences.getInstance();

    // Save the staff data
    await prefs.setString(_staffCacheKey, json.encode(staffData));

    // Save the timestamp (current time)
    await prefs.setString(
      _staffCacheTimestampKey,
      DateTime.now().toIso8601String(),
    );

    print('Staff cache saved successfully');
    print('Cache will expire after $_cacheExpiryDays days');
  }

  // Get valid staff cache (returns null if expired or not exists)
  Future<Map<String, dynamic>?> getValidStaffCache() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if cache exists
    final cachedDataStr = prefs.getString(_staffCacheKey);
    final timestampStr = prefs.getString(_staffCacheTimestampKey);

    if (cachedDataStr == null || timestampStr == null) {
      print('No staff cache found');
      return null;
    }

    // Check if cache is expired
    final cachedTime = DateTime.parse(timestampStr);
    final now = DateTime.now();
    final difference = now.difference(cachedTime);
    final daysDifference = difference.inDays;

    if (daysDifference >= _cacheExpiryDays) {
      print(
        'Staff cache expired (Age: $daysDifference days, Max: $_cacheExpiryDays days)',
      );
      await clearStaffCache();
      return null;
    }

    print('Valid staff cache found (Age: $daysDifference days)');

    // Parse and return cached data
    final Map<String, dynamic> cachedData = json.decode(cachedDataStr);
    return cachedData;
  }

  // Check if valid cache exists (without loading data)
  Future<bool> hasValidCache() async {
    final prefs = await SharedPreferences.getInstance();

    final timestampStr = prefs.getString(_staffCacheTimestampKey);
    if (timestampStr == null) return false;

    final cachedTime = DateTime.parse(timestampStr);
    final now = DateTime.now();
    final difference = now.difference(cachedTime);
    final daysDifference = difference.inDays;

    return daysDifference < _cacheExpiryDays;
  }

  // Get cache age in days
  Future<int?> getCacheAgeInDays() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampStr = prefs.getString(_staffCacheTimestampKey);

    if (timestampStr == null) return null;

    final cachedTime = DateTime.parse(timestampStr);
    final now = DateTime.now();
    final difference = now.difference(cachedTime);

    return difference.inDays;
  }

  // Get remaining days until expiry
  Future<int?> getRemainingDays() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampStr = prefs.getString(_staffCacheTimestampKey);

    if (timestampStr == null) return null;

    final cachedTime = DateTime.parse(timestampStr);
    final now = DateTime.now();
    final difference = now.difference(cachedTime);
    final daysUsed = difference.inDays;

    return _cacheExpiryDays - daysUsed;
  }

  // Clear staff cache
  Future<void> clearStaffCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_staffCacheKey);
    await prefs.remove(_staffCacheTimestampKey);
    print('Staff cache cleared');
  }

  // Get cache expiry days constant
  int getCacheExpiryDays() => _cacheExpiryDays;
}
