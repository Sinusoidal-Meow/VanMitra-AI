import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';

import '../core/api/api_client.dart';
import '../data/local/hive_database.dart';
import 'demo_livelihood.dart';
import 'demo_mode.dart';

/// Where the demo keeps what the presenter does (details saved, questions asked, claims filed),
/// so it survives closing the app. Tests use [MemoryDemoStorage].
abstract class DemoStorage {
  Map<String, dynamic> read();
  Future<void> write(Map<String, dynamic> state);
}

class MemoryDemoStorage implements DemoStorage {
  Map<String, dynamic> _state = {};

  @override
  Map<String, dynamic> read() => _state;

  @override
  Future<void> write(Map<String, dynamic> state) async => _state = state;
}

/// Kept in the app's own Hive settings box, on the phone only.
class HiveDemoStorage implements DemoStorage {
  static const _key = 'demo_state';

  @override
  Map<String, dynamic> read() {
    final raw = Hive.box(HiveDatabase.settingsBox).get(_key);
    if (raw is String) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {};
  }

  @override
  Future<void> write(Map<String, dynamic> state) =>
      Hive.box(HiveDatabase.settingsBox).put(_key, jsonEncode(state));
}

/// The OFFLINE DEMO "server": [ApiClient] hands every call to [handle] instead of the network,
/// and the answer comes from mock data bundled in the APK. See [DemoMode].
///
/// Every answer has the same shape the real server sends (Module 4's were produced by the real
/// rules), so the screens are the real screens. A call this demo does not cover answers 404 and
/// the screen shows its normal error state.
class DemoBackend {
  DemoBackend({DemoStorage? storage, Future<String> Function(String path)? loadAsset})
      : _storage = storage ?? MemoryDemoStorage(),
        _loadAsset = loadAsset ?? rootBundle.loadString;

  static DemoBackend? _instance;

  /// The one used by the app (state kept in Hive).
  static DemoBackend get instance => _instance ??= DemoBackend(storage: HiveDemoStorage());

  /// For tests.
  static set instance(DemoBackend value) => _instance = value;

  final DemoStorage _storage;
  final Future<String> Function(String path) _loadAsset;

  Map<String, dynamic>? _state;
  Map<String, dynamic>? _livelihoodFixture;

  /// The Ozhar village of the sample data (the host's demo village).
  static const String villageId = '01a11846-11fc-7894-bcb3-597768083ceb';

  Future<Map<String, dynamic>> _ensureState() async {
    return _state ??= _storage.read();
  }

  Future<DemoLivelihood> _livelihood() async {
    final state = await _ensureState();
    _livelihoodFixture ??=
        jsonDecode(await _loadAsset('assets/demo/livelihood_demo.json')) as Map<String, dynamic>;
    DemoLivelihood.seed(_livelihoodFixture!, state);
    return DemoLivelihood(_livelihoodFixture!, state);
  }

  /// Forget everything the presenter did (the sample data starts again).
  Future<void> reset() async {
    _state = {};
    await _storage.write(_state!);
  }

  /// The persona signed in: this build's own, or (a build with every persona) whoever logged in.
  Future<DemoPersona?> _persona() async {
    final state = await _ensureState();
    return DemoMode.persona ?? DemoMode.byPhone('${state['phone'] ?? ''}');
  }

  /// Answer one API call. [rawPath] is the path after /api/v1, with any query string.
  Future<dynamic> handle(String method, String rawPath, {Object? body}) async {
    final uri = Uri.parse(rawPath);
    final path = uri.path;
    final state = await _ensureState();

    dynamic result;
    if (path.startsWith('/livelihood/')) {
      final lv = await _livelihood();
      result = lv.handle(method, path, uri.queryParametersAll, body);
    } else {
      result = await _core(method, path, body, state);
    }
    await _storage.write(state);
    return result;
  }

  // ── sign-in, the user, the village list ───────────────────────────────────

  Future<dynamic> _core(
      String method, String path, Object? body, Map<String, dynamic> state) async {
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    switch ((method, path)) {
      case ('POST', '/auth/login'):
        final persona = DemoMode.byPhone('${map['phone']}');
        final allowed = persona != null &&
            '${map['pin']}' == DemoPersona.pin &&
            (DemoMode.persona == null || DemoMode.persona!.id == persona.id);
        if (!allowed) {
          throw ApiException(
            statusCode: 401,
            error: 'INVALID_CREDENTIALS',
            messageKey: 'auth.invalid_credentials',
          );
        }
        state['phone'] = persona.phone;
        return _tokens(persona);
      case ('POST', '/auth/refresh'):
        final persona = await _persona();
        if (persona == null) {
          throw ApiException(statusCode: 401, error: 'TOKEN_INVALID', messageKey: 'auth.token_invalid');
        }
        return _tokens(persona);
      case ('POST', '/auth/register'):
        throw ApiException(
          statusCode: 403,
          error: 'DEMO_MODE',
          messageKey: 'demo.no_registration',
        );
      case ('GET', '/me'):
        final persona = await _persona();
        if (persona == null) {
          throw ApiException(statusCode: 401, error: 'NOT_AUTHENTICATED', messageKey: 'auth.not_authenticated');
        }
        return {
          'id': 'demo-${persona.id}',
          'name': persona.name,
          'phone': persona.phone,
          'is_admin': false,
          'created_at': '2026-10-01T09:00:00Z',
          'roles': [
            {
              'role': 'villager',
              'village_id': villageId,
              'taluka': 'Jawhar',
              'district': 'Palghar',
            },
          ],
        };
      case ('GET', '/public/villages'):
        return [
          {'id': villageId, 'name_en': 'Ozhar (Jawhar, Palghar)', 'name_mr': 'ओझर (जव्हार, पालघर)'},
        ];
    }
    // lists the dashboard asks for on every start: nothing there (rather than an error on a tab
    // this demo does not use)
    if (method == 'GET' && _emptyLists.any((re) => re.hasMatch(path))) return <dynamic>[];
    throw ApiException(
      statusCode: 404,
      error: 'NOT_FOUND',
      messageKey: 'demo.not_available',
    );
  }

  static final List<RegExp> _emptyLists = [
    RegExp(r'^/cases/mine$'),
    RegExp(r'^/review/queue$'),
    RegExp(r'^/notifications'),
    RegExp(r'^/villages/[^/]+/(cases|meetings|members|claim-calls)$'),
  ];

  Map<String, dynamic> _tokens(DemoPersona p) => {
        'access_token': 'demo-access-${p.id}',
        'refresh_token': 'demo-refresh-${p.id}',
        'token_type': 'bearer',
        'expires_in': 86400,
      };
}
