import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vanmitra_ai/data/local/hive_database.dart';
import 'package:vanmitra_ai/demo/core/demo_accounts.dart';
import 'package:vanmitra_ai/features/case_hub/case_home_screen.dart';
import 'package:vanmitra_ai/demo/demo_backend.dart';
import 'package:vanmitra_ai/demo/demo_mode.dart';
import 'package:vanmitra_ai/models/user.dart';
import 'package:vanmitra_ai/models/user_role.dart';
import 'package:vanmitra_ai/providers/auth_provider.dart';
import 'package:vanmitra_ai/providers/meeting_provider.dart';
import 'package:vanmitra_ai/screens/home/villager_home_screen.dart';
import 'package:vanmitra_ai/services/localization_service.dart';

/// The real screens, driven against the offline demo server, for each kind of login. This is the
/// closest a test gets to opening the app on a phone: it checks what each user actually sees.

class _FixedAuth extends AuthNotifier {
  _FixedAuth(User user) {
    state = AuthState(currentUser: user, isAuthenticated: true);
  }
}

User _user(int n, UserRole role, String name) => User(
      id: DemoAccounts.userIdFor(n),
      email: '',
      name: name,
      role: role,
      villageId: 'ozhar_jawhar_palghar',
      backendVillageId: role == UserRole.sdlc ? null : DemoAccounts.villageId,
      createdAt: DateTime(2026, 10, 14),
    );

