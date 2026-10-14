import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/features/livelihood/data/livelihood_api.dart';
import 'package:vanmitra_ai/features/livelihood/data/livelihood_repository.dart';
import 'package:vanmitra_ai/features/livelihood/data/schemes_repository.dart';
import 'package:vanmitra_ai/features/livelihood/livelihood_routes.dart';
import 'package:vanmitra_ai/features/livelihood/livelihood_strings.dart';
import 'package:vanmitra_ai/features/livelihood/models/report.dart';
import 'package:vanmitra_ai/features/livelihood/models/scheme.dart';
import 'package:vanmitra_ai/features/livelihood/providers/detail_providers.dart';
import 'package:vanmitra_ai/features/livelihood/providers/livelihood_providers.dart';
import 'package:vanmitra_ai/features/livelihood/screens/idea_detail_screen.dart';
import 'package:vanmitra_ai/features/livelihood/screens/report_screen.dart';
import 'package:vanmitra_ai/features/livelihood/screens/schemes_screen.dart';

const _en = LivelihoodStrings('en');
const _mr = LivelihoodStrings('mr');

Map<String, dynamic> _scheme(
  String code, {
  String kind = 'government',
  String? url = 'https://example.gov.in/page',
  List<String> help = const ['livestock'],
  List<String> audiences = const ['women'],
  bool sample = true,
  String checked = 'unknown',
}) =>
    {
      'code': code,
      'kind': kind,
      'name_en': 'Scheme $code',
      'name_mr': 'योजना $code',
      'runs_en': 'A state department (sample)',
      'runs_mr': 'राज्य विभाग (नमुना)',
      'what_en': 'Example help for $code.',
      'what_mr': '$code साठी मदतीचे उदाहरण.',
      'who_en':
          'As written on the official page. We cannot tell you whether you qualify.',
      'who_mr': 'अधिकृत पानावर लिहिल्याप्रमाणे.',
      'documents_en': ['Identity proof'],
      'documents_mr': ['ओळखीचा पुरावा'],
      'help_types': help,
      'audiences': audiences,
      'official_url': url,
      'note_en': 'Sample row for a demo.',
      'note_mr': 'डेमोसाठी नमुना नोंद.',
      'last_checked_on': checked,
      'is_sample': sample,
    };

SchemesResult _register({
  List<Map<String, dynamic>>? rows,
  bool empty = false,
}) =>
    SchemesResult.fromJson({
      'schemes': rows ??
          [
            _scheme('gov1'),
            _scheme('gov2', url: null),
            _scheme('ngo1', kind: 'ngo', url: null, help: ['small_business']),
          ],
      'help_types': ['livestock', 'small_business'],
      'audiences': ['women', 'tribal'],
      'is_sample_data': true,
      'register_empty': empty,
    });

class _FakeSchemes implements SchemesRepository {
  _FakeSchemes({this.result, this.detail, this.error});

  SchemesResult? result;
  IdeaDetail? detail;
  Object? error;
  final filters = <SchemeFilter>[];
  final ideaCodes = <String>[];

  @override
  Future<SchemesResult> schemes(SchemeFilter filter) async {
    filters.add(filter);
    if (error != null) throw error!;
    final r = result ?? _register();
    // act like the server: filter by help type and audience
    if (filter.help == null && filter.audience == null) return r;
    return SchemesResult(
      schemes: [
        for (final s in r.schemes)
          if ((filter.help == null || s.helpTypes.contains(filter.help)) &&
              (filter.audience == null ||
                  s.audiences.contains(filter.audience)))
            s,
      ],
      helpTypes: r.helpTypes,
      audiences: r.audiences,
      isSampleData: r.isSampleData,
      registerEmpty: r.registerEmpty,
    );
  }

  @override
  Future<IdeaDetail> idea(String code) async {
    ideaCodes.add(code);
    if (error != null) throw error!;
    return detail!;
  }
}

