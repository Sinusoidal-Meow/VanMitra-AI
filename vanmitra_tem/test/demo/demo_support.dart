import 'dart:io';

import 'package:vanmitra_ai/core/api/api_client.dart';
import 'package:vanmitra_ai/demo/core/demo_accounts.dart';
import 'package:vanmitra_ai/demo/demo_backend.dart';
import 'package:vanmitra_ai/demo/demo_mode.dart';

/// A demo "server" for tests: in-memory storage, a clock you can move, and sign-in by phone.
///
///     final h = DemoHarness();
///     final villager = await h.login('9000000001');
///     final c = await h.call('POST', '/villages/${DemoAccounts.villageId}/cases',
///         token: villager, body: {'claim_type': 'ifr'});
class DemoHarness {
  DemoHarness({DateTime? start, bool sampleClaims = false})
      : _now = start ?? DateTime.utc(2026, 10, 14, 6, 30) {
    DemoMode.idForTest = 'all';
    backend = DemoBackend(
      storage: MemoryDemoStorage(),
      loadAsset: (path) => File(path).readAsString(),
      clock: () => _now,
      seedSampleClaims: sampleClaims,
    );
  }

  late final DemoBackend backend;
  DateTime _now;

  /// The current time of the demo server (UTC).
  DateTime get now => _now;

  void advance(Duration d) => _now = _now.add(d);

  /// Sign in as a seeded demo user (9000000001/2 village users, 3 Gram Sabha, 4 admin, 5 SDO),
  /// or any registered phone with PIN 123456; returns the access token.
  Future<String> login(String phone, {String pin = DemoAccounts.pin}) async {
    final t = await backend.handle('POST', '/auth/login', body: {'phone': phone, 'pin': pin});
    return (t as Map)['access_token'] as String;
  }

  /// One API call; returns the decoded JSON (or null), or throws [ApiException].
  Future<dynamic> call(String method, String path, {Object? body, String? token}) =>
      backend.handle(method, path, body: body, token: token);

  /// The [ApiException] a call throws (fails the test if it succeeds).
  Future<ApiException> fails(String method, String path, {Object? body, String? token}) async {
    try {
      await call(method, path, body: body, token: token);
    } on ApiException catch (e) {
      return e;
    }
    throw StateError('$method $path was expected to fail');
  }

  void dispose() => DemoMode.idForTest = null;
}
