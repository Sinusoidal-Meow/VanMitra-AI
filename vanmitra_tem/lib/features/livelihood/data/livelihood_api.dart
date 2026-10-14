import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';

/// There was no usable answer at all: no network, a timeout, or a reply that was not JSON (a
/// captive-portal page, say). The feature treats this as "offline" and keeps working from what
/// is on the phone. A reply from the server, even an error, is an [ApiException] instead.
class NetworkException implements Exception {
  const NetworkException([this.cause]);
  final Object? cause;

  @override
  String toString() => 'NetworkException($cause)';
}

/// The four calls the feature makes. It depends on THIS, not on a concrete client, so the host's
/// own `ApiClient` (which throws raw socket errors and has no timeout) can be used unchanged
/// behind [HostApiAdapter].
abstract class LivelihoodApi {
  Future<dynamic> get(String path);
  Future<dynamic> post(String path, {Map<String, dynamic>? body});
  Future<dynamic> put(String path, {Map<String, dynamic>? body});
  Future<dynamic> delete(String path);
}

/// Wraps an [ApiClient] (the host's, or the standalone copy) and adds what the feature needs:
/// a timeout, and every "could not reach the server" failure turned into [NetworkException].
class HostApiAdapter implements LivelihoodApi {
  HostApiAdapter(this._client, {this.timeout = const Duration(seconds: 20)});

  final ApiClient _client;
  final Duration timeout;

  Future<dynamic> _guard(Future<dynamic> Function() call) async {
    try {
      return await call().timeout(timeout);
    } on TimeoutException catch (e) {
      throw NetworkException(e);
    } on SocketException catch (e) {
      throw NetworkException(e);
    } on http.ClientException catch (e) {
      throw NetworkException(e);
    } on FormatException catch (e) {
      throw NetworkException(
          e); // a 200 that was not JSON: a proxy or portal page, not our server
    }
  }

  @override
  Future<dynamic> get(String path) => _guard(() => _client.get(path));

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      _guard(() => _client.post(path, body: body));

  @override
  Future<dynamic> put(String path, {Map<String, dynamic>? body}) =>
      _guard(() => _client.put(path, body: body));

  @override
  Future<dynamic> delete(String path) => _guard(() => _client.delete(path));
}
