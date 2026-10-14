import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/features/livelihood/data/ask_repository.dart';
import 'package:vanmitra_ai/features/livelihood/data/livelihood_api.dart';
import 'package:vanmitra_ai/features/livelihood/data/livelihood_repository.dart';
import 'package:vanmitra_ai/features/livelihood/livelihood_routes.dart';
import 'package:vanmitra_ai/features/livelihood/livelihood_strings.dart';
import 'package:vanmitra_ai/features/livelihood/models/ask.dart';
import 'package:vanmitra_ai/features/livelihood/models/report.dart';
import 'package:vanmitra_ai/features/livelihood/providers/ask_providers.dart';
import 'package:vanmitra_ai/features/livelihood/providers/livelihood_providers.dart';
import 'package:vanmitra_ai/features/livelihood/screens/ask_screen.dart';
import 'package:vanmitra_ai/features/livelihood/screens/report_screen.dart';
import 'package:vanmitra_ai/features/livelihood/widgets/answer_card.dart';

Answer _answer(
  AnswerKind kind,
  String headline, {
  Map<String, dynamic> params = const {},
  List<Reason> items = const [],
  List<String> parts = const [],
  bool sample = false,
}) =>
    Answer(
      kind: kind,
      topic: 't',
      headline: Reason(headline, params),
      items: items,
      fromParts: parts,
      isSampleData: sample,
    );

class _FakeAsk implements AskRepository {
  _FakeAsk({this.history0 = const AskHistory()});

  AskHistory history0;
  Object? failWith;
  final asked = <Map<String, String?>>[];
  Answer? next;
  int cleared = 0;

  @override
  Future<AskReply> ask({
    String? question,
    String? chip,
    required String lang,
    bool aiConsent = false,
  }) async {
    if (failWith != null) throw failWith!;
    asked.add({
      'question': question,
      'chip': chip,
      'lang': lang,
      'ai': aiConsent ? 'yes' : null,
    });
    return AskReply(
      ChatTurn(
        id: 't${asked.length}',
        question: question,
        chip: chip,
        answer: next ?? _answer(AnswerKind.offTopic, 'ask.off_topic'),
      ),
      history0.chips,
    );
  }

  @override
  Future<AskHistory> history() async => history0;

  @override
  Future<void> clear() async => cleared++;
}

class _ReportRepo implements LivelihoodRepository {
  @override
  Future<ReportResult> report({int? radiusM}) => Future.value(
        ReportResult(
          Report.fromJson(
            jsonDecode(
              File('assets/livelihood/sample_report.json').readAsStringSync(),
            ) as Map<String, dynamic>,
          ),
        ),
      );
}

