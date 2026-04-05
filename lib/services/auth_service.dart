import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyRememberMe = 'remember_me';
  static const String _keySavedNic = 'saved_nic';
  static const String _keySavedPassword = 'saved_password';

  // Save login credentials if remember me is checked
  Future<void> saveCredentials(
    String nic,
    String password,
    bool rememberMe,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    if (rememberMe) {
      await prefs.setBool(_keyRememberMe, true);
      await prefs.setString(_keySavedNic, nic);
      await prefs.setString(_keySavedPassword, password);
    } else {
      await clearCredentials();
    }
  }

  // Load saved credentials
  Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;

    if (!rememberMe) return null;

    final nic = prefs.getString(_keySavedNic);
    final password = prefs.getString(_keySavedPassword);

    if (nic == null || password == null) return null;

    return {'nic': nic, 'password': password};
  }

  // Check if remember me is enabled
  Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }

  // Clear saved credentials
  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRememberMe);
    await prefs.remove(_keySavedNic);
    await prefs.remove(_keySavedPassword);
  }

  // Clear on logout
  Future<void> logout() async {
    await clearCredentials();
  }
}
