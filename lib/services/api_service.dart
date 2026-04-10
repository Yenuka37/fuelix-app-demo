import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.43.214:8080/api';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ==================== STAFF AUTHENTICATION FOR QR SCANNER ====================

  // Add/Update this method in ApiService class

  // Staff authentication for QR scanner
  Future<Map<String, dynamic>> authenticateStaff(
    String nic,
    String password,
  ) async {
    try {
      print('Authenticating staff: $nic');

      final response = await http
          .post(
            Uri.parse('$baseUrl/staff/auth'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'nic': nic, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.body.isEmpty) {
        return {'success': false, 'error': 'Empty response from server'};
      }

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Save token for subsequent requests
        if (data['token'] != null && data['token'].toString().isNotEmpty) {
          await saveToken(data['token']);
        }
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': data['error'] ?? 'Invalid NIC or password',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'error': data['error'] ?? 'Access denied. Staff only.',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Authentication failed',
        };
      }
    } catch (e) {
      print('Authentication error: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Save staff data locally
  Future<void> saveStaffData(Map<String, dynamic> staffData) async {
    final prefs = await SharedPreferences.getInstance();
    if (staffData['userId'] != null) {
      await prefs.setInt('staff_user_id', staffData['userId']);
    }
    if (staffData['staffId'] != null) {
      await prefs.setInt('staff_id', staffData['staffId']);
    }
    if (staffData['stationId'] != null) {
      await prefs.setInt('station_id', staffData['stationId']);
    }
    if (staffData['stationName'] != null) {
      await prefs.setString('station_name', staffData['stationName']);
    }
    if (staffData['stationBrand'] != null) {
      await prefs.setString('station_brand', staffData['stationBrand']);
    }
    if (staffData['staffName'] != null) {
      await prefs.setString('staff_name', staffData['staffName']);
    }
  }

  // Get saved staff data
  Future<Map<String, dynamic>?> getStaffData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('staff_user_id');
    if (userId == null) return null;

    return {
      'userId': userId,
      'staffId': prefs.getInt('staff_id'),
      'stationId': prefs.getInt('station_id'),
      'stationName': prefs.getString('station_name'),
      'stationBrand': prefs.getString('station_brand'),
      'staffName': prefs.getString('staff_name'),
    };
  }

  // Clear staff data on logout
  Future<void> clearStaffData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('staff_user_id');
    await prefs.remove('staff_id');
    await prefs.remove('station_id');
    await prefs.remove('station_name');
    await prefs.remove('station_brand');
    await prefs.remove('staff_name');
  }

  // ==================== AUTH APIs ====================

  // Send OTP to mobile
  Future<Map<String, dynamic>> sendMobileOTP(String mobile) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/send-otp'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'mobile': mobile}),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Send OTP to email
  Future<Map<String, dynamic>> sendEmailOTP(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/send-otp'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email}),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Verify OTP
  Future<Map<String, dynamic>> verifyOTP(
    String identifier,
    String otp,
    String type,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'identifier': identifier,
              'otp': otp,
              'type': type,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['valid'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': data['message'] ?? 'Invalid OTP'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Signup
  Future<Map<String, dynamic>> signup(Map<String, dynamic> userData) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/signup'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(userData),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Signup failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Login
  Future<Map<String, dynamic>> login(String nic, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'nic': nic, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        await saveToken(data['token']);
        print('Login response - Role: ${data['role']}');
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Get user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/auth/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        print('Profile response - Role: ${data['role']}');
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to get profile',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Get user by ID
  Future<Map<String, dynamic>> getUserById(int userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/auth/user/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch user details',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateUserProfile(
    int userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/auth/user/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(userData),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Change password
  Future<Map<String, dynamic>> changePassword(
    int userId,
    String oldPassword,
    String newPassword,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/change-password'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'userId': userId,
              'oldPassword': oldPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to change password',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== FUEL PRICE APIs ====================

  // Get all fuel prices from backend
  Future<Map<String, dynamic>> getFuelPrices() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/fuel-logs/prices'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch fuel prices',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== QUOTA LIMIT APIs ====================

  Future<Map<String, dynamic>> getAllQuotaLimits() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/admin/quotas/limits'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch quota limits',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getQuotaLimitByVehicleType(
    String vehicleType,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/admin/quotas/limits/$vehicleType'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch quota limit',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== VEHICLE DATA APIs ====================

  Future<Map<String, dynamic>> getBrandsByVehicleType(
    String vehicleType,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/vehicle-data/brands/type/$vehicleType'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch brands',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getModelsByBrandId(int brandId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/vehicle-data/models/brand/$brandId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch models',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getModelsByVehicleType(
    String vehicleType,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/vehicle-data/models/type/$vehicleType'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch models',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getModelsByBrandAndType(
    int brandId,
    String vehicleType,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/vehicle-data/models/brand/$brandId/type/$vehicleType',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch models',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getBrandsWithModelsByType(
    String vehicleType,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/vehicle-data/brands-with-models/type/$vehicleType',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch vehicle data',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== VEHICLE APIs ====================

  Future<Map<String, dynamic>> getVehicles(int userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/vehicles/user/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data'] ?? data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch vehicles',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> addVehicle(
    Map<String, dynamic> vehicleData,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/vehicles'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(vehicleData),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to add vehicle',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateVehicle(
    int id,
    Map<String, dynamic> vehicleData,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/vehicles/$id'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(vehicleData),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to update vehicle',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteVehicle(int id) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .delete(
            Uri.parse('$baseUrl/vehicles/$id'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to delete vehicle',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> generateFuelPass(int vehicleId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/vehicles/$vehicleId/generate-pass'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to generate Fuel Pass',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> regenerateFuelPass(int vehicleId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/vehicles/regenerate-pass/$vehicleId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to regenerate Fuel Pass',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== QR SCANNER PASSCODE APIs ====================

  Future<Map<String, dynamic>> verifyVehiclePasscode(String passcode) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/vehicles/verify-passcode?passcode=$passcode'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else if (response.statusCode == 404) {
        return {'success': false, 'error': 'Invalid Fuel Pass Code'};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to verify passcode',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> checkPasscodeExists(String passcode) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/vehicles/check-passcode/$passcode'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'valid': data['valid'] ?? false};
      } else {
        return {'success': false, 'valid': false};
      }
    } catch (e) {
      return {'success': false, 'valid': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getVehicleByPasscode(String passcode) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/vehicles/by-passcode/$passcode'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch vehicle',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== FUEL LOG APIs ====================

  Future<Map<String, dynamic>> addFuelLog(Map<String, dynamic> logData) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final Map<String, dynamic> cleanData = {};

      if (logData.containsKey('userId') && logData['userId'] != null) {
        cleanData['userId'] = logData['userId'];
      } else {
        return {'success': false, 'error': 'userId is required'};
      }

      if (logData.containsKey('vehicleId') && logData['vehicleId'] != null) {
        cleanData['vehicleId'] = logData['vehicleId'];
      } else {
        return {'success': false, 'error': 'vehicleId is required'};
      }

      if (logData.containsKey('litres') && logData['litres'] != null) {
        cleanData['litres'] = logData['litres'];
      } else {
        return {'success': false, 'error': 'litres is required'};
      }

      if (logData.containsKey('fuelType') && logData['fuelType'] != null) {
        cleanData['fuelType'] = logData['fuelType'];
      } else {
        return {'success': false, 'error': 'fuelType is required'};
      }

      if (logData.containsKey('fuelGrade') && logData['fuelGrade'] != null) {
        cleanData['fuelGrade'] = logData['fuelGrade'];
      } else {
        return {'success': false, 'error': 'fuelGrade is required'};
      }

      if (logData.containsKey('vehicleType') &&
          logData['vehicleType'] != null) {
        cleanData['vehicleType'] = logData['vehicleType'];
      } else {
        return {'success': false, 'error': 'vehicleType is required'};
      }

      if (logData.containsKey('stationName') &&
          logData['stationName'] != null) {
        cleanData['stationName'] = logData['stationName'];
      } else {
        cleanData['stationName'] = '';
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/fuel-logs'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(cleanData),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to add fuel log',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getUserFuelLogs(int userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/fuel-logs/user/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch fuel logs',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getFuelLogStats(int userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/fuel-logs/stats/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch stats',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteFuelLog(int logId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .delete(
            Uri.parse('$baseUrl/fuel-logs/$logId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to delete fuel log',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== WALLET APIs ====================

  Future<Map<String, dynamic>> getWallet(int userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/wallet/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch wallet',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> topUpWallet(
    int userId,
    double amount,
    String method, {
    String? reference,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final Map<String, dynamic> requestData = {
        'userId': userId,
        'amount': amount,
        'method': method,
      };

      if (reference != null) {
        requestData['reference'] = reference;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/wallet/topup'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Top up failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getTopUpTransactions(int userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/wallet/transactions/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch transactions',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== QUOTA APIs ====================

  Future<Map<String, dynamic>> getCurrentQuota(
    int vehicleId,
    String vehicleType,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/quotas/current/$vehicleId?vehicleType=$vehicleType',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch quota',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getQuotaHistory(int vehicleId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/quotas/history/$vehicleId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch quota history',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== FORGOT PASSWORD APIs ====================

  Future<Map<String, dynamic>> sendPasswordResetOTP(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password/send-otp'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email}),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'No account found with this email address',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to send reset code',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> verifyPasswordResetOTP(
    String email,
    String otp,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'identifier': email,
              'otp': otp,
              'type': 'EMAIL',
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['valid'] == true) {
        return {
          'success': true,
          'data': data,
          'resetToken': data['resetToken'],
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Invalid or expired OTP',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password/reset'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'email': email,
              'otp': otp,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to reset password',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== DELETE ACCOUNT API ====================

  Future<Map<String, dynamic>> deleteAccount(String nic, String reason) async {
    try {
      final token = await getToken();

      final response = await http
          .delete(
            Uri.parse('$baseUrl/auth/delete-account'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'nic': nic, 'reason': reason}),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        await clearToken();
        return {'success': true, 'data': data};
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'No account found with this NIC number',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to delete account',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== FUEL STATION APIs ====================

  Future<Map<String, dynamic>> getAllFuelStations() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/fuel-stations'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch fuel stations',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getFuelStationById(int id) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/fuel-stations/$id'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch fuel station',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getFuelStationsByProvince(
    String province,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/fuel-stations/province/$province'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch fuel stations',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getFuelStationsByDistrict(
    String district,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/fuel-stations/district/$district'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch fuel stations',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getFuelStationsByBrand(String brand) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/fuel-stations/brand/$brand'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch fuel stations',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getPartnerFuelStations() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/fuel-stations/partners'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch partner stations',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getOpenFuelStations() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/fuel-stations/open'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch open stations',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== NOTIFICATION APIs ====================

  Future<Map<String, dynamic>> getUserNotifications(int userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/notifications/user/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch notifications',
        };
      }
    } catch (e) {
      print('Error getting notifications: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== QR SCANNER APIs ====================

  Future<Map<String, dynamic>> getVehicleDetails(String vehicleId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/vehicles/$vehicleId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch vehicle details',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getFuelStationDetails(String stationId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/fuel-stations/$stationId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch fuel station details',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Test connection to server
  static Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('http://192.168.43.214:8080/api/auth/test'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
