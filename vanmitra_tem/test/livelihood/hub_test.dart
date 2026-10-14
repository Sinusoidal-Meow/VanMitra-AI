import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/features/livelihood/data/ask_repository.dart';
import 'package:vanmitra_ai/features/livelihood/data/profile_repository.dart';
import 'package:vanmitra_ai/features/livelihood/livelihood_routes.dart';
import 'package:vanmitra_ai/features/livelihood/providers/ask_providers.dart';
import 'package:vanmitra_ai/features/livelihood/providers/host_hooks.dart';
import 'package:vanmitra_ai/features/livelihood/providers/profile_providers.dart';
import 'package:vanmitra_ai/features/livelihood/screens/livelihood_home_screen.dart';

Future<void> _pumpHub(
  WidgetTester tester, {
  String lang = 'en',
  List<Override> extra = const [],
  Widget? nav,
}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(MemoryProfileRepository()),
        askRepositoryProvider.overrideWithValue(const OfflineAskRepository()),
        askConsentStoreProvider.overrideWithValue(MemoryAskConsentStore()),
        ...extra,
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
        home: LivelihoodHomeScreen(bottomNavigationBar: nav),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the hub offers Ask AI, the report, resources, schemes and policy',
      (tester) async {
    await _pumpHub(tester);
    expect(find.text('Add your details'), findsOneWidget);
    expect(find.text('Ask AI'), findsWidgets); // the card and the header button
    expect(find.text('Show my report'), findsOneWidget);
    expect(find.text('Resources near me'), findsOneWidget);
    expect(find.text('Government schemes'), findsOneWidget);
    expect(find.text('Wildlife policy'), findsOneWidget);
    // nothing to change or delete until details are saved
    expect(find.text('Change my details'), findsNothing);
    expect(find.text('Delete my answers'), findsNothing);
  });

  testWidgets('the Ask AI card opens the Ask screen', (tester) async {
    await _pumpHub(tester);
    final card = find.widgetWithText(InkWell, 'Ask AI').first;
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Ask about your report'), findsWidgets);
    expect(find.byType(LivelihoodHomeScreen), findsNothing);
  });

  testWidgets('the header Ask AI button opens the Ask screen', (tester) async {
    await _pumpHub(tester);
    await tester.tap(find.byTooltip('Ask AI'));
    await tester.pumpAndSettle();
    expect(find.text('Ask about your report'), findsWidgets);
    // the Ask screen does not offer a second Ask button to itself
    expect(find.byTooltip('Ask AI'), findsNothing);
  });

  testWidgets('the hub works in Marathi', (tester) async {
    await _pumpHub(tester, lang: 'mr');
    expect(find.text('AI ला विचारा'), findsWidgets);
    expect(find.text('सरकारी योजना'), findsOneWidget);
    expect(find.text('Ask AI'), findsNothing);
  });

  testWidgets('inside the host: its frame, its bottom bar and its hero are used',
      (tester) async {
    await _pumpHub(
      tester,
      nav: const Text('HOST-NAV'),
      extra: [
        hostFrameBuilderProvider.overrideWithValue(
          (context, spec) => Column(
            children: [
              Text('HOST-FRAME ${spec.title}'),
              Expanded(child: spec.body),
              if (spec.bottomNavigationBar != null) spec.bottomNavigationBar!,
            ],
          ),
        ),
        hostHeroBuilderProvider.overrideWithValue(
          (context, ref, {required badge, required child}) => Column(
            children: [Text('HOST-HERO $badge'), child],
          ),
        ),
      ],
    );
    expect(find.text('HOST-FRAME My livelihood'), findsOneWidget);
    expect(find.text('HOST-HERO Livelihood'), findsOneWidget);
    expect(find.text('HOST-NAV'), findsOneWidget);
    expect(find.text('Ask AI'), findsWidgets);
  });
}
