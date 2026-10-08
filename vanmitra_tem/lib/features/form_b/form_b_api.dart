// Client for the VanMitra backend Form B API (docs/API_FORM_B.md).
//
// Base URL: --dart-define=VANMITRA_API_BASE_URL=http://localhost:8000
// (phone over USB: `adb reverse tcp:8000 tcp:8000`; emulator: 10.0.2.2).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../form_c/form_c_models.dart';
import 'form_b_models.dart';

const String _apiBaseUrl = String.fromEnvironment(
  'VANMITRA_API_BASE_URL',
  defaultValue: kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000',
);

/// Error body returned by every backend endpoint: {error, message_key, rule?, details}.
class ApiException implements Exception {
  ApiException(this.status, this.error, this.messageKey, {this.rule, this.details});

  final int status;
  final String error;
  final String messageKey;
  final String? rule;
  final Map<String, dynamic>? details;

  @override
  String toString() => rule == null ? '$error ($status)' : '$error ($status) · $rule';
}

class FormBApi {
  FormBApi({String? baseUrl}) : baseUrl = baseUrl ?? _apiBaseUrl;

  final String baseUrl;
  String? _accessToken;

  bool get isLoggedIn => _accessToken != null;

  void logout() => _accessToken = null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl/api/v1$path');

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (body is Map<String, dynamic>) {
      throw ApiException(
        res.statusCode,
        body['error'] as String? ?? 'HTTP_${res.statusCode}',
        body['message_key'] as String? ?? 'http.${res.statusCode}',
        rule: body['rule'] as String?,
        details: body['details'] as Map<String, dynamic>?,
      );
    }
    throw ApiException(res.statusCode, 'HTTP_${res.statusCode}', 'http.${res.statusCode}');
  }

  Future<void> login(String phone, String pin) async {
    final res = await http
        .post(_uri('/auth/login'), headers: _headers, body: jsonEncode({'phone': phone, 'pin': pin}))
        .timeout(const Duration(seconds: 10));
    final body = _decode(res) as Map<String, dynamic>;
    _accessToken = body['access_token'] as String;
  }

  Future<Me> me() async {
    final res = await http.get(_uri('/me'), headers: _headers).timeout(const Duration(seconds: 10));
    return Me.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<List<CaseSummary>> listCases(String villageId) async {
    final res = await http
        .get(_uri('/villages/$villageId/cases'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    return (_decode(res) as List<dynamic>)
        .map((e) => CaseSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CaseSummary> createCommunityRightsCase(String villageId) async {
    final res = await http
        .post(_uri('/villages/$villageId/cases'), headers: _headers, body: jsonEncode({'claim_type': 'cr'}))
        .timeout(const Duration(seconds: 10));
    return CaseSummary.fromJson(_decode(res) as Map<String, dynamic>);
  }

  /// Opens a case: 'cr' → empty Form B draft, 'cfr' → empty Form C draft.
  Future<CaseSummary> createCase(String villageId, String claimType) async {
    final res = await http
        .post(_uri('/villages/$villageId/cases'), headers: _headers, body: jsonEncode({'claim_type': claimType}))
        .timeout(const Duration(seconds: 10));
    return CaseSummary.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<FormCData> getFormC(String caseId) async {
    final res = await http
        .get(_uri('/cases/$caseId/form-c'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    return FormCData.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<FormCData> saveFormC(String caseId, Map<String, dynamic> body) async {
    final res = await http
        .put(_uri('/cases/$caseId/form-c'), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return FormCData.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<List<GsMember>> listMembers(String villageId) async {
    final res = await http
        .get(_uri('/villages/$villageId/members'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    return (_decode(res) as List<dynamic>).map((e) => GsMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<GsMember> addMember(String villageId, {required String name, required String gender, required String category}) async {
    final res = await http
        .post(_uri('/villages/$villageId/members'),
            headers: _headers, body: jsonEncode({'name': name, 'gender': gender, 'category': category}))
        .timeout(const Duration(seconds: 10));
    return GsMember.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<GsMember> updateMember(String memberId, Map<String, dynamic> changes) async {
    final res = await http
        .patch(_uri('/members/$memberId'), headers: _headers, body: jsonEncode(changes))
        .timeout(const Duration(seconds: 10));
    return GsMember.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<FormBData> getFormB(String caseId) async {
    final res = await http
        .get(_uri('/cases/$caseId/form-b'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    return FormBData.fromJson(_decode(res) as Map<String, dynamic>);
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
    final res = await http
        .put(_uri('/cases/$caseId/form-b'), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return FormBData.fromJson(_decode(res) as Map<String, dynamic>);
  }
}

/// One client for the app session (token kept in memory only for now).
final formBApi = FormBApi();