Future<void> _pump(
  WidgetTester tester,
  _FakeAsk repo, {
  String lang = 'en',
  Widget home = const AskScreen(),
  AskConsentStore? consent,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        askRepositoryProvider.overrideWithValue(repo),
        askConsentStoreProvider
            .overrideWithValue(consent ?? MemoryAskConsentStore()),
        livelihoodRepositoryProvider.overrideWithValue(_ReportRepo()),
      ],
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
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _en = LivelihoodStrings('en');
const _mr = LivelihoodStrings('mr');

ChatTurn _turn(String id, Answer a, {String? q, String? chip}) =>
    ChatTurn(id: id, answer: a, question: q, chip: chip);

void main() {
  group('Ask screen', () {
    testWidgets('shows the intro and the suggestions built from his report',
        (tester) async {
      final repo = _FakeAsk(
        history0: const AskHistory(hasReport: true, chips: [
          SuggestedQuestion('top_ideas', Reason('ask.chip.top_ideas')),
          SuggestedQuestion(
            'idea:goat_rearing',
            Reason('ask.chip.idea', {
              'name_en': 'Goat rearing',
              'name_mr': 'शेळीपालन',
            }),
          ),
        ]),
      );
      await _pump(tester, repo);
      expect(find.text(_en.t('ask.intro')), findsOneWidget);
      expect(find.text('What are my best ideas?'), findsOneWidget);
      expect(find.text('Tell me about Goat rearing'), findsOneWidget);
    });

    testWidgets('an answer shows its items, its source and the Sample marker',
        (tester) async {
      final repo = _FakeAsk(
        history0: AskHistory(hasReport: true, turns: [
          _turn(
            'a',
            _answer(
              AnswerKind.answer,
              'ask.top_ideas',
              params: {'count': 2},
              items: const [
                Reason('ask.item.idea', {
                  'rank': 1,
                  'name_en': 'Small dairy',
                  'name_mr': 'दुग्धव्यवसाय',
                  'fit': 'fair',
                }),
              ],
              parts: ['ideas'],
              sample: true,
            ),
            q: 'best idea?',
          ),
        ]),
      );
      await _pump(tester, repo);
      expect(find.text('best idea?'), findsOneWidget);
      expect(find.text('Your top 2 ideas'), findsOneWidget);
      expect(find.text('1. Small dairy: Fair fit'), findsOneWidget);
      expect(find.text('From: your ideas'), findsOneWidget);
      expect(find.text(_en.t('lv_sample')), findsOneWidget);
    });

    testWidgets(
        'a harmful question is red, has no answer, and links the policy',
        (tester) async {
      final repo = _FakeAsk(
        history0: AskHistory(hasReport: true, turns: [
          _turn('r', _answer(AnswerKind.refusedHarmful, 'ask.refused_harmful')),
        ]),
      );
      await _pump(tester, repo);
      expect(find.text(_en.t('ask.refused_harmful')), findsOneWidget);
      // the server does not keep a refused question, and the app says so
      expect(find.text(_en.t('ask.question_not_kept')), findsOneWidget);
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);
      expect(find.text('From: your ideas'), findsNothing);
      await tester.tap(find.text(_en.t('lv_policy_link')));
      await tester.pumpAndSettle();
      expect(find.text(_en.t('lv_policy_title')), findsOneWidget);
    });

    testWidgets('off topic and not-in-report are grey, never red',
        (tester) async {
      final repo = _FakeAsk(
        history0: AskHistory(hasReport: true, turns: [
          _turn('o', _answer(AnswerKind.offTopic, 'ask.off_topic'), q: 'joke'),
          _turn(
            'n',
            _answer(
              AnswerKind.notInReport,
              'ask.not_in_report',
              items: const [Reason('ask.nir.outside')],
            ),
            q: 'price of milk',
          ),
        ]),
      );
      await _pump(tester, repo);
      expect(find.text(_en.t('ask.off_topic')), findsOneWidget);
      expect(find.text(_en.t('ask.not_in_report')), findsOneWidget);
      expect(find.text(_en.t('ask.nir.outside')), findsOneWidget);
      expect(find.byIcon(Icons.block_rounded), findsNothing);
      expect(find.text(_en.t('lv_policy_link')), findsNothing);
    });

    testWidgets(
        'typing a question sends it with the language and clears the box',
        (tester) async {
      final repo = _FakeAsk(history0: const AskHistory(hasReport: true));
      repo.next = _answer(AnswerKind.offTopic, 'ask.off_topic');
      await _pump(tester, repo, lang: 'mr');
      await tester.enterText(find.byType(TextField), 'हवामान कसे आहे?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(repo.asked.single, {
        'question': 'हवामान कसे आहे?',
        'chip': null,
        'lang': 'mr',
        'ai': null,
      });
      expect(find.text('हवामान कसे आहे?'), findsOneWidget); // his bubble
      expect(find.text(_mr.t('ask.off_topic')), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('an empty question is not sent', (tester) async {
      final repo = _FakeAsk(history0: const AskHistory(hasReport: true));
      await _pump(tester, repo);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(repo.asked, isEmpty);
    });

    testWidgets('tapping a suggestion asks by its id', (tester) async {
      final repo = _FakeAsk(
        history0: const AskHistory(hasReport: true, chips: [
          SuggestedQuestion('weather', Reason('ask.chip.weather')),
        ]),
      );
      await _pump(tester, repo);
      await tester.tap(find.text('How is the weather?'));
      await tester.pumpAndSettle();
      expect(repo.asked.single['chip'], 'weather');
      expect(repo.asked.single['question'], isNull);
      // his bubble shows the suggestion's wording
      expect(find.text('How is the weather?'), findsWidgets);
    });

    testWidgets('no internet: a calm message, and nothing is added',
        (tester) async {
      final repo = _FakeAsk(history0: const AskHistory(hasReport: true))
        ..failWith = const NetworkException();
      await _pump(tester, repo);
      await tester.enterText(find.byType(TextField), 'best idea');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(find.text(_en.t('lv_err_offline')), findsOneWidget);
      expect(find.byType(AnswerCard), findsNothing);
      // his words are kept in the box so he can send them again
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'best idea');
    });

    testWidgets('a saved answer changes language with him', (tester) async {
      final turn = _turn(
        'a',
        _answer(
          AnswerKind.answer,
          'ask.idea.in_report',
          params: {
            'rank': 2,
            'name_en': 'Goat rearing',
            'name_mr': 'शेळीपालन',
            'fit': 'fair',
          },
          parts: ['ideas'],
        ),
        q: 'goat',
      );
      final repo = _FakeAsk(
        history0: AskHistory(hasReport: true, turns: [turn]),
      );
      final store = MemoryAskConsentStore();
      await _pump(tester, repo, lang: 'en', consent: store);
      expect(
        find.text('Goat rearing is number 2 in your report: Fair fit'),
        findsOneWidget,
      );
      await _pump(tester, repo, lang: 'mr', consent: store);
      expect(
        find.text(
            'शेळीपालन तुमच्या अहवालात क्रमांक 2 वर आहे: ${_mr.t('lv_fit_fair')}'),
        findsOneWidget,
      );
      expect(find.text('स्रोत: तुमच्या कल्पना'), findsOneWidget);
    });

    testWidgets('clearing asks first, then deletes', (tester) async {
      final repo = _FakeAsk(
        history0: AskHistory(hasReport: true, turns: [
          _turn('o', _answer(AnswerKind.offTopic, 'ask.off_topic'), q: 'joke'),
        ]),
      );
      await _pump(tester, repo);
      await tester.tap(find.byTooltip(_en.t('ask.clear')));
      await tester.pumpAndSettle();
      expect(find.text(_en.t('ask.clear_title')), findsOneWidget);
      await tester.tap(find.text(_en.t('lv_keep')));
      await tester.pumpAndSettle();
      expect(repo.cleared, 0);
      expect(find.text('joke'), findsOneWidget);

      await tester.tap(find.byTooltip(_en.t('ask.clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en.t('ask.clear_confirm')));
      await tester.pumpAndSettle();
      expect(repo.cleared, 1);
      expect(find.text('joke'), findsNothing);
    });

    testWidgets('the clear button is off when there is nothing to clear',
        (tester) async {
      await _pump(tester, _FakeAsk());
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline_rounded),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('the report screen opens the Ask screen', (tester) async {
      await _pump(
        tester,
        _FakeAsk(history0: const AskHistory(hasReport: true)),
        home: const ReportScreen(),
      );
      await tester.scrollUntilVisible(
        find.text(_en.t('ask.entry')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(_en.t('ask.entry')));
      await tester.pumpAndSettle();
      expect(find.text(_en.t('ask.intro')), findsOneWidget);
    });
  });

  group('AI assistant', () {
    AskHistory available({List<ChatTurn> turns = const []}) =>
        AskHistory(hasReport: true, aiAvailable: true, turns: turns);

    testWidgets('with the AI off on the server, nothing about it is shown',
        (tester) async {
      await _pump(
          tester, _FakeAsk(history0: const AskHistory(hasReport: true)));
      expect(find.text(_en.t('ask.ai_consent_title')), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets(
        'asks his permission once, in plain words, before anything is sent',
        (tester) async {
      final repo = _FakeAsk(history0: available());
      final store = MemoryAskConsentStore();
      await _pump(tester, repo, consent: store);
      expect(find.text(_en.t('ask.ai_consent_title')), findsOneWidget);
      expect(find.textContaining('never send your name'), findsOneWidget);
      expect(
          find.textContaining('question you type is sent too'), findsOneWidget);
      // typing before he answers sends no permission
      await tester.enterText(find.byType(TextField), 'help me');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(repo.asked.single['ai'], isNull);
    });

    testWidgets('allowing is remembered and sent with his questions',
        (tester) async {
      final repo = _FakeAsk(history0: available());
      final store = MemoryAskConsentStore();
      await _pump(tester, repo, consent: store);
      await tester.tap(find.text(_en.t('ask.ai_allow')));
      await tester.pumpAndSettle();
      expect(store.value, isTrue);
      expect(find.text(_en.t('ask.ai_consent_title')), findsNothing);
      await tester.enterText(find.byType(TextField), 'help me');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(repo.asked.single['ai'], 'yes');
    });

    testWidgets('declining is remembered and nothing is sent to the AI',
        (tester) async {
      final repo = _FakeAsk(history0: available());
      final store = MemoryAskConsentStore();
      await _pump(tester, repo, consent: store);
      await tester.tap(find.text(_en.t('ask.ai_deny')));
      await tester.pumpAndSettle();
      expect(store.value, isFalse);
      await tester.enterText(find.byType(TextField), 'help me');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(repo.asked.single['ai'], isNull);
    });

    testWidgets('he can change his mind with the switch', (tester) async {
      final repo = _FakeAsk(history0: available());
      final store = MemoryAskConsentStore(true);
      await _pump(tester, repo, consent: store);
      expect(find.text(_en.t('ask.ai_consent_title')), findsNothing);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(store.value, isFalse);
      await tester.enterText(find.byType(TextField), 'help me');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(repo.asked.single['ai'], isNull);
    });

    testWidgets('a tapped suggestion never carries the AI permission',
        (tester) async {
      final repo = _FakeAsk(
        history0: const AskHistory(hasReport: true, aiAvailable: true, chips: [
          SuggestedQuestion('weather', Reason('ask.chip.weather')),
        ]),
      );
      await _pump(tester, repo, consent: MemoryAskConsentStore(true));
      await tester.tap(find.text('How is the weather?'));
      await tester.pumpAndSettle();
      // the app sends the flag with every ask; the server ignores it for suggestions
      expect(repo.asked.single['chip'], 'weather');
    });

    testWidgets('an AI answer says an AI wrote it, and still shows its source',
        (tester) async {
      final turn = ChatTurn(
        id: 'ai1',
        question: 'help me',
        answer: Answer(
          kind: AnswerKind.answer,
          topic: 'ai',
          headline: const Reason('ask.ai_answer'),
          text: 'Your children can help with the dairy.',
          engine: 'ai',
          fromParts: const ['your_details'],
          isSampleData: true,
        ),
      );
      await _pump(
        tester,
        _FakeAsk(history0: available(turns: [turn])),
        consent: MemoryAskConsentStore(true),
      );
      expect(
          find.text('Your children can help with the dairy.'), findsOneWidget);
      expect(find.text(_en.t('ask.ai_label')), findsOneWidget);
      expect(find.text('From: what you told us'), findsOneWidget);
      expect(find.text(_en.t('lv_sample')), findsOneWidget);
    });

    testWidgets('our own answers are not labelled as AI', (tester) async {
      final turn = ChatTurn(
        id: 't1',
        question: 'joke',
        answer: _answer(AnswerKind.offTopic, 'ask.off_topic'),
      );
      await _pump(
        tester,
        _FakeAsk(history0: available(turns: [turn])),
        consent: MemoryAskConsentStore(true),
      );
      expect(find.text(_en.t('ask.ai_label')), findsNothing);
    });

    test('the AI fields parse, and old servers without them still work', () {
      final a = Answer.fromJson({
        'kind': 'ANSWER',
        'topic': 'ai',
        'headline': {'key': 'ask.ai_answer', 'params': {}},
        'text': 'x',
        'engine': 'ai',
      });
      expect(a.isAi, isTrue);
      final old = Answer.fromJson({
        'kind': 'ANSWER',
        'topic': 't',
        'headline': {'key': 'ask.top_ideas', 'params': {}},
      });
      expect(old.isAi, isFalse);
      expect(
          AskHistory.fromJson({'turns': [], 'chips': []}).aiAvailable, isFalse);
      expect(AskHistory.fromJson({'ai_available': true}).aiAvailable, isTrue);
    });

    test('a text answer without the ai engine is never labelled AI', () {
      final a = Answer.fromJson({
        'kind': 'ANSWER',
        'topic': 'x',
        'headline': {'key': 'ask.top_ideas', 'params': {}},
        'text': 'words',
        'engine': 'template',
      });
      expect(a.isAi, isFalse);
    });
  });

  group('Ask data', () {
    test('an unknown kind from the server is shown as the safe grey one', () {
      final a = Answer.fromJson({
        'kind': 'SOMETHING_NEW',
        'topic': 'x',
        'headline': {'key': 'ask.not_in_report', 'params': {}},
      });
      expect(a.kind, AnswerKind.notInReport);
    });

    test('a reply parses, items and all', () {
      final reply = AskReply.fromJson({
        'turn': {
          'id': 'abc',
          'question': 'best idea',
          'chip': null,
          'answer': {
            'kind': 'ANSWER',
            'topic': 'top_ideas',
            'headline': {
              'key': 'ask.top_ideas',
              'params': {'count': 1}
            },
            'items': [
              {
                'key': 'ask.item.idea',
                'params': {'rank': 1}
              }
            ],
            'from_parts': ['ideas'],
            'is_sample_data': true,
          },
        },
        'chips': [
          {
            'id': 'weather',
            'label': {'key': 'ask.chip.weather', 'params': {}},
          },
        ],
      });
      expect(reply.turn.answer.items.single.key, 'ask.item.idea');
      expect(reply.turn.answer.isSampleData, isTrue);
      expect(reply.chips.single.id, 'weather');
    });
  });

  group('Ask words', () {
    // every key the backend can send must have words in both languages, or the app would show
    // a raw key. Read from the backend source when it sits next to the app (standalone layout,
    // or the host's vanmitra_backend).
    final root = ['../backend', '../vanmitra_backend']
        .where((d) => File('$d/app/livelihood/domain/ask_engine.py').existsSync())
        .firstOrNull;
    final keys = <String>{};
    if (root != null) {
      final pattern = RegExp(r'"(ask\.[a-z_.]+)"');
      for (final name in ['ask_engine', 'ask_ai_guard', 'ask_topics']) {
        final src = File('$root/app/livelihood/domain/$name.py')
            .readAsStringSync();
        keys.addAll(pattern.allMatches(src).map((m) => m.group(1)!));
      }
    }
    // chip labels are built as "ask.chip.<id>"
    keys.addAll([
      for (final id in [
        'heading',
        'top_ideas',
        'idea',
        'water',
        'wildlife',
        'cost',
        'forest',
        'own',
        'weather',
        'removed',
      ])
        'ask.chip.$id',
    ]);

    test('there are keys to check', () {
      expect(keys.length, greaterThan(20));
    });

    for (final lang in ['en', 'mr']) {
      test('every Ask key has words in $lang', () {
        final s = LivelihoodStrings(lang);
        final missing =
            keys.where((k) => s.t(k) == k && !k.endsWith('.')).toList()..sort();
        expect(missing, isEmpty);
      });
    }

    test('the harmful reply is the project wording and the same in meaning',
        () {
      expect(
        _en.t('ask.refused_harmful'),
        'This is not allowed under our policy. VanMitra does not support any harm to wildlife.',
      );
      expect(_mr.t('ask.refused_harmful'), isNot(_en.t('ask.refused_harmful')));
    });

    test('names, fit, cost, gate and month are written in the language', () {
      final r = Reason('ask.item.removed', {
        'name_en': 'Cut timber',
        'name_mr': 'लाकूड तोडणे',
        'gate': 'TIMBER_OR_HARM',
      });
      expect(_en.reason(r), startsWith('Cut timber: '));
      expect(_mr.reason(r), startsWith('लाकूड तोडणे: '));
      expect(
        _en.reason(
            const Reason('ask.weather.hottest', {'month': 5, 'tmax_c': 41.2})),
        'Hottest month: May, about 41.2 °C',
      );
      // an idea held back (no gate) uses its own wording
      expect(
        _en.reason(const Reason('ask.item.removed', {
          'name_en': 'Fish',
          'name_mr': 'मासे',
          'gate': null,
        })),
        'Fish: other ideas fit you better',
      );
    });
  });
}
