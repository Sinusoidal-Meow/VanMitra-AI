import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';

import '../core/api/api_client.dart';
import '../data/local/hive_database.dart';
import 'core/demo_accounts.dart';
import 'core/demo_cases.dart';
import 'core/demo_core.dart';
import 'boundary/demo_boundary.dart';
import 'boundary/demo_notifications.dart';
import 'demo_livelihood.dart';
import 'demo_seed_claims.dart';
import 'evidence/demo_evidence.dart';
import 'forms/demo_forms.dart';
import 'gramsabha/demo_gramsabha.dart';
import 'procedure/demo_procedure.dart';

/// Where the demo keeps everything the presenters do (accounts, claims, forms, details saved,
/// questions asked), so it survives closing the app. Tests use [MemoryDemoStorage].
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

/// Kept in the app's own Hive settings box, on the phone only. Saving the whole database after
/// every call would be slow once photos are in it, so writes are gathered: the latest state is
/// saved a moment after the last change.
class HiveDemoStorage implements DemoStorage {
  static const _key = 'demo_state_v2';
  static const _delay = Duration(milliseconds: 600);

  Map<String, dynamic>? _pending;
  Timer? _timer;

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
  Future<void> write(Map<String, dynamic> state) {
    _pending = state;
    _timer ??= Timer(_delay, flush);
    return Future.value();
  }

  /// Save now (also called when the app goes to the background).
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final state = _pending;
    _pending = null;
    if (state != null) await Hive.box(HiveDatabase.settingsBox).put(_key, jsonEncode(state));
  }
}

/// Saves the demo's data when the app goes to the background, so nothing is lost if it is closed
/// right after an action.
class DemoLifecycleFlush with WidgetsBindingObserver {
  DemoLifecycleFlush(this._storage);

  final HiveDemoStorage _storage;

  static void start() =>
      WidgetsBinding.instance.addObserver(DemoLifecycleFlush(DemoBackend.instance._hive));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _storage.flush();
  }
}

/// The OFFLINE DEMO "server": [ApiClient] hands every call to [handle] instead of the network.
///
/// It is a port of the real backend's rules to Dart, running on the phone over an in-memory
/// database (accounts and roles, the claim path, Forms A, B and C, evidence, the Gram Sabha, ...)
/// plus the Module 4 answers made by the real Module 4 rules. Every answer has the same shape the
/// real server sends, so the screens are the real screens. A call this demo does not cover answers
/// 404 and the screen shows its normal error state.
class DemoBackend {
  DemoBackend({
    DemoStorage? storage,
    Future<String> Function(String path)? loadAsset,
    DateTime Function()? clock,
    this.seedSampleClaims = false,
  })  : _storage = storage ?? MemoryDemoStorage(),
        _loadAsset = loadAsset ?? rootBundle.loadString,
        _clock = clock {
    DemoAccounts.register(_router);
    DemoCases.register(_router);
    DemoForms.register(_router);
    DemoEvidence.register(_router);
    DemoGramSabha.register(_router);
    DemoProcedure.register(_router);
    DemoBoundary.register(_router);
    DemoNotifications.register(_router);
    DemoLivelihood.register(_router, _livelihoodFixture);
  }

  static DemoBackend? _instance;

  /// The one used by the app (state kept in Hive).
  static DemoBackend get instance => _instance ??=
      DemoBackend(storage: HiveDemoStorage(), seedSampleClaims: true);

  HiveDemoStorage get _hive => _storage as HiveDemoStorage;

  /// For tests.
  static set instance(DemoBackend value) => _instance = value;

  /// Make a few SAMPLE claims the first time (see [DemoSeedClaims]).
  final bool seedSampleClaims;

  final DemoStorage _storage;
  final Future<String> Function(String path) _loadAsset;
  final DateTime Function()? _clock;
  final DemoRouter _router = DemoRouter();

  DemoDb? _db;
  Map<String, dynamic>? _fixture;

  /// The Ozhar village of the sample data (the host's demo village).
  static const String villageId = DemoAccounts.villageId;

  Future<Map<String, dynamic>> _livelihoodFixture() async {
    return _fixture ??=
        jsonDecode(await _loadAsset('assets/demo/livelihood_demo.json')) as Map<String, dynamic>;
  }

  DemoDb get _database {
    final existing = _db;
    if (existing != null) return existing;
    final db = DemoDb(_storage.read(), clock: _clock);
    DemoAccounts.seed(db);
    return _db = db;
  }

  /// Forget everything the presenters did (the sample data starts again).
  Future<void> reset() async {
    await _storage.write({});
    _db = null;
  }

  /// The signed-in person for a bearer token.
  Principal? principalFor(String? token) =>
      DemoAccounts.principalOf(_database, DemoAccounts.userIdOfToken(token));

  /// Answer one API call. [rawPath] is the path after /api/v1, with any query string.
  Future<dynamic> handle(String method, String rawPath, {Object? body, String? token}) async {
    final db = _database;
    if (seedSampleClaims && db.data['sample_claims_v1'] != true) {
      db.data['sample_claims_v1'] = true; // first, so the calls below cannot start it again
      await DemoSeedClaims.run((m, p, {body, token}) => _dispatch(m, p, body, token));
    }
    final result = await _dispatch(method, rawPath, body, token);
    await _storage.write(db.data);
    return result;
  }

  Future<dynamic> _dispatch(String method, String rawPath, Object? body, String? token) async {
    final uri = Uri.parse(rawPath);
    final path = uri.path;
    final db = _database;
    try {
      final found = _router.match(method, path);
      if (found != null) {
        return await found.handler(DemoRequest(
          method: method,
          path: path,
          params: found.params,
          query: uri.queryParametersAll,
          body: body,
          db: db,
          principal: DemoAccounts.principalOf(db, DemoAccounts.userIdOfToken(token)),
        ));
      }
      if (method == 'GET' && _emptyLists.any((re) => re.hasMatch(path))) {
        // lists the dashboard asks for on every start that this demo has nothing in
        return <dynamic>[];
      }
      throw DemoError(404, 'NOT_FOUND', 'demo.not_available');
    } on DemoError catch (e) {
      throw ApiException(
        statusCode: e.status,
        error: e.error,
        messageKey: e.messageKey,
        rule: e.rule,
        details: e.details,
      );
    }
  }

  static final List<RegExp> _emptyLists = [
    RegExp(r'^/notifications'),
  ];
}
