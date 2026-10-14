import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanmitra_ai/core/api/api_client.dart';
import 'package:vanmitra_ai/features/livelihood/data/error_mapping.dart';
import 'package:vanmitra_ai/features/livelihood/data/livelihood_api.dart';
import 'package:vanmitra_ai/features/livelihood/data/livelihood_cache.dart';
import 'package:vanmitra_ai/features/livelihood/data/livelihood_repository.dart';
import 'package:vanmitra_ai/features/livelihood/data/profile_repository.dart';
import 'package:vanmitra_ai/features/livelihood/livelihood_routes.dart';
import 'package:vanmitra_ai/features/livelihood/models/profile.dart';
import 'package:vanmitra_ai/features/livelihood/models/report.dart';
import 'package:vanmitra_ai/features/livelihood/providers/livelihood_providers.dart';
import 'package:vanmitra_ai/features/livelihood/providers/profile_providers.dart';
import 'package:vanmitra_ai/features/livelihood/screens/livelihood_home_screen.dart';
import 'package:vanmitra_ai/features/livelihood/screens/report_screen.dart';

String _sampleJson() =>
    File('assets/livelihood/sample_report.json').readAsStringSync();

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      // no charset on purpose: the client must still read Marathi as UTF-8 (the host's care)
      headers: {'content-type': 'application/json'},
    );

http.Response _error(int status, String key, [String error = 'ERR']) =>
    _json({'error': error, 'message_key': key, 'details': {}}, status);

/// A fake server. `handler` answers; every request is recorded in `calls`.
class _Server {
  _Server(this.handler);

  http.Response Function(http.Request) handler;
  final List<http.Request> calls = [];

  /// The server as the feature sees it (a LivelihoodApi): the same answers a real client would
  /// give, without depending on how the client is built, so these tests run unchanged in the host.
  LivelihoodApi api() => _FakeApi(this);

  Iterable<String> get paths => calls.map((c) => '${c.method} ${c.url.path}');
}

class _FakeApi implements LivelihoodApi {
  _FakeApi(this._server);

  final _Server _server;

  Future<dynamic> _call(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    final request =
        http.Request(method, Uri.parse('http://host:8010/api/v1$path'));
    if (body != null) request.body = jsonEncode(body);
    _server.calls.add(request);
    final http.Response response;
    try {
      response = _server.handler(request);
    } on SocketException catch (e) {
      throw NetworkException(e); // what the adapter does for a lost connection
    }
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return text.isEmpty ? null : jsonDecode(text);
    }
    throw ApiException.fromJson(
      response.statusCode,
      jsonDecode(text) as Map<String, dynamic>,
    );
  }

  @override
  Future<dynamic> get(String path) => _call('GET', path, null);

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      _call('POST', path, body);

  @override
  Future<dynamic> put(String path, {Map<String, dynamic>? body}) =>
      _call('PUT', path, body);

  @override
  Future<dynamic> delete(String path) => _call('DELETE', path, null);
}

/// An ApiClient that does whatever the test says. A subclass works for the host's client and
/// the standalone one alike, so the adapter is tested the same way in both repos.
class _ScriptedClient extends ApiClient {
  _ScriptedClient(this.script);

  final Future<dynamic> Function() script;

  @override
  Future<dynamic> get(String path, {bool requireAuth = true}) => script();

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) =>
      script();

  @override
  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) =>
      script();

  @override
  Future<dynamic> delete(String path, {bool requireAuth = true}) => script();
}

http.Response _offline(http.Request _) =>
    throw const SocketException('no network');

const _profile = LivelihoodProfile(
  areaValue: 3,
  areaUnit: AreaUnit.acre,
  livestock: {'cow': 2},
  assets: {'well'},
);

Map<String, dynamic> _profileOut(LivelihoodProfile p) => {
      'profile': p.toJson(),
      'area_ha': p.areaHa,
      'village': {'id': 'v', 'name_mr': 'ओझर', 'name_en': 'Ozhar'},
      'created_at': '2026-10-14T00:00:00Z',
      'updated_at': '2026-10-14T00:00:00Z',
    };

