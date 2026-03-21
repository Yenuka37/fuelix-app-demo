import 'package:shared_preferences/shared_preferences.dart';

/// Keys for every tutorial / onboarding step in the app.
enum TutorialKey {
  onboarding, // Full onboarding slides (first login)
  homeTour, // Home screen spotlight tour
  vehiclesTour, // Vehicles screen tour
  topupTour, // Top-up screen tour
  fuelPassTour, // Fuel pass QR tour
}

class TutorialService {
  TutorialService._();

  static const _prefix = 'tutorial_seen_';

  static String _key(TutorialKey k) => '$_prefix${k.name}';

  /// Returns true if this tutorial has been completed/dismissed before.
  static Future<bool> isSeen(TutorialKey key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(key)) ?? false;
  }

  /// Mark a tutorial as seen so it never shows again.
  static Future<void> markSeen(TutorialKey key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(key), true);
  }

  /// Reset a specific tutorial (for testing / "replay tutorial" feature).
  static Future<void> reset(TutorialKey key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(key));
  }

  /// Reset ALL tutorials.
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in TutorialKey.values) {
      await prefs.remove(_key(k));
    }
  }
}