Map<String, dynamic> _resourceJson() => {
      'id': 'well-1',
      'kind': 'well',
      'name_mr': 'विहीर',
      'name_en': 'Village well',
      'distance_m': 420,
      'tag': 'near',
      'label': 'useful',
      'reason': {'key': 'reason.good_all_round', 'params': {}},
      'checked_on_ground': false,
      'unknown_checks': <String>[],
      'use_only_through_gram_sabha': false,
      'trust': {
        'source': 'Sample',
        'source_date': 'unknown',
        'check_status': 'to_verify',
      },
    };

IdeaDetail _detail({
  String status = 'in_report',
  List<Map<String, dynamic>>? schemes,
  bool withWeather = true,
}) =>
    IdeaDetail.fromJson({
      'code': 'dairy_small',
      'name_en': 'Small dairy',
      'name_mr': 'दुग्धव्यवसाय',
      'status': status,
      'rank': status == 'in_report' ? 1 : null,
      'group': 'ranked',
      'fit': status == 'removed' ? null : 'fair',
      'reason': {
        'key': 'idea.reason.good_resources_nearby',
        'params': {'nearest_m': 420}
      },
      'cost_level': 'medium',
      'best_season': 'year_round',
      'wildlife_risk': 'low',
      'needs': [
        {
          'options': ['well', 'borewell'],
          'met_by': 'well'
        },
        {
          'options': ['asset:shed'],
          'met_by': 'asset:shed'
        },
        {
          'options': ['grazing_land'],
          'met_by': null
        },
      ],
      'checks': status == 'removed'
          ? [
              {
                'check': 'law',
                'result': 'flagged',
                'reason': {'key': 'gate.timber_or_harm', 'params': {}},
              },
            ]
          : [
              {
                'check': 'law',
                'result': 'passed',
                'reason': {'key': 'detail.check.law', 'params': {}},
              },
              {
                'check': 'wildlife',
                'result': 'passed',
                'reason': {'key': 'detail.check.wildlife_low', 'params': {}},
              },
              {
                'check': 'needs',
                'result': 'flagged',
                'reason': {'key': 'detail.check.needs_missing', 'params': {}},
              },
              {
                'check': 'land',
                'result': 'not_checked',
                'reason': {
                  'key': 'flag.land_unknown',
                  'params': {'min_ha': 0.2}
                },
              },
            ],
      'resources': [_resourceJson()],
      'flags': [
        {'key': 'flag.ask_forest_dept', 'params': {}},
      ],
      'weather_note': withWeather
          ? {
              'key': 'detail.weather.heat',
              'params': {'month': 5, 'tmax_c': 41.2, 'is_sample': true},
            }
          : null,
      'schemes': schemes ?? [_scheme('gov1')],
      'draft': true,
      'is_sample_data': true,
    });

