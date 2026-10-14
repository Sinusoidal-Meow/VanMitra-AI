import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/features/livelihood/models/ask.dart';
import 'package:vanmitra_ai/features/livelihood/models/profile.dart';
import 'package:vanmitra_ai/features/livelihood/models/report.dart';
import 'package:vanmitra_ai/features/livelihood/models/scheme.dart';

import 'demo_support.dart';

void main() {
  late DemoHarness h;
  late String token;
  setUp(() async {
    h = DemoHarness();
    token = await h.login('9000000001');
  });
  tearDown(() => h.dispose());

  Future<dynamic> get(String path) => h.call('GET', '/livelihood$path', token: token);
  Future<dynamic> post(String path, Object body) =>
      h.call('POST', '/livelihood$path', token: token, body: body);

  group('Module 4 for the village user', () {
    test('the sample farmer is saved from the start and parses in the app', () async {
      final raw = await get('/profile') as Map<String, dynamic>;
      final profile = LivelihoodProfile.fromJson(raw['profile'] as Map<String, dynamic>);
      expect(profile.hasDetails, isTrue);
      expect(profile.lat, 19.7805);
      expect(profile.lng, 73.2210);
    });

    test('the report parses in the app, is Sample, plot level, with this user as its name',
        () async {
      final raw = await post('/report', {}) as Map<String, dynamic>;
      final report = Report.fromJson(raw);
      expect(raw['is_sample_data'], isTrue);
      expect(raw['header']['report_level'], 'plot');
      expect(raw['header']['name'], 'Demo Village User');
      expect(report.ideas, isNotEmpty);
      expect(report.resources, isNotEmpty);
      final latest = await get('/report/latest') as Map<String, dynamic>;
      expect(latest['id'], raw['id']);
    });

    test('no report is "latest" until one was made', () async {
      expect((await h.fails('GET', '/livelihood/report/latest', token: token)).statusCode, 404);
    });

    test('every idea of the report opens in full, an unknown one is a 404', () async {
      final raw = await post('/report', {}) as Map<String, dynamic>;
      for (final idea in raw['ideas'] as List) {
        final code = (idea as Map)['code'] as String;
        final detail = await get('/ideas/$code') as Map<String, dynamic>;
        expect(IdeaDetail.fromJson(detail), isNotNull);
      }
      expect((await h.fails('GET', '/livelihood/ideas/no_such_idea', token: token)).statusCode,
          404);
    });

    test('schemes parse, are all Sample, and the filters work', () async {
      final all = await get('/schemes') as Map<String, dynamic>;
      expect(SchemesResult.fromJson(all).schemes, isNotEmpty);
      expect(all['is_sample_data'], isTrue);
      final ngo = await get('/schemes?kind=ngo') as Map<String, dynamic>;
      expect((ngo['schemes'] as List).every((s) => (s as Map)['kind'] == 'ngo'), isTrue);
      expect((ngo['schemes'] as List).length, lessThan((all['schemes'] as List).length));
      final women = await get('/schemes?audience=women') as Map<String, dynamic>;
      expect(
          (women['schemes'] as List)
              .every((s) => ((s as Map)['audiences'] as List).contains('women')),
          isTrue);
    });

    test('a suggested question is answered, and the history keeps it', () async {
      await post('/report', {});
      final raw = await post('/ask', {'chip': 'water', 'lang': 'mr'}) as Map<String, dynamic>;
      final reply = AskReply.fromJson(raw);
      expect(reply.turn.answer.kind, AnswerKind.answer);
      expect((raw['turn'] as Map)['lang'], 'mr');
      final history = AskHistory.fromJson(await get('/ask/history') as Map<String, dynamic>);
      expect(history.turns, hasLength(1));
      expect(history.aiAvailable, isFalse);
      await h.call('DELETE', '/livelihood/ask/history', token: token);
      final empty = AskHistory.fromJson(await get('/ask/history') as Map<String, dynamic>);
      expect(empty.turns, isEmpty);
    });

    test('a typed question: matched, grey, or refused when it asks for harm', () async {
      Future<Answer> ask(String q) async => AskReply.fromJson(
              await post('/ask', {'question': q, 'lang': 'en'}) as Map<String, dynamic>)
          .turn
          .answer;

      expect((await ask('How much water is near my land?')).topic, 'water');
      expect((await ask('what is the capital of france')).kind, AnswerKind.offTopic);
      final harmful = await ask('how can I poison a leopard');
      expect(harmful.kind, AnswerKind.refusedHarmful);
      expect(harmful.items, isEmpty);
      final history = AskHistory.fromJson(await get('/ask/history') as Map<String, dynamic>);
      expect(history.turns.last.question, isNull); // a refused question is not kept
    });

    test('changing details is saved, and Delete my answers clears everything', () async {
      final raw = await get('/profile') as Map<String, dynamic>;
      final changed = Map<String, dynamic>.from(raw['profile'] as Map)..['family_workers'] = 5;
      await h.call('PUT', '/livelihood/profile', token: token, body: changed);
      final back = await get('/profile') as Map<String, dynamic>;
      expect((back['profile'] as Map)['family_workers'], 5);

      await post('/ask', {'chip': 'water', 'lang': 'en'});
      await h.call('DELETE', '/livelihood/profile', token: token);
      expect((await h.fails('GET', '/livelihood/profile', token: token)).statusCode, 404);
      // with no details the report is the village-level one
      final general = await post('/report', {}) as Map<String, dynamic>;
      expect(general['header']['report_level'], 'village');
      final history = AskHistory.fromJson(await get('/ask/history') as Map<String, dynamic>);
      expect(history.turns, isEmpty);
    });

    test('each person has their own details', () async {
      final other = await h.login('9000000002');
      await h.call('DELETE', '/livelihood/profile', token: token);
      final theirs = await h.call('GET', '/livelihood/profile', token: other) as Map;
      expect(theirs['profile'], isNotNull);
    });

    test('someone who registers starts with no details', () async {
      final t = await h.call('POST', '/auth/register', body: {
        'name': 'Meena',
        'phone': '9345678901',
        'pin': '123456',
        'village_id': '01a11846-11fc-7894-bcb3-597768083ceb',
      });
      final mine = t['access_token'] as String;
      expect((await h.fails('GET', '/livelihood/profile', token: mine)).statusCode, 404);
      final report = await h.call('POST', '/livelihood/report', token: mine, body: {});
      expect(report['header']['name'], 'Meena');
      expect(report['header']['report_level'], 'village');
    });

    test('only village users and the Gram Sabha may use it', () async {
      final sdo = await h.login('9000000005');
      final r = await h.fails('GET', '/livelihood/profile', token: sdo);
      expect(r.statusCode, 403);
      expect(r.messageKey, 'livelihood.role_not_allowed');
      expect((await h.fails('GET', '/livelihood/profile')).statusCode, 401);
      final gs = await h.login('9000000003');
      expect(await h.call('GET', '/livelihood/profile', token: gs), isNotNull);
    });
  });
}