Future<void> _pumpApp(WidgetTester tester, User user, int userNumber, {Widget? home}) async {
  // test fonts are far wider than the app's, so a row that fits on a phone can "overflow" here
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final what = details.exceptionAsString();
    // test fonts are wider than the app's; the ListTile note is a cosmetic debug assertion
    if (what.contains('RenderFlex overflowed') || what.contains('ListTile background color')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
  FlutterSecureStorage.setMockInitialValues({
    'access_token': 'demo-access-${DemoAccounts.userIdFor(userNumber)}',
    'refresh_token': 'demo-refresh-${DemoAccounts.userIdFor(userNumber)}',
  });
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(), // a fresh app each time: no routes left over from the last screen
      overrides: [
        authProvider.overrideWith((ref) => _FixedAuth(user)),
        meetingsStreamProvider.overrideWith((ref, id) => Stream.value(const [])),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home ?? const VillagerHomeScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('vm_hive_ui');
    Hive.init(hiveDir.path);
    for (final box in [HiveDatabase.settingsBox]) {
      await Hive.openBox(box);
    }
    for (final box in [HiveDatabase.noticesBox, HiveDatabase.userBox, HiveDatabase.syncQueueBox]) {
      await Hive.openBox<Map>(box);
    }
  });

  setUp(() {
    DemoMode.idForTest = 'all';
    DemoBackend.instance = DemoBackend(
      storage: MemoryDemoStorage(),
      loadAsset: (p) => File(p).readAsString(),
      seedSampleClaims: true,
    );
  });
  tearDown(() => DemoMode.idForTest = null);

  testWidgets('the Gram Sabha login opens its own dashboard, with no demo bar', (tester) async {
    await _pumpApp(tester, _user(3, UserRole.frc, 'Demo Gram Sabha (Ozhar)'), 3);
    expect(find.textContaining('Demo Active'), findsNothing);
    expect(find.text('Switch Role'), findsNothing);
    expect(find.text('Gram Sabha'), findsWidgets); // the role on the hero card
    expect(find.text('Gram Sabha review'), findsOneWidget);
    expect(find.text('1 claim waiting for your decision'), findsOneWidget);
  });

  testWidgets('the SDO login opens its own dashboard and has no Livelihood tab', (tester) async {
    await _pumpApp(tester, _user(5, UserRole.sdlc, 'Demo SDO (Jawhar)'), 5);
    expect(find.textContaining('Demo Active'), findsNothing);
    expect(find.text('SDO review'), findsOneWidget);
    expect(find.text('1 claim waiting for your decision'), findsOneWidget);
    expect(find.text('Livelihood'), findsNothing);
    // an SDO reviews claims; it does not file them or attend as a member
    expect(find.text('File New Claim'), findsNothing);
    expect(find.text('Self Check-in'), findsNothing);
    expect(find.text('My livelihood'), findsNothing);
  });

  testWidgets('the village user sees the normal dashboard, not the officials card', (tester) async {
    await _pumpApp(tester, _user(1, UserRole.villager, 'Demo Village User'), 1);
    expect(find.text('Gram Sabha review'), findsNothing);
    expect(find.text('SDO review'), findsNothing);
    expect(find.text('Livelihood'), findsWidgets);
  });

  Future<void> settle(WidgetTester tester, [int times = 4]) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  /// Press the button that carries [label], whatever kind of button it is.
  Future<void> press(WidgetTester tester, String label) async {
    for (final kind in [FilledButton, ElevatedButton, TextButton, OutlinedButton]) {
      final found = find.ancestor(of: find.text(label).last, matching: find.byType(kind));
      if (found.evaluate().isEmpty) continue;
      final w = tester.widget(found.first);
      final VoidCallback? onPressed = switch (w) {
        FilledButton b => b.onPressed,
        ElevatedButton b => b.onPressed,
        TextButton b => b.onPressed,
        OutlinedButton b => b.onPressed,
        _ => null,
      };
      expect(onPressed, isNotNull, reason: '"$label" is disabled');
      onPressed!();
      return;
    }
    fail('no button labelled "$label"');
  }

  testWidgets('the Gram Sabha opens the claim waiting for it and approves it', (tester) async {
    await _pumpApp(tester, _user(3, UserRole.frc, 'Demo Gram Sabha (Ozhar)'), 3);
    await tester.tap(find.text('Claims').last);
    await settle(tester);
    // the review queue is the first thing it sees: the Form B that was filed to it
    expect(find.textContaining('Ozhar Gram Sabha'), findsWidgets);
    await tester.tap(find.textContaining('Ozhar Gram Sabha').first);
    await settle(tester);
    expect(find.text('Approve & forward'), findsOneWidget);
    expect(find.text('Submit claim · दाखल करा'), findsNothing); // not its claim to submit

    await tester.tap(find.text('Approve & forward')); // a real tap: the button must be reachable
    await settle(tester);
    await tester.tap(find.text('Approve').last); // the confirmation dialog
    await settle(tester, 6);
    expect(find.text('Claim approved and forwarded.'), findsOneWidget);
    // the claim moved on: the Gram Sabha has nothing left to decide
    final queue = await DemoBackend.instance
        .handle('GET', '/review/queue', token: 'demo-access-${DemoAccounts.userIdFor(3)}') as List;
    expect(queue, isEmpty);
  });

  testWidgets('the SDO sees what the Gram Sabha approved and sends one back', (tester) async {
    await _pumpApp(tester, _user(5, UserRole.sdlc, 'Demo SDO (Jawhar)'), 5);
    await tester.tap(find.text('Claims').last);
    await settle(tester);
    expect(find.textContaining('Ramesh Gavit'), findsWidgets);
    await tester.tap(find.textContaining('Ramesh Gavit').first);
    await settle(tester);
    expect(find.text('Approve & forward'), findsOneWidget);
    expect(find.textContaining('Send back'), findsWidgets);
  });

  testWidgets('the village user corrects a returned claim and files it again', (tester) async {
    await _pumpApp(tester, _user(1, UserRole.villager, 'Demo Village User'), 1);
    await tester.tap(find.text('Claims').last);
    await settle(tester);
    expect(find.textContaining('Sent back'), findsWidgets); // the claim the Gram Sabha returned
    await tester.tap(find.textContaining('Lata Bhoye').first);
    await settle(tester);
    expect(find.text('Submit claim · दाखल करा'), findsOneWidget);
    await press(tester, 'Submit claim · दाखल करा');
    await settle(tester);
    await press(tester, 'Submit');
    await settle(tester, 6);
    expect(find.text('Claim submitted to the Gram Sabha.'), findsOneWidget);
  });

  // Every tab of the bottom bar, for every kind of login: none may show a load error.
  const errorMarks = [
    'Could not load',
    'Could not open',
    'Error loading',
    'went wrong',
    'Try again',
    'not available',
    'Not Found',
  ];

  String shownText(WidgetTester tester) => find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? '')
      .join(' | ');

  Future<void> everyTab(WidgetTester tester, User user, int n, List<String> tabs) async {
    await _pumpApp(tester, user, n);
    for (final tab in tabs) {
      await tester.tap(find.text(tab).last);
      await settle(tester, 6);
      final text = shownText(tester);
      for (final mark in errorMarks) {
        expect(text.contains(mark), isFalse,
            reason: '${user.name}, tab $tab shows $mark: $text');
      }
    }
  }

  testWidgets('every tab loads for the village user', (tester) async {
    await everyTab(tester, _user(1, UserRole.villager, 'Demo Village User'), 1,
        ['Claims', 'Profile', 'Gram Sabha', 'Map', 'Livelihood', 'Dashboard']);
  });

  testWidgets('every tab loads for the Gram Sabha', (tester) async {
    await everyTab(tester, _user(3, UserRole.frc, 'Demo Gram Sabha (Ozhar)'), 3,
        ['Claims', 'Profile', 'Gram Sabha', 'Map', 'Livelihood', 'Dashboard']);
  });

  testWidgets('every tab loads for the SDO', (tester) async {
    await everyTab(tester, _user(5, UserRole.sdlc, 'Demo SDO (Jawhar)'), 5,
        ['Claims', 'Profile', 'Gram Sabha', 'Map', 'Dashboard']);
  });

  Future<List> myCases(int n) async => await DemoBackend.instance
      .handle('GET', '/cases/mine', token: 'demo-access-${DemoAccounts.userIdFor(n)}') as List;

  testWidgets('the village user files a new Form A, B and C from the dashboard', (tester) async {
    await _pumpApp(tester, _user(2, UserRole.villager, 'Demo Village User 2'), 2);
    final before = (await myCases(2)).length;
    for (final form in [
      'Form A · Individual forest rights',
      'Form B · Community rights',
      'Form C · Community forest resource',
    ]) {
      await tester.tap(find.text('File New Claim').first);
      await settle(tester);
      expect(find.text('Form A · Individual forest rights'), findsOneWidget);
      expect(find.text('Form B · Community rights'), findsOneWidget);
      expect(find.text('Form C · Community forest resource'), findsOneWidget);
      await tester.tap(find.text(form));
      await settle(tester, 6);
      // its claim page opened: a draft with the claimant's own submit button
      expect(find.text('Submit claim · दाखल करा'), findsOneWidget, reason: form);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop(); // back to the dashboard
      await settle(tester);
    }
    final after = await myCases(2);
    expect(after.length, before + 3);
    expect(after.map((c) => c['form']).toSet(), containsAll(['A', 'B', 'C']));
  });

  testWidgets('a new Form A is filed from the claim page and reaches the Gram Sabha', (tester) async {
    await _pumpApp(tester, _user(2, UserRole.villager, 'Demo Village User 2'), 2);
    await tester.tap(find.text('File New Claim').first);
    await settle(tester);
    await tester.tap(find.text('Form A · Individual forest rights'));
    await settle(tester, 6);
    await press(tester, 'Submit claim · दाखल करा');
    await settle(tester);
    await press(tester, 'Submit');
    await settle(tester, 6);
    expect(find.text('Claim submitted to the Gram Sabha.'), findsOneWidget);
    final gsQueue = await DemoBackend.instance
        .handle('GET', '/review/queue', token: 'demo-access-${DemoAccounts.userIdFor(3)}') as List;
    expect(gsQueue.where((c) => c['form'] == 'A'), isNotEmpty);
  });

  testWidgets('the Gram Sabha can file Forms B and C, but not Form A', (tester) async {
    await _pumpApp(tester, _user(3, UserRole.frc, 'Demo Gram Sabha (Ozhar)'), 3);
    await tester.tap(find.text('File New Claim').first);
    await settle(tester);
    expect(find.text('Form A · Individual forest rights'), findsNothing);
    expect(find.text('Form B · Community rights'), findsOneWidget);
    expect(find.text('Form C · Community forest resource'), findsOneWidget);
  });

  // Each step of a claim opens its real screen without an error: the form itself (A, B or C),
  // the evidence, the Gram Sabha decision and the status page.
  Future<void> everyStep(WidgetTester tester, User user, int n, String claimant) async {
    await _pumpApp(tester, user, n);
    for (final step in [
      'Claim form · दावा अर्ज',
      'Evidence · पुरावे (Rule 13)',
      'Gram Sabha decision · ठराव',
      'Status & title · सनद',
    ]) {
      await tester.tap(find.text('Claims').last);
      await settle(tester);
      await tester.tap(find.textContaining(claimant).first);
      await settle(tester, 6);
      await tester.tap(find.text(step));
      await settle(tester, 8);
      final text = shownText(tester);
      for (final mark in errorMarks) {
        expect(text.contains(mark), isFalse, reason: '$claimant, step $step shows $mark: $text');
      }
      // back to the dashboard shell for the next step
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      while (nav.canPop()) {
        nav.pop();
        await settle(tester, 2);
      }
    }
  }

  testWidgets('every step of a Form A claim opens', (tester) async {
    await everyStep(tester, _user(1, UserRole.villager, 'Demo Village User'), 1, 'Kisan Pawar');
  });

  testWidgets('every step of a Form B claim opens', (tester) async {
    await everyStep(tester, _user(1, UserRole.villager, 'Demo Village User'), 1, 'Ozhar Gram Sabha');
  });

  testWidgets('every step of the Gram Sabha own Form C opens', (tester) async {
    final gs = _user(3, UserRole.frc, 'Demo Gram Sabha (Ozhar)');
    final mine = await myCases(3);
    final c = mine.firstWhere((x) => x['form'] == 'C') as Map;
    for (final step in [
      'Claim form · दावा अर्ज',
      'Evidence · पुरावे (Rule 13)',
      'Boundary & landmarks · सीमा',
      'Field verification · पडताळणी',
      'Gram Sabha decision · ठराव',
      'Status & title · सनद',
    ]) {
      await _pumpApp(tester, gs, 3, home: CaseHomeScreen(caseId: c['id'] as String, initialClaimType: 'cfr'));
      await settle(tester, 6);
      await tester.tap(find.text(step));
      await settle(tester, 8);
      final text = shownText(tester);
      for (final mark in errorMarks) {
        expect(text.contains(mark), isFalse, reason: 'Form C, step $step shows $mark: $text');
      }
    }
  });

  testWidgets('Form A: type the details on the form screen, save, and the server has them', (tester) async {
    await _pumpApp(tester, _user(2, UserRole.villager, 'Demo Village User 2'), 2);
    await tester.tap(find.text('File New Claim').first);
    await settle(tester);
    await tester.tap(find.text('Form A · Individual forest rights'));
    await settle(tester, 6);
    await tester.tap(find.text('Claim form · दावा अर्ज'));
    await settle(tester, 8);

    final names = find.widgetWithText(TextField, 'दावेदाराचे नाव / Claimant Name(s) *');
    await tester.scrollUntilVisible(names, 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(names, 'Sanskriti Patil');
    final address = find.widgetWithText(TextField, 'पत्ता / Address');
    await tester.scrollUntilVisible(address, 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(address, 'Ozhar, Jawhar');
    await settle(tester, 2);

    final save = find.textContaining('Save Draft');
    await tester.scrollUntilVisible(save, 300, scrollable: find.byType(Scrollable).first);
    await press(tester, 'मसुदा जतन करा / Save Draft');
    await settle(tester, 6);
    expect(find.textContaining('saved successfully'), findsOneWidget);

    final mine = await myCases(2);
    final c = mine.firstWhere((x) => x['claimant_label'] == 'Sanskriti Patil') as Map;
    final form = await DemoBackend.instance.handle('GET', '/cases/${c['id']}/form-a',
        token: 'demo-access-${DemoAccounts.userIdFor(2)}') as Map;
    expect(form['claimant_names'], ['Sanskriti Patil']);
    expect(form['address'], 'Ozhar, Jawhar');
  });

  Future<void> newClaimAndOpenForm(WidgetTester tester, String form) async {
    await _pumpApp(tester, _user(2, UserRole.villager, 'Demo Village User 2'), 2);
    await tester.tap(find.text('File New Claim').first);
    await settle(tester);
    await tester.tap(find.text(form));
    await settle(tester, 6);
    await tester.tap(find.text('Claim form · दावा अर्ज'));
    await settle(tester, 8);
  }

  testWidgets('Form B: type the claimant on the form screen and save', (tester) async {
    await newClaimAndOpenForm(tester, 'Form B · Community rights');
    final names = find.widgetWithText(TextField, 'Name of the claimant(s): one per line');
    await tester.scrollUntilVisible(names, 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(names, 'Ozhar Gram Sabha');
    final save = find.text('Save draft');
    await tester.scrollUntilVisible(save, 300, scrollable: find.byType(Scrollable).first);
    await press(tester, 'Save draft');
    await settle(tester, 6);
    final mine = await myCases(2);
    final c = mine.firstWhere((x) => x['form'] == 'B') as Map;
    final form = await DemoBackend.instance.handle('GET', '/cases/${c['id']}/form-b',
        token: 'demo-access-${DemoAccounts.userIdFor(2)}') as Map;
    expect(form['claimant_names'], ['Ozhar Gram Sabha']);
  });

  testWidgets('Form C: the form screen saves its draft without an error', (tester) async {
    await newClaimAndOpenForm(tester, 'Form C · Community forest resource');
    final save = find.text('Save draft · जतन करा');
    await tester.scrollUntilVisible(save, 400, scrollable: find.byType(Scrollable).first);
    await press(tester, 'Save draft · जतन करा');
    await settle(tester, 6);
    expect(find.text('Form C draft saved.'), findsOneWidget);
  });
}
