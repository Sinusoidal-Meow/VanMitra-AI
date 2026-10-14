import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/core/api/api_client.dart';
import 'package:vanmitra_ai/demo/demo_backend.dart';
import 'package:vanmitra_ai/demo/demo_mode.dart';
import 'package:vanmitra_ai/features/livelihood/models/ask.dart';
import 'package:vanmitra_ai/features/livelihood/models/profile.dart';
import 'package:vanmitra_ai/features/livelihood/models/report.dart';
import 'package:vanmitra_ai/features/livelihood/models/scheme.dart';

DemoBackend _backend() => DemoBackend(
      storage: MemoryDemoStorage(),
      loadAsset: (path) => File(path).readAsString(),
    );

Future<ApiException> _error(Future<dynamic> call) async {
  try {
    await call;
  } on ApiException catch (e) {
    return e;
  }
  throw StateError('expected an ApiException');
}

void main() {
  tearDown(() => DemoMode.idForTest = null);

  group('sign in', () {
    test("Samrudhi's build accepts her phone and PIN, and only hers", () async {
      DemoMode.idForTest = 'samrudhi';
      final b = _backend();
      final tokens = await b.handle('POST', '/auth/login',
          body: {'phone': '9100000001', 'pin': '123456'});
      expect(tokens['access_token'], isNotEmpty);
      expect((await _error(b.handle('POST', '/auth/login',
              body: {'phone': '9100000001', 'pin': '000000'})))
          .statusCode, 401);
      // another presenter's phone does not open this build
      expect((await _error(b.handle('POST', '/auth/login',
              body: {'phone': '9100000002', 'pin': '123456'})))
          .statusCode, 401);
      final me = await b.handle('GET', '/me');
      expect(me['name'], 'Samrudhi');
      expect(me['is_admin'], isFalse);
      expect((me['roles'] as List).single['role'], 'villager');
    });

    test('a build with every presenter signs in whoever logs in', () async {
      DemoMode.idForTest = 'all';
      final b = _backend();
      await b.handle('POST', '/auth/login', body: {'phone': '9100000003', 'pin': '123456'});
      expect((await b.handle('GET', '/me'))['name'], 'Ayush');
    });

    test('there is no sign-up in the demo', () async {
      DemoMode.idForTest = 'samrudhi';
      expect((await _error(_backend().handle('POST', '/auth/register', body: {}))).statusCode, 403);
    });

    test('the lists the dashboard asks for on start are empty, not errors', () async {
      DemoMode.idForTest = 'samrudhi';
      final b = _backend();
      expect(await b.handle('GET', '/cases/mine'), isEmpty);
      expect(await b.handle('GET', '/villages/abc/meetings'), isEmpty);
    });

    test('an unknown call is a plain 404, not a crash', () async {
      DemoMode.idForTest = 'samrudhi';
      expect((await _error(_backend().handle('GET', '/something/new'))).statusCode, 404);
    });
  });

  group('Module 4 for the sample farmer', () {
    late DemoBackend b;
    setUp(() {
      DemoMode.idForTest = 'samrudhi';
      b = _backend();
    });

    test('her details are saved from the start and parse in the app', () async {
      final raw = await b.handle('GET', '/livelihood/profile') as Map<String, dynamic>;
      final profile = LivelihoodProfile.fromJson(raw['profile'] as Map<String, dynamic>);
      expect(profile.hasDetails, isTrue);
      expect(profile.lat, 19.7805);
      expect(profile.lng, 73.2210);
    });

    test('the report parses in the app, is Sample and plot level', () async {
      final raw = await b.handle('POST', '/livelihood/report', body: {}) as Map<String, dynamic>;
      final report = Report.fromJson(raw);
      expect(raw['is_sample_data'], isTrue);
      expect(raw['header']['report_level'], 'plot');
      expect(report.ideas, isNotEmpty);
      expect(report.resources, isNotEmpty);
      final latest = await b.handle('GET', '/livelihood/report/latest') as Map<String, dynamic>;
      expect(latest['id'], raw['id']);
    });

    test('no report is "latest" until one was made', () async {
      expect((await _error(b.handle('GET', '/livelihood/report/latest'))).statusCode, 404);
    });

    test('every idea of the report opens in full, an unknown one is a 404', () async {
      final raw = await b.handle('POST', '/livelihood/report', body: {}) as Map<String, dynamic>;
      for (final idea in raw['ideas'] as List) {
        final code = (idea as Map)['code'] as String;
        final detail = await b.handle('GET', '/livelihood/ideas/$code') as Map<String, dynamic>;
        expect(IdeaDetail.fromJson(detail), isNotNull);
      }
      expect((await _error(b.handle('GET', '/livelihood/ideas/no_such_idea'))).statusCode, 404);
    });

    test('schemes parse, are all Sample, and the filters work', () async {
      final all = await b.handle('GET', '/livelihood/schemes') as Map<String, dynamic>;
      final result = SchemesResult.fromJson(all);
      expect(result.schemes, isNotEmpty);
      expect(all['is_sample_data'], isTrue);
      final ngo = await b.handle('GET', '/livelihood/schemes?kind=ngo') as Map<String, dynamic>;
      expect((ngo['schemes'] as List).every((s) => (s as Map)['kind'] == 'ngo'), isTrue);
      expect((ngo['schemes'] as List).length, lessThan((all['schemes'] as List).length));
      final women =
          await b.handle('GET', '/livelihood/schemes?audience=women') as Map<String, dynamic>;
      expect(
          (women['schemes'] as List)
              .every((s) => ((s as Map)['audiences'] as List).contains('women')),
          isTrue);
    });

    test('a suggested question is answered, and the history keeps it', () async {
      await b.handle('POST', '/livelihood/report', body: {});
      final raw = await b.handle('POST', '/livelihood/ask',
          body: {'chip': 'water', 'lang': 'mr'}) as Map<String, dynamic>;
      final reply = AskReply.fromJson(raw);
      expect(reply.turn.answer.kind, AnswerKind.answer);
      expect((raw['turn'] as Map)['lang'], 'mr');
      final history = AskHistory.fromJson(
          await b.handle('GET', '/livelihood/ask/history') as Map<String, dynamic>);
      expect(history.turns, hasLength(1));
      expect(history.aiAvailable, isFalse);
      await b.handle('DELETE', '/livelihood/ask/history');
      final empty = AskHistory.fromJson(
          await b.handle('GET', '/livelihood/ask/history') as Map<String, dynamic>);
      expect(empty.turns, isEmpty);
    });

    test('a typed question: matched, grey, or refused when it asks for harm', () async {
      Future<Answer> ask(String q) async => AskReply.fromJson(await b.handle(
              'POST', '/livelihood/ask', body: {'question': q, 'lang': 'en'})
          as Map<String, dynamic>).turn.answer;

      expect((await ask('How much water is near my land?')).topic, 'water');
      expect((await ask('what is the capital of france')).kind, AnswerKind.offTopic);
      final harmful = await ask('how can I poison a leopard');
      expect(harmful.kind, AnswerKind.refusedHarmful);
      expect(harmful.items, isEmpty);
      // a refused question is not kept
      final history = AskHistory.fromJson(
          await b.handle('GET', '/livelihood/ask/history') as Map<String, dynamic>);
      expect(history.turns.last.question, isNull);
    });

    test('changing details is saved, and Delete my answers clears everything', () async {
      final raw = await b.handle('GET', '/livelihood/profile') as Map<String, dynamic>;
      final changed = Map<String, dynamic>.from(raw['profile'] as Map)
        ..['family_workers'] = 5;
      await b.handle('PUT', '/livelihood/profile', body: changed);
      final back = await b.handle('GET', '/livelihood/profile') as Map<String, dynamic>;
      expect((back['profile'] as Map)['family_workers'], 5);

      await b.handle('POST', '/livelihood/ask', body: {'chip': 'water', 'lang': 'en'});
      await b.handle('DELETE', '/livelihood/profile');
      expect((await _error(b.handle('GET', '/livelihood/profile'))).statusCode, 404);
      // with no details the report is the village-level one
      final general =
          await b.handle('POST', '/livelihood/report', body: {}) as Map<String, dynamic>;
      expect(general['header']['report_level'], 'village');
      final history = AskHistory.fromJson(
          await b.handle('GET', '/livelihood/ask/history') as Map<String, dynamic>);
      expect(history.turns, isEmpty);
    });

    test('what he did survives the app closing (same storage, new backend)', () async {
      final storage = MemoryDemoStorage();
      Future<String> load(String path) => File(path).readAsString();
      final first = DemoBackend(storage: storage, loadAsset: load);
      await first.handle('POST', '/livelihood/ask', body: {'chip': 'water', 'lang': 'en'});
      final second = DemoBackend(storage: storage, loadAsset: load);
      final history = AskHistory.fromJson(
          await second.handle('GET', '/livelihood/ask/history') as Map<String, dynamic>);
      expect(history.turns, hasLength(1));
    });
  });
}
