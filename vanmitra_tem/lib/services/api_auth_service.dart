import 'package:vanmitra_ai/core/api/api_client.dart';
import 'package:vanmitra_ai/core/api/api_endpoints.dart';
import 'package:vanmitra_ai/core/auth/auth_storage.dart';
import 'package:vanmitra_ai/models/user.dart';
import 'package:vanmitra_ai/models/user_role.dart';

class ApiAuthService {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  ApiAuthService({ApiClient? apiClient, AuthStorage? authStorage})
      : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  /// Login with phone and pin
  Future<User> login(String phone, String pin) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      body: {'phone': phone, 'pin': pin},
      requireAuth: false,
    );
    
    if (response != null && response['access_token'] != null) {
      await _authStorage.saveTokens(
        accessToken: response['access_token'],
        refreshToken: response['refresh_token'] ?? '',
      );
      return getMe();
    }
    throw Exception('Login failed: Invalid response');
  }

  /// Register new user
  Future<User> register({
    required String phone,
    required String pin,
    required String name,
    required String role,
    required String villageId,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.register,
      body: {
        'phone': phone,
        'pin': pin,
        'name': name,
        'role': role,
        'village_id': villageId,
      },
      requireAuth: false,
    );
    
    if (response != null && response['access_token'] != null) {
      await _authStorage.saveTokens(
        accessToken: response['access_token'],
        refreshToken: response['refresh_token'] ?? '',
      );
      return getMe();
    }
    throw Exception('Registration failed: Invalid response');
  }

  /// Get current user profile (/me)
  Future<User> getMe() async {
    final response = await _apiClient.get(ApiEndpoints.me);
    if (response != null) {
      // Build User model from backend response
      final roleStr = response['role'] as String? ?? 'villager';
      final role = UserRoleExtension.parse(roleStr);

      return User(
        id: response['id'] ?? '',
        email: response['email'] ?? '',
        name: response['name'] ?? '',
        role: role,
        villageId: response['village_id'] ?? 'ozhar_jawhar_palghar',
        tehsil: response['tehsil'] ?? 'Jawhar',
        district: response['district'] ?? 'Palghar',
        state: response['state'] ?? 'Maharashtra',
        preferredLanguage: response['preferredLanguage'] ?? 'mr',
        createdAt: response['created_at'] != null 
            ? DateTime.tryParse(response['created_at']) ?? DateTime.now()
            : DateTime.now(),
      );
    }
    throw Exception('Failed to fetch user profile');
  }

  /// Fetch public villages
  Future<List<Map<String, dynamic>>> getVillages() async {
    final response = await _apiClient.get(ApiEndpoints.villages, requireAuth: false);
    if (response != null && response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    return [];
  }

  Future<void> logout() async {
    await _authStorage.clearTokens();
  }
}
