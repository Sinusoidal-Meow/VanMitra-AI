import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_endpoints.dart';
import '../auth/auth_storage.dart';

class ApiException implements Exception {
  final int statusCode;
  final String error;
  final String messageKey;
  final String? rule;
  final Map<String, dynamic>? details;

  int get status => statusCode;

  ApiException({
    required this.statusCode,
    required this.error,
    required this.messageKey,
    this.rule,
    this.details,
  });

  factory ApiException.fromJson(int statusCode, Map<String, dynamic> json) {
    return ApiException(
      statusCode: statusCode,
      error: json['error'] ?? 'UNKNOWN_ERROR',
      messageKey: json['message_key'] ?? 'error.unknown',
      rule: json['rule'],
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'ApiException: $error (Rule: $rule) - $messageKey';
  }
}

class ApiClient {
  final AuthStorage _authStorage;

  ApiClient({AuthStorage? authStorage}) : _authStorage = authStorage ?? AuthStorage();

  Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final token = await _authStorage.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.bodyBytes.isEmpty) return null;
      // Always UTF-8: the server sends Marathi text, and without a charset in the
      // reply the http package would read it as Latin-1.
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        throw ApiException.fromJson(response.statusCode, body);
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException(
          statusCode: response.statusCode,
          error: 'NETWORK_OR_SERVER_ERROR',
          messageKey: 'error.network_or_server',
        );
      }
    }
  }

  Future<dynamic> get(String path, {bool requireAuth = true}) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.get(Uri.parse('${ApiEndpoints.baseUrl}$path'), headers: headers);
    return _handleResponse(response);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool requireAuth = true}) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.post(
      Uri.parse('${ApiEndpoints.baseUrl}$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body, bool requireAuth = true}) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.put(
      Uri.parse('${ApiEndpoints.baseUrl}$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(String path, {bool requireAuth = true}) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.delete(Uri.parse('${ApiEndpoints.baseUrl}$path'), headers: headers);
    return _handleResponse(response);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body, bool requireAuth = true}) async {
    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.patch(
      Uri.parse('${ApiEndpoints.baseUrl}$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }
}
