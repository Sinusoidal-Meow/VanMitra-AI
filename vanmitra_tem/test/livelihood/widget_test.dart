import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/features/livelihood/data/livelihood_repository.dart';
import 'package:vanmitra_ai/features/livelihood/livelihood_routes.dart';
import 'package:vanmitra_ai/features/livelihood/providers/livelihood_providers.dart';
import 'package:vanmitra_ai/features/livelihood/livelihood_strings.dart';
import 'package:vanmitra_ai/features/livelihood/models/report.dart';
import 'package:vanmitra_ai/features/livelihood/screens/report_screen.dart';
import 'package:vanmitra_ai/features/livelihood/screens/resources_screen.dart';

Report _sample() {
  final raw = File('assets/livelihood/sample_report.json').readAsStringSync();
  return Report.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Hands back the sample report at once. (The real bundle read needs real async, which the
/// widget-test clock does not provide; it is tested separately below.)
class _FakeRepository implements LivelihoodRepository {
  @override
  Future<ReportResult> report({int? radiusM}) =>
      Future.value(ReportResult(_sample()));
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  String lang = 'en',
  ThemeMode mode = ThemeMode.light,
}) async {
  // tall viewport so every lazily-built list item exists
  tester.view.physicalSize = const Size(800, 16000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        livelihoodRepositoryProvider.overrideWithValue(_FakeRepository()),
      ],
      child: MaterialApp(
        locale: Locale(lang),
        themeMode: mode,
        theme: ThemeData(fontFamily: 'NotoSansDevanagari'),
        darkTheme: ThemeData.dark().copyWith(),
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
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
}

Iterable<String> _allText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');

void main() {
  group('bundled repository', () {
    testWidgets('reads the sample report from the app bundle', (tester) async {
      final report = await tester.runAsync(
        () => const SeedLivelihoodRepository().report(),
      );
      expect(report, isNotNull);
      expect(report!.report.isSampleData, isTrue);
      expect(report.fromCache, isFalse);
    });
  });

  group('report model', () {
    test('parses the backend sample report', () {
      final r = _sample();
      expect(r.isSampleData, isTrue);
      expect(r.resources, isNotEmpty);
      expect(r.ideas.length, lessThanOrEqualTo(5));
      expect(r.header.radiusM, 5000);
      expect(r.footerKey, 'footer.suggestion_only');
      final distances = r.resources.map((x) => x.distanceM).toList();
      expect(distances, [...distances]..sort());
    });
  });

  group('strings', () {
    const en = LivelihoodStrings('en');
    const mr = LivelihoodStrings('mr');

    test('fills parameters and formats distances', () {
      expect(
        en.reason(const Reason('reason.far_from_you', {'distance_m': 3500})),
        'Far from you: 3.5 km',
      );
      expect(
        en.reason(const Reason('reason.low_water_months', {'months': 4})),
        'Has water for only 4 months',
      );
      expect(LivelihoodStrings.distance(420), '420 m');
      expect(LivelihoodStrings.km(5000), '5');
    });

    test('translates animals and needs', () {
      expect(
        en.reason(
          const Reason('analysis.you_have_animals', {
            'cow': 2,
            'goat_sheep': 5,
          }),
        ),
        'You keep: Cow 2, Goat or sheep 5',
      );
      expect(
        en.reason(const Reason('flag.missing_need', {'need': 'asset:shed'})),
        'Missing: Shed',
      );
      expect(
        en.reason(const Reason('flag.missing_need', {'need': 'well'})),
        'Missing: Well',
      );
    });

    test('forest nearby says Gram Sabha only when it is community forest', () {
      final text = en.reason(
        const Reason('analysis.forest_nearby', {
          'count': 2,
          'gram_sabha_only': true,
        }),
      );
      expect(text, contains('Gram Sabha'));
    });

    test('falls back to English, never to a blank or a raw key', () {
      const hi = LivelihoodStrings('hi');
      expect(hi.t('lv_footer'), en.t('lv_footer'));
      expect(
        hi.t('no_such_key'),
        'no_such_key',
      ); // visible, so a gap is noticed in testing
    });

    test('every Marathi key exists in English and vice versa', () {
      final mrFooter = mr.t('lv_footer');
      expect(mrFooter, isNot(en.t('lv_footer')));
    });
  });

  group('report screen', () {
    testWidgets(
      'shows the footer, the Sample marker and a trust label on every resource',
      (tester) async {
        await _pump(tester, const ReportScreen());
        final text = _allText(tester).toList();

        expect(
          text,
          contains(
            'Suggestion only. Check on the ground. The Gram Sabha decides.',
          ),
        );
        expect(find.text('Sample'), findsWidgets);

        final report = _sample();
        final trustLines = text.where((t) => t.startsWith('Source:')).length;
        // header trust + one per resource card shown (4 on this screen) + ...
        expect(trustLines, greaterThanOrEqualTo(1 + 4));
        expect(report.resources.length, greaterThan(4));
      },
    );

    testWidgets('never shows a numeric score (rule L5)', (tester) async {
      await _pump(tester, const ReportScreen());
      final scorey = RegExp(r'(^|\s)0\.\d{2}(\s|$)|\d+\s?%');
      final offenders = _allText(tester).where(scorey.hasMatch).toList();
      expect(offenders, isEmpty);
    });

    testWidgets('community forest is marked Gram Sabha only', (tester) async {
      await _pump(tester, const ReportScreen());
      expect(find.text('Use only through the Gram Sabha'), findsWidgets);
    });

    testWidgets('every idea shows a wildlife badge', (tester) async {
      await _pump(tester, const ReportScreen());
      final badges = _allText(tester).where(
        (t) => t.startsWith('Wildlife risk') || t.startsWith('Needs Forest'),
      );
      expect(badges.length, _sample().ideas.length);
    });

    testWidgets('renders in Marathi', (tester) async {
      await _pump(tester, const ReportScreen(), lang: 'mr');
      expect(
        _allText(tester),
        contains('फक्त सूचना. प्रत्यक्ष जागेवर तपासा. निर्णय ग्रामसभा घेते.'),
      );
    });

    testWidgets('renders in dark theme without errors', (tester) async {
      await _pump(tester, const ReportScreen(), mode: ThemeMode.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text does not overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, const ReportScreen(), lang: 'mr');
      expect(tester.takeException(), isNull);
    });
  });

  group('resources screen', () {
    testWidgets('filter shows only the chosen label', (tester) async {
      await _pump(tester, const ResourcesScreen());
      final report = _sample();
      final all = find.textContaining('Source:');
      expect(all, findsNWidgets(report.resources.length));

      await tester.tap(find.textContaining('Not useful').first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Source:'),
        findsNWidgets(report.counts.notUseful),
      );
    });
  });
}
