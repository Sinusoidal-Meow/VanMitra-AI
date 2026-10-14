import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/features/livelihood/data/livelihood_repository.dart';
import 'package:vanmitra_ai/features/livelihood/data/location_service.dart';
import 'package:vanmitra_ai/features/livelihood/data/profile_repository.dart';
import 'package:vanmitra_ai/features/livelihood/livelihood_routes.dart';
import 'package:vanmitra_ai/features/livelihood/models/profile.dart';
import 'package:vanmitra_ai/features/livelihood/models/report.dart';
import 'package:vanmitra_ai/features/livelihood/providers/intake_provider.dart';
import 'package:vanmitra_ai/features/livelihood/providers/livelihood_providers.dart';
import 'package:vanmitra_ai/features/livelihood/providers/profile_providers.dart';
import 'package:vanmitra_ai/features/livelihood/screens/livelihood_home_screen.dart';

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

class _FakeLocation implements LocationService {
  _FakeLocation({this.fix, this.failure});
  final GpsFix? fix;
  final LocationFailure? failure;

  @override
  Future<GpsFix> currentFix() async {
    if (failure != null) throw LocationException(failure!);
    return fix!;
  }
}

Future<ProviderContainer> _pumpHome(
  WidgetTester tester, {
  LocationService? location,
  String lang = 'en',
}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        livelihoodRepositoryProvider.overrideWithValue(_ReportRepo()),
        // the feature's default is the live server: these tests keep details in memory
        profileRepositoryProvider.overrideWithValue(MemoryProfileRepository()),
        if (location != null)
          locationServiceProvider.overrideWithValue(location),
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
        home: const LivelihoodHomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(LivelihoodHomeScreen)),
  );
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await _tap(tester, find.text('Next'));
  }
}