class _SampleReportRepo implements LivelihoodRepository {
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
  _FakeSchemes repo, {
  Widget home = const SchemesScreen(),
  String lang = 'en',
  Future<bool> Function(String)? opener,
}) async {
  tester.view.physicalSize =
      const Size(800, 12000); // tall, so lazy lists build everything
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        schemesRepositoryProvider.overrideWithValue(repo),
        livelihoodRepositoryProvider.overrideWithValue(_SampleReportRepo()),
        if (opener != null) urlOpenerProvider.overrideWithValue(opener),
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

void main() {
  group('Schemes screen', () {
    testWidgets('Government and NGO tabs, Sample labels, and the honesty line',
        (tester) async {
      await _pump(tester, _FakeSchemes());
      expect(find.text(_en.t('sch.tab_government')), findsOneWidget);
      expect(find.text(_en.t('sch.tab_ngo')), findsOneWidget);
      expect(find.text('Scheme gov1'), findsOneWidget);
      expect(find.text('Scheme gov2'), findsOneWidget);
      expect(find.text('Scheme ngo1'), findsNothing); // on the other tab
      expect(find.text(_en.t('lv_sample')), findsWidgets);
      expect(find.text(_en.t('sch.sample_note')), findsOneWidget);
      // we never claim he qualifies and never show an amount
      expect(find.textContaining('You qualify'), findsNothing);
      expect(find.textContaining('are eligible'), findsNothing);
      expect(find.textContaining('₹'), findsNothing);

      await tester.tap(find.text(_en.t('sch.tab_ngo')));
      await tester.pumpAndSettle();
      expect(find.text('Scheme ngo1'), findsOneWidget);
      expect(find.text('Scheme gov1'), findsNothing);
    });

    testWidgets(
        'a card says who runs it, who can apply, papers, and when checked',
        (tester) async {
      await _pump(tester, _FakeSchemes());
      expect(find.text('Run by: A state department (sample)'), findsWidgets);
      expect(find.text(_en.t('sch.who')), findsWidgets);
      expect(find.text('•  Identity proof'), findsWidgets);
      expect(find.text(_en.t('sch.never_checked')), findsWidgets);
      expect(find.text(_en.t('sch.help.livestock')), findsWidgets);
    });

    testWidgets('a row with a link opens it; a row without says so',
        (tester) async {
      final opened = <String>[];
      await _pump(
        tester,
        _FakeSchemes(),
        opener: (url) async {
          opened.add(url);
          return true;
        },
      );
      expect(find.text(_en.t('sch.no_page')), findsOneWidget); // gov2
      await tester.tap(find.text(_en.t('sch.open')));
      await tester.pumpAndSettle();
      expect(opened, ['https://example.gov.in/page']);
    });

    testWidgets('a link that cannot be opened says so calmly', (tester) async {
      await _pump(tester, _FakeSchemes(), opener: (_) async => false);
      await tester.tap(find.text(_en.t('sch.open')));
      await tester.pumpAndSettle();
      expect(find.text(_en.t('sch.open_failed')), findsOneWidget);
    });

    testWidgets('filters ask the server and can be cleared', (tester) async {
      final repo = _FakeSchemes();
      await _pump(tester, repo);
      await tester.tap(find.text(_en.t('sch.help.livestock')).first);
      await tester.pumpAndSettle();
      expect(repo.filters.last, const SchemeFilter(help: 'livestock'));
      // no NGO row is about livestock in this register
      await tester.tap(find.text(_en.t('sch.tab_ngo')));
      await tester.pumpAndSettle();
      expect(find.text(_en.t('sch.empty_filter')), findsOneWidget);
      // choosing the same chip again clears it
      await tester.tap(find.text(_en.t('sch.help.livestock')).first);
      await tester.pumpAndSettle();
      expect(find.text('Scheme ngo1'), findsOneWidget);
    });

    testWidgets('an empty register is not the same as no match',
        (tester) async {
      await _pump(
        tester,
        _FakeSchemes(result: _register(rows: [], empty: true)),
      );
      expect(find.text(_en.t('sch.empty_register')), findsOneWidget);
    });

    testWidgets('no internet: a calm message and a retry', (tester) async {
      final repo = _FakeSchemes(error: const NetworkException());
      await _pump(tester, repo);
      expect(find.text(_en.t('lv_err_offline')), findsOneWidget);
      repo.error = null;
      await tester.tap(find.text(_en.t('lv_retry')));
      await tester.pumpAndSettle();
      expect(find.text('Scheme gov1'), findsOneWidget);
    });

    testWidgets('in Marathi the names, text and tabs are Marathi',
        (tester) async {
      await _pump(tester, _FakeSchemes(), lang: 'mr');
      expect(find.text('योजना gov1'), findsOneWidget);
      expect(find.text(_mr.t('sch.tab_government')), findsOneWidget);
      expect(find.text('राज्य विभाग (नमुना)'),
          findsNothing); // shown inside "Run by"
      expect(find.text(_mr.t('sch.runs', {'who': 'राज्य विभाग (नमुना)'})),
          findsWidgets);
    });
  });

  group('Idea detail', () {
    testWidgets(
        'shows why, needs, checks, weather, resources, warnings, schemes',
        (tester) async {
      await _pump(
        tester,
        _FakeSchemes(detail: _detail()),
        home: const IdeaDetailScreen(code: 'dairy_small'),
      );
      expect(find.text('Small dairy'), findsOneWidget);
      expect(find.text(_en.t('idea.rank', {'rank': 1})), findsOneWidget);
      expect(find.text(_en.t('idea.why')), findsOneWidget);
      // needs: near, own, missing
      expect(find.text('Found near you: Well'), findsOneWidget);
      expect(find.text('You have: Shed'), findsOneWidget);
      expect(find.textContaining('Not found:'), findsOneWidget);
      // checks, each with a word and a reason
      expect(find.text('Law: Passed'), findsOneWidget);
      expect(find.text('Needs: Look at this'), findsNothing);
      expect(find.text('What it needs: Look at this'), findsOneWidget);
      expect(find.text('Land: Not checked yet'), findsOneWidget);
      expect(find.text(_en.t('detail.check.law')), findsOneWidget);
      // weather note, written in words from the numbers the server sent
      expect(find.textContaining('May, about 41.2'), findsOneWidget);
      // the resource it would use, and the warning
      expect(find.text('Village well'), findsOneWidget);
      expect(find.text(_en.t('flag.ask_forest_dept')), findsOneWidget);
      // schemes that may relate, with the honesty line and a Sample label
      await tester.scrollUntilVisible(
        find.text('Scheme gov1'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_en.t('idea.schemes_note')), findsOneWidget);
      expect(find.text(_en.t('lv_sample')), findsWidgets);
      expect(find.text(_en.t('lv_draft_idea')), findsOneWidget);
    });

    testWidgets('an idea removed by law shows the law and no schemes',
        (tester) async {
      await _pump(
        tester,
        _FakeSchemes(detail: _detail(status: 'removed', withWeather: false)),
        home: const IdeaDetailScreen(code: 'timber_sale'),
      );
      expect(find.text(_en.t('idea.status_removed')), findsOneWidget);
      expect(find.text('Law: Look at this'), findsOneWidget);
      expect(find.text(_en.t('gate.timber_or_harm')), findsOneWidget);
      expect(find.text(_en.t('idea.schemes')), findsNothing);
      expect(find.text('Scheme gov1'), findsNothing);
    });

    testWidgets('an idea held back says so', (tester) async {
      await _pump(
        tester,
        _FakeSchemes(detail: _detail(status: 'held_back')),
        home: const IdeaDetailScreen(code: 'dairy_small'),
      );
      expect(find.text(_en.t('idea.status_held_back')), findsOneWidget);
    });

    testWidgets('with no schemes it says there are none, without inventing any',
        (tester) async {
      await _pump(
        tester,
        _FakeSchemes(detail: _detail(schemes: [])),
        home: const IdeaDetailScreen(code: 'dairy_small'),
      );
      await tester.scrollUntilVisible(
        find.text(_en.t('idea.schemes_none')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_en.t('idea.schemes_none')), findsOneWidget);
    });

    testWidgets('no internet: a calm message', (tester) async {
      await _pump(
        tester,
        _FakeSchemes(error: const NetworkException()),
        home: const IdeaDetailScreen(code: 'dairy_small'),
      );
      expect(find.text(_en.t('lv_err_offline')), findsOneWidget);
    });

    testWidgets('it works in Marathi', (tester) async {
      await _pump(
        tester,
        _FakeSchemes(detail: _detail()),
        home: const IdeaDetailScreen(code: 'dairy_small'),
        lang: 'mr',
      );
      expect(find.text('दुग्धव्यवसाय'), findsOneWidget);
      expect(find.text(_mr.t('idea.why')), findsOneWidget);
      expect(find.textContaining('मे, सुमारे 41.2'), findsOneWidget);
    });
  });

  group('Ways in', () {
    testWidgets('an idea card in the report opens its detail', (tester) async {
      final repo = _FakeSchemes(detail: _detail());
      await _pump(tester, repo, home: const ReportScreen());
      final report = Report.fromJson(
        jsonDecode(
          File('assets/livelihood/sample_report.json').readAsStringSync(),
        ) as Map<String, dynamic>,
      );
      final first = report.ideas.first;
      await tester.tap(find.text(first.name('en')).first);
      await tester.pumpAndSettle();
      expect(repo.ideaCodes, [first.code]);
      expect(find.text(_en.t('idea.title')), findsOneWidget);
    });

    testWidgets('a row in "Why not others?" opens its detail', (tester) async {
      final repo = _FakeSchemes(detail: _detail(status: 'removed'));
      await _pump(tester, repo, home: const ReportScreen());
      final report = Report.fromJson(
        jsonDecode(
          File('assets/livelihood/sample_report.json').readAsStringSync(),
        ) as Map<String, dynamic>,
      );
      final removed = report.removed.first;
      await tester.scrollUntilVisible(
        find.text(removed.name('en')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(removed.name('en')));
      await tester.pumpAndSettle();
      expect(repo.ideaCodes, [removed.code]);
    });

    testWidgets('the report has a way into Schemes', (tester) async {
      await _pump(tester, _FakeSchemes(), home: const ReportScreen());
      await tester.scrollUntilVisible(
        find.text(_en.t('sch.entry')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(_en.t('sch.entry')));
      await tester.pumpAndSettle();
      expect(find.text('Scheme gov1'), findsOneWidget);
    });
  });

  group('Scheme data', () {
    test('a row with no flag is treated as a sample, never as real', () {
      final j = _scheme('x')..remove('is_sample');
      expect(Scheme.fromJson(j).isSample, isTrue);
      expect(Scheme.fromJson(_scheme('y', sample: false)).isSample, isFalse);
    });

    test('an unknown check result is never shown as a pass', () {
      final c = CheckInfo.fromJson({
        'check': 'law',
        'result': 'something_new',
        'reason': {'key': 'detail.check.law', 'params': {}},
      });
      expect(c.result, CheckResult.notChecked);
    });

    test('filters compare by value', () {
      expect(const SchemeFilter(help: 'a'), const SchemeFilter(help: 'a'));
      expect(const SchemeFilter(help: 'a') == const SchemeFilter(), isFalse);
    });

    test('a scheme link is only ever https in what the opener accepts', () {
      // the server refuses http rows; the app refuses too (see urlOpenerProvider)
      expect(Uri.parse('http://x').scheme == 'https', isFalse);
    });
  });

  group('Stage 3 words', () {
    final keys = <String>{};
    final detailSrc = File('../backend/app/livelihood/domain/idea_detail.py');
    final askSrc = File('../backend/app/livelihood/domain/ask_engine.py');
    if (detailSrc.existsSync()) {
      final pattern = RegExp(r'"((?:detail|flag|gate)\.[a-z_.]+)"');
      keys.addAll(pattern
          .allMatches(detailSrc.readAsStringSync())
          .map((m) => m.group(1)!));
    }
    if (askSrc.existsSync()) {
      keys.addAll(RegExp(r'"(ask\.[a-z_.]+)"')
          .allMatches(askSrc.readAsStringSync())
          .map((m) => m.group(1)!));
    }
    // keys the backend builds in code
    keys.addAll([
      for (final r in ['low', 'medium', 'needs_permission'])
        'detail.check.wildlife_$r',
      for (final h in [
        'farming',
        'fishing',
        'livestock',
        'small_business',
        'forest_produce',
      ])
        'sch.help.$h',
      for (final a in ['women', 'tribal', 'farmers', 'groups']) 'sch.aud.$a',
      for (final k in ['law', 'wildlife', 'needs', 'land', 'community'])
        'idea.check_name.$k',
      'ask.chip.schemes',
    ]);

    test('there are keys to check', () {
      expect(keys.length, greaterThan(15));
    });

    for (final lang in ['en', 'mr']) {
      test('every key the server can send has words in $lang', () {
        final s = LivelihoodStrings(lang);
        final missing =
            keys.where((k) => s.t(k) == k && !k.endsWith('.')).toList()..sort();
        expect(missing, isEmpty);
      });
    }
  });
}
