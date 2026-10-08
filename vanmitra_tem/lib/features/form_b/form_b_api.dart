import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_storage.dart';
import '../form_c/form_c_models.dart';
import 'form_b_models.dart';

// Re-export ApiException so all consumers can use it uniformly
export '../../core/api/api_client.dart' show ApiException;

class FormBApi {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  FormBApi({ApiClient? apiClient, AuthStorage? authStorage}) 
      : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  String get baseUrl => ApiEndpoints.baseUrl;

  Future<bool> isLoggedIn() async {
    return (await _authStorage.getAccessToken()) != null;
  }

  Future<void> login(String phone, String pin) async {
    final res = await _apiClient.post(ApiEndpoints.login, body: {'phone': phone, 'pin': pin}, requireAuth: false);
    if (res != null && res['access_token'] != null) {
      await _authStorage.saveTokens(
        accessToken: res['access_token'],
        refreshToken: res['refresh_token'] ?? '',
      );
    }
  }

  Future<void> logout() async {
    await _authStorage.clearTokens();
  }

  Future<Me> me() async {
    final res = await _apiClient.get(ApiEndpoints.me);
    return Me.fromJson(res as Map<String, dynamic>);
  }

  Future<List<CaseSummary>> listCases(String villageId) async {
    final res = await _apiClient.get(ApiEndpoints.villageCases(villageId));
    return (res as List<dynamic>)
        .map((e) => CaseSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CaseSummary> createCommunityRightsCase(String villageId) async {
    return createCase(villageId, 'cr');
  }

  /// Opens a case: 'cr' -> Form B draft, 'cfr' -> Form C draft, 'ifr' -> Form A draft.
  Future<CaseSummary> createCase(String villageId, String claimType) async {
    final res = await _apiClient.post(
      ApiEndpoints.villageCases(villageId),
      body: {'claim_type': claimType},
    );
    return CaseSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<FormCData> getFormC(String caseId) async {
    final res = await _apiClient.get(ApiEndpoints.formC(caseId));
    return FormCData.fromJson(res as Map<String, dynamic>);
  }

  Future<FormCData> saveFormC(String caseId, Map<String, dynamic> body) async {
    final res = await _apiClient.put(ApiEndpoints.formC(caseId), body: body);
    return FormCData.fromJson(res as Map<String, dynamic>);
  }

  Future<List<GsMember>> listMembers(String villageId) async {
    final res = await _apiClient.get(ApiEndpoints.members(villageId));
    return (res as List<dynamic>)
        .map((e) => GsMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GsMember> addMember(
    String villageId, {
    required String name,
    required String gender,
    required String category,
  }) async {
    final res = await _apiClient.post(
      ApiEndpoints.members(villageId),
      body: {'name': name, 'gender': gender, 'category': category},
    );
    return GsMember.fromJson(res as Map<String, dynamic>);
  }

  Future<GsMember> updateMember(String memberId, Map<String, dynamic> changes) async {
    final res = await _apiClient.patch('/members/$memberId', body: changes);
    return GsMember.fromJson(res as Map<String, dynamic>);
  }

  Future<FormBData> getFormB(String caseId) async {
    final res = await _apiClient.get(ApiEndpoints.formB(caseId));
    return FormBData.fromJson(res as Map<String, dynamic>);
  }

  // ── Push messages and in-app notifications ──────────────────────────────────────

  /// Register this phone for push messages, in Marathi ('mr') or English ('en').
  Future<void> registerDevice(String token, {String platform = 'android', String language = 'mr'}) async {
    final res = await http
        .post(_uri('/devices'),
            headers: _headers, body: jsonEncode({'token': token, 'platform': platform, 'language': language}))
        .timeout(const Duration(seconds: 10));
    _decode(res);
  }

  /// Stop push messages to this phone (on sign-out).
  Future<void> removeDevice(String token) async {
    final res = await http
        .delete(_uri('/devices/${Uri.encodeComponent(token)}'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    _decode(res);
  }

  Future<NotificationsPage> notifications() async {
    final res = await http.get(_uri('/notifications'), headers: _headers).timeout(const Duration(seconds: 10));
    return NotificationsPage.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<void> markNotificationRead(String id) async {
    final res = await http
        .post(_uri('/notifications/$id/read'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    _decode(res);
  }

  Future<NotificationsPage> markAllNotificationsRead() async {
    final res = await http
        .post(_uri('/notifications/read-all'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    return NotificationsPage.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<FormBData> saveFormB(String caseId, Map<String, dynamic> body) async {
    final res = await _apiClient.put(ApiEndpoints.formB(caseId), body: body);
    return FormBData.fromJson(res as Map<String, dynamic>);
  }
}

/// One client for the app session
final formBApi = FormBApi();