void main() {
  group('HostApiAdapter', () {
    HostApiAdapter adapter(Future<dynamic> Function() script,
            [Duration? timeout]) =>
        HostApiAdapter(
          _ScriptedClient(script),
          timeout: timeout ?? const Duration(seconds: 5),
        );

    test('passes a good answer through unchanged', () async {
      final api = adapter(() async => {'ok': true});
      expect(await api.get('/x'), {'ok': true});
      expect(await api.post('/x', body: {'a': 1}), {'ok': true});
      expect(await api.put('/x', body: {'a': 1}), {'ok': true});
      expect(await api.delete('/x'), {'ok': true});
    });

    test('a server answer, even an error, is NOT hidden as offline', () async {
      final e = ApiException(statusCode: 422, error: 'E', messageKey: 'k');
      await expectLater(
        adapter(() async => throw e).post('/x'),
        throwsA(same(e)),
      );
    });

    test(
        'no network, a client error, a non-JSON reply and a timeout are all offline',
        () async {
      for (final failure in <Object>[
        const SocketException('down'),
        http.ClientException('reset'),
        const FormatException('<html>Sign in to Wi-Fi</html>'),
      ]) {
        await expectLater(
          adapter(() async => throw failure).get('/x'),
          throwsA(isA<NetworkException>()),
          reason: '$failure',
        );
      }
      final slow = adapter(
        () => Completer<dynamic>().future, // never answers
        const Duration(milliseconds: 20),
      );
      await expectLater(slow.get('/x'), throwsA(isA<NetworkException>()));
    });
  });

  group('errorMessageKey', () {
    ApiException api(int status, String key) =>
        ApiException(statusCode: status, error: 'E', messageKey: key);

    test('every known server key has plain words', () {
      expect(errorMessageKey(const NetworkException()), 'lv_err_offline');
      for (final k in [
        'auth.required',
        'auth.token_expired',
        'auth.token_invalid',
      ]) {
        expect(errorMessageKey(api(401, k)), 'lv_err_signin');
      }
      expect(
        errorMessageKey(api(403, 'livelihood.role_not_allowed')),
        'lv_err_role',
      );
      expect(
        errorMessageKey(api(422, 'livelihood.no_village')),
        'lv_err_no_village',
      );
      expect(
        errorMessageKey(api(503, 'livelihood.data_not_loaded')),
        'lv_err_data',
      );
      expect(
        errorMessageKey(api(422, 'livelihood.location_outside_maharashtra')),
        'lv_err_outside_mh',
      );
      expect(
        errorMessageKey(api(422, 'livelihood.radius_too_large')),
        'lv_err_radius',
      );
    });

    test('anything unknown gets a calm generic line, never a raw code', () {
      expect(errorMessageKey(api(500, 'error.server')), 'lv_err_server');
      expect(errorMessageKey(api(418, 'something.new')), 'lv_err_generic');
      expect(errorMessageKey(StateError('boom')), 'lv_err_generic');
    });
  });

  group('LivelihoodCache', () {
    test('a damaged entry is dropped, not shown', () async {
      final store = MemoryCacheStore();
      await store.write('profile', '{not json');
      final cache = LivelihoodCache(store);
      expect(await cache.readJson('profile'), isNull);
      expect(await store.read('profile'), isNull);
    });

    test(
      'clearPersonal removes his details and report but not a pending delete',
      () async {
        final cache = LivelihoodCache(MemoryCacheStore());
        await cache.writeJson(LivelihoodCache.profileKey, {'a': 1});
        await cache.writeJson(LivelihoodCache.reportKey, {'b': 2});
        await cache.setFlag(LivelihoodCache.profileDirtyKey, true);
        await cache.setFlag(LivelihoodCache.deletePendingKey, true);
        await cache.clearPersonal();
        expect(await cache.readJson(LivelihoodCache.profileKey), isNull);
        expect(await cache.readJson(LivelihoodCache.reportKey), isNull);
        expect(await cache.flag(LivelihoodCache.profileDirtyKey), isFalse);
        expect(
          await cache.flag(LivelihoodCache.deletePendingKey),
          isTrue,
        ); // the promise survives
      },
    );
  });

  group('RemoteLivelihoodRepository', () {
    late LivelihoodCache cache;
    setUp(() => cache = LivelihoodCache(MemoryCacheStore()));

    test('builds a report on the server and keeps it on the phone', () async {
      final s = _Server((_) => _json(jsonDecode(_sampleJson())));
      final repo = RemoteLivelihoodRepository(s.api(), cache);
      final r = await repo.report(radiusM: 3000);
      expect(r.fromCache, isFalse);
      expect(r.report.isSampleData, isTrue);
      expect(s.paths, ['POST /api/v1/livelihood/report']);
      expect(jsonDecode(s.calls.single.body), {'radius_m': 3000});
      expect(await cache.readJson(LivelihoodCache.reportKey), isNotNull);
    });

    test(
      'with no radius it sends an empty body (the server default is 5 km)',
      () async {
        final s = _Server((_) => _json(jsonDecode(_sampleJson())));
        await RemoteLivelihoodRepository(s.api(), cache).report();
        expect(jsonDecode(s.calls.single.body), isEmpty);
      },
    );

    test('offline, it shows the last saved report and says so', () async {
      final online = _Server((_) => _json(jsonDecode(_sampleJson())));
      await RemoteLivelihoodRepository(online.api(), cache).report();
      final r = await RemoteLivelihoodRepository(
        _Server(_offline).api(),
        cache,
      ).report();
      expect(r.fromCache, isTrue);
      expect(r.savedAt, isNotNull);
      expect(r.report.resources, isNotEmpty);
    });

    test(
      'offline with nothing saved is an honest error, not an empty report',
      () async {
        final repo = RemoteLivelihoodRepository(
          _Server(_offline).api(),
          cache,
        );
        await expectLater(repo.report(), throwsA(isA<NetworkException>()));
      },
    );

    test(
      'a server failure (5xx) also falls back to the saved report',
      () async {
        await RemoteLivelihoodRepository(
          _Server((_) => _json(jsonDecode(_sampleJson()))).api(),
          cache,
        ).report();
        final down = _Server((_) => _error(503, 'livelihood.data_not_loaded'));
        expect(
          (await RemoteLivelihoodRepository(
            down.api(),
            cache,
          ).report())
              .fromCache,
          isTrue,
        );
      },
    );

    test(
      'a refusal (4xx) is shown, never hidden behind an old report',
      () async {
        await RemoteLivelihoodRepository(
          _Server((_) => _json(jsonDecode(_sampleJson()))).api(),
          cache,
        ).report();
        for (final status in [401, 403, 422]) {
          final refuses = _Server((_) => _error(status, 'auth.required'));
          await expectLater(
            RemoteLivelihoodRepository(refuses.api(), cache).report(),
            throwsA(
              isA<ApiException>().having((e) => e.statusCode, 'status', status),
            ),
            reason: '$status',
          );
        }
      },
    );

    test(
      'an unreadable saved report is dropped and the real error is shown',
      () async {
        await cache.writeJson(LivelihoodCache.reportKey, {
          'saved_at': '2026-10-14T00:00:00Z',
          'report': {'nonsense': true},
        });
        final repo = RemoteLivelihoodRepository(
          _Server(_offline).api(),
          cache,
        );
        await expectLater(repo.report(), throwsA(isA<NetworkException>()));
        expect(await cache.readJson(LivelihoodCache.reportKey), isNull);
      },
    );
  });

  group('OfflineFirstProfileRepository', () {
    late LivelihoodCache cache;
    setUp(() => cache = LivelihoodCache(MemoryCacheStore()));

    OfflineFirstProfileRepository repoFor(_Server s) =>
        OfflineFirstProfileRepository(s.api(), cache);

    test('saves on the phone and on the server', () async {
      final s = _Server((_) => _json(_profileOut(_profile)));
      final repo = repoFor(s);
      await repo.save(_profile);
      expect(s.paths, ['PUT /api/v1/livelihood/profile']);
      expect(jsonDecode(s.calls.single.body), _profile.toJson());
      expect(repo.pendingSync, isFalse);
      expect(await cache.readJson(LivelihoodCache.profileKey), isNotNull);
      expect(await cache.flag(LivelihoodCache.profileDirtyKey), isFalse);
    });

    test(
      'offline, a save is kept on the phone and goes up on the next load',
      () async {
        final offline = _Server(_offline);
        final repo = repoFor(offline);
        await repo.save(_profile); // must not throw
        expect(repo.pendingSync, isTrue);
        expect(await cache.flag(LivelihoodCache.profileDirtyKey), isTrue);
        expect((await repo.load())!.livestock, {
          'cow': 2,
        }); // still offline: what he saved

        final online = _Server((req) => _json(_profileOut(_profile)));
        final later = repoFor(online);
        final loaded = await later.load();
        expect(online.paths, [
          'PUT /api/v1/livelihood/profile',
          'GET /api/v1/livelihood/profile',
        ]);
        expect(loaded!.livestock, {'cow': 2});
        expect(later.pendingSync, isFalse);
        expect(await cache.flag(LivelihoodCache.profileDirtyKey), isFalse);
      },
    );

    test(
        'a refusal is not kept: the old answers come back and the error is raised',
        () async {
      await cache.writeJson(
        LivelihoodCache.profileKey,
        const LivelihoodProfile(areaValue: 1).toJson(),
      );
      final s = _Server(
        (_) => _error(422, 'livelihood.location_outside_maharashtra'),
      );
      await expectLater(
        repoFor(s).save(_profile),
        throwsA(
          isA<ApiException>().having(
            (e) => e.messageKey,
            'key',
            'livelihood.location_outside_maharashtra',
          ),
        ),
      );
      expect((await cache.readJson(LivelihoodCache.profileKey))!['land'], {
        'area_value': 1.0,
        'area_unit': 'hectare',
      });
      expect(await cache.flag(LivelihoodCache.profileDirtyKey), isFalse);
    });

    test('a refused first save leaves nothing behind', () async {
      final s = _Server((_) => _error(422, 'livelihood.no_village'));
      await expectLater(
        repoFor(s).save(_profile),
        throwsA(isA<ApiException>()),
      );
      expect(await cache.readJson(LivelihoodCache.profileKey), isNull);
    });

    test('load: the server is the truth, and is copied to the phone', () async {
      final s = _Server((_) => _json(_profileOut(_profile)));
      final p = await repoFor(s).load();
      expect(p!.areaHa, closeTo(1.214, 1e-3));
      expect(await cache.readJson(LivelihoodCache.profileKey), isNotNull);
    });

    test('load: nothing on the server means nothing here either', () async {
      await cache.writeJson(LivelihoodCache.profileKey, _profile.toJson());
      final s = _Server(
        (_) => _error(404, 'livelihood.no_profile', 'NO_PROFILE'),
      );
      expect(await repoFor(s).load(), isNull);
      expect(await cache.readJson(LivelihoodCache.profileKey), isNull);
    });

    test('load offline returns what is on the phone', () async {
      await cache.writeJson(LivelihoodCache.profileKey, _profile.toJson());
      expect((await repoFor(_Server(_offline)).load())!.assets, {'well'});
      expect(await repoFor(_Server(_offline)).load(), isNotNull);
    });

    test('load with nothing anywhere is null', () async {
      expect(await repoFor(_Server(_offline)).load(), isNull);
    });

    test('delete: gone from the phone at once and from the server', () async {
      await cache.writeJson(LivelihoodCache.profileKey, _profile.toJson());
      await cache.writeJson(LivelihoodCache.reportKey, {'x': 1});
      final s = _Server((_) => http.Response('', 204));
      final repo = repoFor(s);
      await repo.delete();
      expect(s.paths, ['DELETE /api/v1/livelihood/profile']);
      expect(await cache.readJson(LivelihoodCache.profileKey), isNull);
      expect(await cache.readJson(LivelihoodCache.reportKey), isNull);
      expect(await cache.flag(LivelihoodCache.deletePendingKey), isFalse);
      expect(repo.pendingSync, isFalse);
    });

    test(
        'delete offline: gone locally now, and the server delete is retried until it works (L8)',
        () async {
      await cache.writeJson(LivelihoodCache.profileKey, _profile.toJson());
      final offline = repoFor(_Server(_offline));
      await offline.delete(); // must not throw
      expect(await cache.readJson(LivelihoodCache.profileKey), isNull);
      expect(await cache.flag(LivelihoodCache.deletePendingKey), isTrue);
      expect(offline.pendingSync, isTrue);

      // still offline on the next open: nothing shown, still pending
      expect(await offline.load(), isNull);
      expect(await cache.flag(LivelihoodCache.deletePendingKey), isTrue);

      // back online: the delete goes first, and the old answers are NOT fetched back
      final online = _Server(
        (req) => req.method == 'DELETE'
            ? http.Response('', 204)
            : _error(404, 'livelihood.no_profile'),
      );
      final later = repoFor(online);
      expect(await later.load(), isNull);
      expect(online.paths.first, 'DELETE /api/v1/livelihood/profile');
      expect(await cache.flag(LivelihoodCache.deletePendingKey), isFalse);
      expect(later.pendingSync, isFalse);
    });

    test('saving again cancels a delete that was waiting', () async {
      await cache.setFlag(LivelihoodCache.deletePendingKey, true);
      final s = _Server((_) => _json(_profileOut(_profile)));
      await repoFor(s).save(_profile);
      expect(await cache.flag(LivelihoodCache.deletePendingKey), isFalse);
    });
  });

  group('screens', () {
    Future<ProviderContainer> pump(
      WidgetTester tester,
      Widget screen, {
      required List<Override> overrides,
      String lang = 'en',
    }) async {
      tester.view.physicalSize = const Size(800, 16000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            locale: Locale(lang),
            theme: ThemeData(fontFamily: 'NotoSansDevanagari'),
            supportedLocales: const [Locale('en'), Locale('mr')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routes: livelihoodRoutes,
            home: screen,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
    }

    Report sample() =>
        Report.fromJson(jsonDecode(_sampleJson()) as Map<String, dynamic>);

    testWidgets('an offline report says it is the last saved one', (
      tester,
    ) async {
      await pump(
        tester,
        const ReportScreen(),
        overrides: [
          livelihoodRepositoryProvider.overrideWithValue(
            _FixedRepo(
              ReportResult(
                sample(),
                fromCache: true,
                savedAt: DateTime(2026, 10, 14),
              ),
            ),
          ),
        ],
      );
      expect(
        find.textContaining('Showing your last saved report'),
        findsOneWidget,
      );
      expect(find.textContaining('14-10-2026'), findsOneWidget);
    });

    testWidgets('a live report has no offline banner', (tester) async {
      await pump(
        tester,
        const ReportScreen(),
        overrides: [
          livelihoodRepositoryProvider.overrideWithValue(
            _FixedRepo(ReportResult(sample())),
          ),
        ],
      );
      expect(
        find.textContaining('Showing your last saved report'),
        findsNothing,
      );
    });

    testWidgets('failures are explained in plain words, with a retry', (
      tester,
    ) async {
      final cases = {
        const NetworkException():
            'No internet right now. Try again when you are online.',
        ApiException(
          statusCode: 401,
          error: 'E',
          messageKey: 'auth.token_expired',
        ): 'Please sign in again to see your report.',
        ApiException(
          statusCode: 503,
          error: 'E',
          messageKey: 'livelihood.data_not_loaded',
        ): 'The resource data is not ready yet. Please try again later.',
      };
      for (final entry in cases.entries) {
        await pump(
          tester,
          const ReportScreen(),
          overrides: [
            livelihoodRepositoryProvider.overrideWithValue(
              _FixedRepo.error(entry.key),
            ),
          ],
        );
        expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
        expect(find.text('Try again'), findsOneWidget);
        expect(find.textContaining('auth.'), findsNothing); // never a raw key
      }
    });

    testWidgets(
      'home says when details are saved on the phone but not sent yet',
      (tester) async {
        final repo = _PendingProfileRepo();
        final container = await pump(
          tester,
          const LivelihoodHomeScreen(),
          overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        );
        await container.read(profileProvider.notifier).save(_profile);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Saved on this phone. It will be sent when you are online.',
          ),
          findsOneWidget,
        );
        expect(container.read(syncPendingProvider), isTrue);
      },
    );

    testWidgets(
      'opening home loads his saved details without building a report',
      (tester) async {
        final repo = _CountingRepo();
        await pump(
          tester,
          const LivelihoodHomeScreen(),
          overrides: [
            livelihoodRepositoryProvider.overrideWithValue(repo),
            profileRepositoryProvider.overrideWithValue(
              _PendingProfileRepo(initial: _profile, pending: false),
            ),
          ],
        );
        expect(
          find.text('Your details are saved on this phone.'),
          findsOneWidget,
        );
        expect(
          repo.calls,
          0,
        ); // opening home must not create a report on the server
      },
    );
  });
}

class _FixedRepo implements LivelihoodRepository {
  _FixedRepo(ReportResult this.result) : error = null;
  _FixedRepo.error(Object this.error) : result = null;

  final ReportResult? result;
  final Object? error;

  @override
  Future<ReportResult> report({int? radiusM}) async {
    if (error != null) throw error!;
    return result!;
  }
}

class _CountingRepo implements LivelihoodRepository {
  int calls = 0;

  @override
  Future<ReportResult> report({int? radiusM}) async {
    calls++;
    throw const NetworkException();
  }
}

class _PendingProfileRepo implements ProfileRepository {
  _PendingProfileRepo({this.initial, this.pending = true});

  final LivelihoodProfile? initial;
  final bool pending;
  LivelihoodProfile? _saved;

  @override
  Future<LivelihoodProfile?> load() async => _saved ?? initial;

  @override
  Future<void> save(LivelihoodProfile profile) async => _saved = profile;

  @override
  Future<void> delete() async => _saved = null;

  @override
  bool get pendingSync => pending;
}