void main() {
  group('LivelihoodProfile', () {
    test('converts land units to hectares', () {
      expect(
        const LivelihoodProfile(
          areaValue: 1,
          areaUnit: AreaUnit.hectare,
        ).areaHa,
        1,
      );
      expect(
        const LivelihoodProfile(areaValue: 1, areaUnit: AreaUnit.acre).areaHa,
        closeTo(0.4047, 1e-4),
      );
      expect(
        const LivelihoodProfile(
          areaValue: 40,
          areaUnit: AreaUnit.guntha,
        ).areaHa,
        closeTo(
          const LivelihoodProfile(
            areaValue: 1,
            areaUnit: AreaUnit.acre,
          ).areaHa!,
          1e-9,
        ),
      );
      expect(const LivelihoodProfile().areaHa, isNull);
    });

    test(
      'JSON matches the backend request and leaves out what was not answered',
      () {
        expect(const LivelihoodProfile().toJson(), isEmpty);
        final json = const LivelihoodProfile(
          areaValue: 3,
          areaUnit: AreaUnit.acre,
          landType: LandType.rainFed,
          lat: 19.78,
          lng: 73.22,
          locationSource: LocationSource.gps,
          livestock: {'cow': 2},
          assets: {'well', 'pump'},
          pastWork: {'dairy'},
          moneyLevel: MoneyLevel.medium,
        ).toJson();
        expect(json['land'], {
          'area_value': 3.0,
          'area_unit': 'acre',
          'land_type': 'rain_fed',
        });
        expect(json['location'], {'lat': 19.78, 'lng': 73.22, 'source': 'gps'});
        expect(json['livestock'], {'cow': 2});
        expect(json['assets'], [
          'pump',
          'well',
        ]); // sorted, like the server stores them
        expect(json['money_level'], 'medium');
        expect(json.containsKey('family_workers'), isFalse);
      },
    );

    test('never carries caste, income or ID fields (rule L8)', () {
      final text = jsonEncode(
        const LivelihoodProfile(
          areaValue: 1,
          livestock: {'cow': 1},
          assets: {'well'},
        ).toJson(),
      ).toLowerCase();
      for (final banned in ['caste', 'income', 'aadhaar', 'pan']) {
        expect(text.contains(banned), isFalse, reason: banned);
      }
    });

    test('round-trips through JSON', () {
      const p = LivelihoodProfile(
        areaValue: 2.5,
        areaUnit: AreaUnit.guntha,
        waterOnLand: WaterOnLand.borewell,
        lat: 19.7,
        lng: 73.2,
        accuracyM: 12,
        locationSource: LocationSource.manual,
        livestock: {'goat_sheep': 5},
        assets: {'shed'},
        pastWork: {'millets', 'dairy'},
        familyWorkers: 3,
        moneyLevel: MoneyLevel.low,
      );
      final back = LivelihoodProfile.fromJson(p.toJson());
      expect(back.toJson(), p.toJson());
      expect(back.hasDetails, isTrue);
    });

    test('hasDetails is false for an empty profile', () {
      expect(const LivelihoodProfile().hasDetails, isFalse);
      expect(
        const LivelihoodProfile(locationSource: LocationSource.villageCentre)
            .hasDetails,
        isFalse,
      );
    });

    test('Maharashtra sanity box', () {
      expect(insideMaharashtra(19.78, 73.22), isTrue);
      expect(insideMaharashtra(28.6, 77.2), isFalse);
    });
  });

  group('IntakeNotifier', () {
    test('every question is optional: an empty form can be saved', () {
      final n = IntakeNotifier(const IntakeState());
      expect(n.validateForSave(), isTrue);
      expect(n.state.toProfile().hasDetails, isFalse);
    });

    test('a malformed area is refused, a blank one is not', () {
      final n = IntakeNotifier(const IntakeState());
      for (final bad in ['abc', '0', '-2', '..']) {
        n.setArea(bad);
        expect(n.errorFor(0), 'lv_err_area', reason: bad);
        expect(n.next(), isFalse);
        expect(n.state.step, 0);
      }
      n.setArea('2,5'); // a decimal comma is fine
      expect(n.errorFor(0), isNull);
      expect(n.state.areaValue, 2.5);
      n.setArea('');
      expect(n.errorFor(0), isNull);
    });

    test(
      'shows the hectare conversion and warns on a huge area without blocking',
      () {
        final n = IntakeNotifier(const IntakeState());
        n.setArea('3');
        expect(n.state.areaHa, closeTo(1.214, 1e-3));
        expect(n.state.areaLooksTooBig, isFalse);
        n.setArea('500');
        expect(n.state.areaLooksTooBig, isTrue);
        expect(n.errorFor(0), isNull);
      },
    );

    test('animal counts are clamped and zero removes the animal', () {
      final n = IntakeNotifier(const IntakeState());
      n.setAnimal('cow', 2);
      n.setAnimal('goat_sheep', 5000);
      expect(n.state.animals, {'cow': 2, 'goat_sheep': 999});
      n.setAnimal('cow', 0);
      n.setAnimal('goat_sheep', -3);
      expect(n.state.animals, isEmpty);
    });

    test('ticking twice unticks', () {
      final n = IntakeNotifier(const IntakeState());
      n.toggleAsset('well');
      n.toggleAsset('pump');
      n.toggleAsset('well');
      expect(n.state.assets, {'pump'});
    });

    test(
      'location: coordinates are checked only when he chose to give them',
      () {
        final n = IntakeNotifier(const IntakeState());
        expect(n.errorFor(4), isNull); // village centre by default
        n.setSource(LocationSource.manual);
        expect(n.errorFor(4), 'lv_err_coords');
        n.setLat('28.6');
        n.setLng('77.2');
        expect(n.errorFor(4), 'lv_err_outside_mh');
        n.setLat('19.78');
        n.setLng('73.22');
        expect(n.errorFor(4), isNull);
      },
    );

    test(
      'village centre sends no coordinates even if some were typed before',
      () {
        final n = IntakeNotifier(const IntakeState());
        n.setSource(LocationSource.manual);
        n.setLat('19.78');
        n.setLng('73.22');
        n.setSource(LocationSource.villageCentre);
        final p = n.state.toProfile();
        expect(p.lat, isNull);
        expect(p.locationSource, LocationSource.villageCentre);
      },
    );

    test('saving jumps back to the step with the problem', () {
      final n = IntakeNotifier(const IntakeState());
      n.setSource(LocationSource.manual); // coordinates missing
      n.setArea('x'); // and a bad area on step 1
      expect(n.validateForSave(), isFalse);
      expect(n.state.step, 0);
      expect(n.state.errorKey, 'lv_err_area');
    });

    test('Change my details starts from what he saved', () {
      const saved = LivelihoodProfile(
        areaValue: 3,
        areaUnit: AreaUnit.acre,
        livestock: {'cow': 2},
        assets: {'well'},
        lat: 19.78,
        lng: 73.22,
        locationSource: LocationSource.gps,
        accuracyM: 8,
      );
      final s = IntakeState.fromProfile(saved);
      expect(s.areaText, '3');
      expect(s.unit, AreaUnit.acre);
      expect(s.animals, {'cow': 2});
      expect(s.source, LocationSource.gps);
      expect(s.latText, '19.780000');
      expect(
        IntakeState.fromProfile(null).source,
        LocationSource.villageCentre,
      );
    });

    test('the back button never goes below the first step', () {
      final n = IntakeNotifier(const IntakeState());
      n.back();
      expect(n.state.step, 0);
    });
  });

  group('the form on screen', () {
    testWidgets('home asks for details first, then the form saves them', (
      tester,
    ) async {
      final container = await _pumpHome(tester);
      expect(
        find.text(
          'You have not added details yet. Add them to get ideas that fit you.',
        ),
        findsOneWidget,
      );
      expect(find.text('Change my details'), findsNothing);

      await _tap(tester, find.text('Add your details'));
      expect(find.text('Step 1 of 5'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('area_field')), '3');
      await tester.pumpAndSettle();
      expect(find.text('About 1.21 hectares'), findsOneWidget);
      await _tap(tester, find.text('Rain-fed'));
      await _next(tester);

      expect(find.text('Step 2 of 5'), findsOneWidget);
      final plus = find.byTooltip('+');
      await _tap(tester, plus.first); // cow
      await _tap(tester, plus.first);
      await _next(tester);

      await _tap(tester, find.text('Well'));
      await _next(tester);

      await _tap(tester, find.text('Dairy'));
      await _tap(tester, find.text('Medium'));
      await _next(tester);

      expect(find.text('Step 5 of 5'), findsOneWidget);
      expect(find.text('Save my details'), findsOneWidget);
      await _tap(tester, find.text('Save my details'));

      // back on the home screen, with his details saved
      expect(
        find.text('Your details are saved on this phone.'),
        findsOneWidget,
      );
      expect(find.text('Change my details'), findsOneWidget);
      final saved = container.read(profileProvider)!;
      expect(saved.areaHa, closeTo(1.214, 1e-3));
      expect(saved.landType, LandType.rainFed);
      expect(saved.livestock, {'cow': 2});
      expect(saved.assets, {'well'});
      expect(saved.pastWork, {'dairy'});
      expect(saved.moneyLevel, MoneyLevel.medium);
      expect(saved.locationSource, LocationSource.villageCentre);
      expect(saved.lat, isNull);
    });

    testWidgets('a bad area stops Next and says why', (tester) async {
      await _pumpHome(tester);
      await _tap(tester, find.text('Add your details'));
      await tester.enterText(find.byKey(const ValueKey('area_field')), '0');
      await _next(tester);
      expect(find.text('Enter a number greater than zero.'), findsOneWidget);
      expect(find.text('Step 1 of 5'), findsOneWidget);
    });

    testWidgets('Back returns to the previous step and keeps the answers', (
      tester,
    ) async {
      await _pumpHome(tester);
      await _tap(tester, find.text('Add your details'));
      await tester.enterText(find.byKey(const ValueKey('area_field')), '5');
      await _next(tester);
      await _tap(tester, find.text('Back'));
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '5'), findsOneWidget);
    });

    testWidgets('GPS fills the location and shows how accurate it is', (
      tester,
    ) async {
      final container = await _pumpHome(
        tester,
        location: _FakeLocation(
          fix: const GpsFix(lat: 19.7805, lng: 73.221, accuracyM: 9.4),
        ),
      );
      await _tap(tester, find.text('Add your details'));
      await _next(tester, 4);
      await _tap(tester, find.text('Use my current location'));
      expect(find.text('Location found: 19.780500, 73.221000'), findsOneWidget);
      expect(find.text('Accurate to about 9 m'), findsOneWidget);
      await _tap(tester, find.text('Save my details'));
      final p = container.read(profileProvider)!;
      expect(p.locationSource, LocationSource.gps);
      expect(p.lat, closeTo(19.7805, 1e-6));
      expect(p.accuracyM, 9.4);
    });

    testWidgets(
      'a refused location permission explains and offers the other ways',
      (tester) async {
        await _pumpHome(
          tester,
          location: _FakeLocation(failure: LocationFailure.denied),
        );
        await _tap(tester, find.text('Add your details'));
        await _next(tester, 4);
        await _tap(tester, find.text('Use my current location'));
        expect(
          find.text(
            'Location permission was denied. Type the coordinates or use your village centre.',
          ),
          findsOneWidget,
        );
        expect(find.text('Type the coordinates'), findsOneWidget);
        expect(find.text('Use my village centre'), findsOneWidget);
      },
    );

    testWidgets('coordinates outside Maharashtra are refused on save', (
      tester,
    ) async {
      final container = await _pumpHome(tester);
      await _tap(tester, find.text('Add your details'));
      await _next(tester, 4);
      await _tap(tester, find.text('Type the coordinates'));
      await tester.enterText(find.byKey(const ValueKey('lat_field')), '28.6');
      await tester.enterText(find.byKey(const ValueKey('lng_field')), '77.2');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Save my details'));
      expect(
        find.text('This place is outside Maharashtra. Check the numbers.'),
        findsOneWidget,
      );
      expect(container.read(profileProvider), isNull); // nothing was saved
    });

    testWidgets('Delete my answers asks first, then clears them', (
      tester,
    ) async {
      final container = await _pumpHome(tester);
      await container
          .read(profileProvider.notifier)
          .save(const LivelihoodProfile(areaValue: 2, livestock: {'cow': 1}));
      await tester.pumpAndSettle();
      expect(find.text('Delete my answers'), findsOneWidget);

      await _tap(tester, find.text('Delete my answers'));
      expect(find.text('Delete your answers?'), findsOneWidget);
      await _tap(tester, find.text('Keep them'));
      expect(
        container.read(profileProvider),
        isNotNull,
      ); // keeping them changes nothing

      await _tap(tester, find.text('Delete my answers'));
      await _tap(tester, find.text('Delete answers'));
      expect(container.read(profileProvider), isNull);
      expect(
        find.text(
          'You have not added details yet. Add them to get ideas that fit you.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the form works in Marathi', (tester) async {
      await _pumpHome(tester, lang: 'mr');
      await _tap(tester, find.text('तुमची माहिती भरा'));
      expect(find.text('पायरी 1 पैकी 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
