import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/core/api/api_client.dart';
import 'package:vanmitra_ai/demo/boundary/demo_geo.dart';
import 'package:vanmitra_ai/demo/core/demo_accounts.dart';
import 'package:vanmitra_ai/demo/core/demo_core.dart';
import 'package:vanmitra_ai/demo/demo_backend.dart';
import 'package:vanmitra_ai/demo/demo_mode.dart';

import 'demo_support.dart';

const String _v = DemoAccounts.villageId;
const String _villager = '9000000001';
const String _villager2 = '9000000002';
const String _gramSabha = '9000000003';
const String _sdo = '9000000005';

List<List<double>> _sq(double lon, double lat, [double d = 0.01]) => [
      [lon, lat],
      [lon + d, lat],
      [lon + d, lat + d],
      [lon, lat + d],
    ];

Map<String, dynamic> _poly(List<List<double>> pts) => {
      'type': 'Polygon',
      'coordinates': [pts],
    };

/// A demo server whose database the test can reach (to put in what other slices would have
/// written: a neighbouring village, forms, messages).
class _Rig {
  _Rig() {
    DemoMode.idForTest = 'all';
    backend = DemoBackend(
      storage: storage,
      loadAsset: (path) => File(path).readAsString(),
      clock: () => now,
    );
  }

  final MemoryDemoStorage storage = MemoryDemoStorage();
  late final DemoBackend backend;
  DateTime now = DateTime.utc(2026, 10, 14, 6, 30);

  Future<String> login(String phone) async {
    final t = await backend
        .handle('POST', '/auth/login', body: {'phone': phone, 'pin': DemoAccounts.pin});
    return (t as Map)['access_token'] as String;
  }

  Future<dynamic> call(String method, String path, {Object? body, String? token}) =>
      backend.handle(method, path, body: body, token: token);

  Future<ApiException> fails(String method, String path, {Object? body, String? token}) async {
    try {
      await call(method, path, body: body, token: token);
    } on ApiException catch (e) {
      return e;
    }
    throw StateError('$method $path was expected to fail');
  }

  /// A table of the database (the demo's data after the first call).
  List<Map<String, dynamic>> table(String name) =>
      (storage.read().putIfAbsent(name, () => <dynamic>[]) as List).cast<Map<String, dynamic>>();

  /// A second village with its own Gram Sabha and a Form C claim already mapped in [polygon].
  String neighbour(String tag, List<List<double>> polygon, {String state = 'gs_review'}) {
    final stamp = now.toIso8601String();
    table('village').add(<String, dynamic>{
      'id': 'village-$tag',
      'name_mr': 'वाडी $tag',
      'name_en': 'Wadi $tag',
      'gram_panchayat': 'Wadi',
      'taluka': 'Jawhar',
      'district': 'Palghar',
      'state': 'Maharashtra',
      'created_at': stamp,
      'updated_at': stamp,
    });
    table('gram_sabha').add(<String, dynamic>{
      'id': 'gs-$tag',
      'village_id': 'village-$tag',
      'created_at': stamp,
      'updated_at': stamp,
    });
    table('claim_case').add(<String, dynamic>{
      'id': 'case-$tag',
      'gram_sabha_id': 'gs-$tag',
      'claim_type': 'cfr',
      'state': state,
      'created_by_user_id': 'someone-$tag',
      'reached_stage': 1,
      'created_at': stamp,
      'updated_at': stamp,
    });
    table('cfr_boundary').add(<String, dynamic>{
      'id': 'boundary-$tag',
      'case_id': 'case-$tag',
      'version': 1,
      'geom': {
        'type': 'Polygon',
        'coordinates': [
          [...polygon, polygon.first],
        ],
      },
      'source': 'gps_walk',
      'status': 'draft',
      'area_ha': 1.0,
      'accuracy_stats': <String, dynamic>{},
      'is_current': true,
      'created_by_user_id': 'someone-$tag',
      'created_at': stamp,
      'segments': <dynamic>[],
      'landmarks': <dynamic>[],
      'use_zones': <dynamic>[],
    });
    return 'case-$tag';
  }

  void dispose() => DemoMode.idForTest = null;
}

void main() {
  group('geometry (port of tests/unit/test_geo.py)', () {
    final square = [
      [73.2, 19.9],
      [73.21, 19.9],
      [73.21, 19.91],
      [73.2, 19.91],
    ];

    test('a ring is closed for the caller', () {
      final r = ring(square);
      expect(r.first, r.last);
      expect(r.length, 5);
      expect(ring([...square, square.first]), r);
    });

    test('bad rings are refused with the backend keys', () {
      void expectKey(List<List<num>> coords, String key) {
        expect(
          () => ring(coords),
          throwsA(isA<GeoError>().having((e) => e.key, 'key', key)),
        );
      }

      expectKey([
        [73.2, 19.9],
        [73.21, 19.9],
        [73.2, 19.9],
      ], 'geo.ring_too_short');
      expectKey([
        [73.2, 19.9],
        [190, 19.9],
        [73.2, 19.91],
      ], 'geo.out_of_range');
      expectKey([
        [73.2],
        [73.21, 19.9],
        [73.2, 19.91],
      ], 'geo.bad_position');
    });

    test('WKT text', () {
      expect(polygonWkt([ring(square)]).startsWith('POLYGON((73.2 19.9, 73.21 19.9'), isTrue);
      expect(lineWkt([(1.0, 2.0), (3.0, 4.0)]), 'LINESTRING(1.0 2.0, 3.0 4.0)');
      expect(pointWkt(73.2, 19.9), 'POINT(73.2 19.9)');
      expect(() => lineWkt([(1.0, 2.0)]), throwsA(isA<GeoError>()));
    });

    test('one break is the whole ring', () {
      final r = ring(square);
      expect(splitRing(r, [0]), [r]);
    });

    test('four breaks are the four sides; order and duplicates do not matter', () {
      final r = ring(square);
      final parts = splitRing(r, [3, 0, 2, 1, 1]);
      expect(parts.length, 4);
      expect(parts[0], [r[0], r[1]]);
      expect(parts[3], [r[3], r[0]]); // wraps round to the first break
    });

    test('breaks split where asked', () {
      final r = ring(square);
      expect(splitRing(r, [1, 3]), [
        [r[1], r[2], r[3]],
        [r[3], r[0], r[1]],
      ]);
    });

    test('bad breaks', () {
      for (final breaks in [<int>[], [4], [-1]]) {
        expect(() => splitRing(ring(square), breaks), throwsA(isA<GeoError>()));
      }
    });

    test('accuracy statistics flag the points over the limit', () {
      expect(accuracyStats([3.0, null, 22.5, 15.0], 4, 15.0), {
        'points': 4,
        'with_accuracy': 3,
        'worst_m': 22.5,
        'over_limit': 1,
        'limit_m': 15.0,
      });
      expect(accuracyStats(null, 4, 15.0)['worst_m'], isNull);
    });

    test('UTM 43N: the central meridian and a known northing', () {
      final onMeridian = toUtm((75.0, 20.0));
      expect(onMeridian.$1, closeTo(500000, 0.01));
      expect(onMeridian.$2, closeTo(2211481, 20)); // 0.9996 x the meridian arc to 20 degrees
      expect(toUtm((75.0, 0.0)).$2, closeTo(0, 0.001));
    });

    test('areas and lengths are in metres on the ground', () {
      // 0.01 degree square at 19.9 N: about 1047 m by 1107 m
      final ha = areaHa([ring(square)]);
      expect(ha, inInclusiveRange(115.5, 116.5));
      expect(lengthM([(73.2, 19.9), (73.21, 19.9)]), closeTo(1047.5, 3));
      // a hole is taken out of the area
      final hole = ring(_sq(73.203, 19.903, 0.002));
      expect(areaHa([ring(square), hole]), closeTo(ha - areaHa([hole]), 0.0002));
    });

    test('validity: a bow-tie, a spike and a hole outside the shell are invalid', () {
      expect(explainInvalid([ring(square)]), isNull);
      final bowTie = ring([
        [73.2, 19.9],
        [73.21, 19.91],
        [73.21, 19.9],
        [73.2, 19.91],
      ]);
      expect(explainInvalid([bowTie]), startsWith('Self-intersection'));
      final spike = ring([
        [73.2, 19.9],
        [73.21, 19.9],
        [73.205, 19.9],
        [73.205, 19.91],
      ]);
      expect(explainInvalid([spike]), isNotNull);
      final outside = ring(_sq(73.3, 19.9, 0.001));
      expect(explainInvalid([ring(square), outside]), startsWith('Hole lies outside shell'));
      expect(explainInvalid([ring(square), ring(_sq(73.203, 19.903, 0.002))]), isNull);
    });

    test('overlap of two squares is a quarter of each, and none when apart or only touching', () {
      final a = [ring(_sq(73.2, 19.9))];
      final b = [ring(_sq(73.205, 19.905))];
      final ov = overlapOf(a, b)!;
      expect(ov.ha, closeTo(areaHa(a) / 4, 0.1));
      expect(ov.geojson['type'], 'Polygon');
      expect(overlapOf(a, [ring(_sq(73.3, 19.9))]), isNull);
      expect(overlapOf(a, [ring(_sq(73.21, 19.9))]), isNull); // share only an edge
    });

    test('overlap of two non-convex polygons is exact in area', () {
      // an L shape and a square covering its corner
      final l = [
        ring([
          [73.2, 19.9],
          [73.21, 19.9],
          [73.21, 19.905],
          [73.205, 19.905],
          [73.205, 19.91],
          [73.2, 19.91],
        ]),
      ];
      final l2 = [
        ring([
          [73.203, 19.903],
          [73.213, 19.903],
          [73.213, 19.908],
          [73.208, 19.908],
          [73.208, 19.913],
          [73.203, 19.913],
        ]),
      ];
      final ov = overlapOf(l, l2)!;
      // in cells of 0.001 degree: 14 (lower arm) + 6 + 4 (upper arm) = 24
      final cell = areaHa([ring(_sq(73.2, 19.9, 0.001))]);
      expect(ov.ha, closeTo(24 * cell, 0.1));
      expect(overlapOf(l2, l)!.ha, closeTo(ov.ha, 0.01)); // the order does not matter
      expect(overlapOf(l, l)!.ha, closeTo(areaHa(l), 0.01)); // a polygon with itself
    });

    test('a zone within the boundary is covered; one sticking out is not', () {
      final b = [ring(square)];
      expect(polygonCovers(b, [ring(_sq(73.203, 19.903, 0.003))]), isTrue);
      expect(polygonCovers(b, [ring(_sq(73.205, 19.905, 0.01))]), isFalse);
      expect(polygonCovers(b, [ring(square)]), isTrue); // the same polygon
    });
  });

  group('boundary mapping routes', () {
    late DemoHarness h;
    late String gs;
    late String villager;
    late String caseId;
    setUp(() async {
      h = DemoHarness();
      gs = await h.login(_gramSabha);
      villager = await h.login(_villager);
      final c = await h.call('POST', '/villages/$_v/cases', token: gs, body: {'claim_type': 'cfr'});
      caseId = c['id'] as String;
    });
    tearDown(() => h.dispose());

    Future<Map<String, dynamic>> save({
      List<int>? breaks,
      List<List<double>>? pts,
      List<double?>? accuracy,
      String? token,
      String? id,
    }) async {
      final out = await h.call('POST', '/cases/${id ?? caseId}/boundary',
          token: token ?? gs,
          body: {
            'polygon': _poly(pts ?? _sq(73.2, 19.9)),
            'source': 'gps_walk',
            if (breaks != null) 'segment_breaks': breaks,
            if (accuracy != null) 'vertex_accuracy_m': accuracy,
          });
      return Map<String, dynamic>.from(out as Map);
    }

    test('there is no boundary before one is saved', () async {
      final e = await h.fails('GET', '/cases/$caseId/boundary', token: gs);
      expect((e.statusCode, e.error, e.messageKey), (404, 'NO_BOUNDARY', 'boundary.none'));
      expect(await h.call('GET', '/cases/$caseId/boundary/versions', token: gs), isEmpty);
      expect(await h.call('GET', '/cases/$caseId/disputes', token: gs), isEmpty);
      expect(await h.call('GET', '/cases/$caseId/boundary/walks', token: gs), isEmpty);
    });

    test('saving a boundary gives version 1 with its four sides', () async {
      final b = await save(breaks: [0, 1, 2, 3], accuracy: [3.0, null, 22.5, 9.0]);
      expect(b['version'], 1);
      expect(b['status'], 'draft');
      expect(b['source'], 'gps_walk');
      expect(b['case_id'], caseId);
      expect(double.parse(b['area_ha'] as String), inInclusiveRange(115.5, 116.5));
      expect((b['area_ha'] as String).split('.').last.length, 4); // a Decimal, 4 places
      expect(b['sealed_hash'], isNull);
      expect(b['approved_on'], isNull);
      final segments = (b['segments'] as List).cast<Map>();
      expect(segments.length, 4);
      expect(segments.map((s) => s['seq']), [0, 1, 2, 3]);
      expect(segments.first['geometry']['type'], 'LineString');
      expect((segments.first['length_m'] as num), closeTo(1047.5, 3));
      expect(segments.every((s) => s['landmark_count'] == 0), isTrue);
      expect(b['segments_without_landmark'], 4);
      expect(b['open_disputes'], 0);
      expect(b['landmarks'], isEmpty);
      expect(b['use_zones'], isEmpty);
      expect(b['accuracy_stats'],
          {'points': 4, 'with_accuracy': 3, 'worst_m': 22.5, 'over_limit': 1, 'limit_m': 15.0});
      expect(b['geometry']['coordinates'][0].length, 5); // closed for us
      final again = await h.call('GET', '/cases/$caseId/boundary', token: gs);
      expect(again['id'], b['id']);
    });

    test('the default is one segment: the whole ring', () async {
      final b = await save();
      expect((b['segments'] as List).length, 1);
      expect(((b['segments'] as List).single as Map)['geometry']['coordinates'].length, 5);
    });

    test('bad input: invalid shapes and counts', () async {
      final bow = await h.fails('POST', '/cases/$caseId/boundary', token: gs, body: {
        'polygon': _poly([
          [73.2, 19.9],
          [73.21, 19.91],
          [73.21, 19.9],
          [73.2, 19.91],
        ]),
      });
      expect((bow.statusCode, bow.error, bow.messageKey), (422, 'INVALID_GEOMETRY', 'geo.invalid_polygon'));
      expect(bow.details!['reason'], contains('Self-intersection'));

      final two = await h.fails('POST', '/cases/$caseId/boundary', token: gs, body: {
        'polygon': _poly([
          [73.2, 19.9],
          [73.21, 19.9],
          [73.2, 19.9],
        ]),
      });
      expect((two.statusCode, two.messageKey), (422, 'geo.ring_too_short'));

      final acc = await h.fails('POST', '/cases/$caseId/boundary',
          token: gs, body: {'polygon': _poly(_sq(73.2, 19.9)), 'vertex_accuracy_m': [1.0, 2.0]});
      expect((acc.statusCode, acc.error), (422, 'ACCURACY_LENGTH'));
      expect(acc.details, {'vertices': 4});

      final brk = await h.fails('POST', '/cases/$caseId/boundary',
          token: gs, body: {'polygon': _poly(_sq(73.2, 19.9)), 'segment_breaks': [7]});
      expect((brk.statusCode, brk.messageKey), (422, 'geo.break_out_of_range'));

      final shape = await h.fails('POST', '/cases/$caseId/boundary',
          token: gs, body: {'polygon': {'type': 'Point', 'coordinates': [1, 2]}});
      expect((shape.statusCode, shape.error, shape.messageKey),
          (422, 'VALIDATION_ERROR', 'validation.invalid'));
      expect((shape.details!['errors'] as List), isNotEmpty);

      final missing = await h.fails('POST', '/cases/$caseId/boundary', token: gs, body: {});
      expect(missing.error, 'VALIDATION_ERROR');
      final source = await h.fails('POST', '/cases/$caseId/boundary',
          token: gs, body: {'polygon': _poly(_sq(73.2, 19.9)), 'source': 'dream'});
      expect(source.error, 'VALIDATION_ERROR');
    });

    test('landmarks: add, count per side, distance, errors, delete', () async {
      await save(breaks: [0, 1, 2, 3]);
      final lm = await h.call('POST', '/cases/$caseId/boundary/landmarks', token: gs, body: {
        'segment_seq': 0,
        'name': '  Nagdevta shrine ',
        'kind': 'sacred_place',
        'lat': 19.9,
        'lon': 73.205,
      });
      expect(lm['name'], 'Nagdevta shrine');
      expect(lm['kind'], 'sacred_place');
      expect(lm['segment_seq'], 0);
      expect(lm['lat'], 19.9);
      expect(lm['lon'], 73.205);
      expect(lm['distance_to_segment_m'], 0.0); // on the south side
      expect(lm['photo_media_id'], isNull);
      expect(lm['evidence_id'], isNull);

      final far = await h.call('POST', '/cases/$caseId/boundary/landmarks', token: gs, body: {
        'segment_seq': 1,
        'name': 'Stream',
        'kind': 'stream',
        'lat': 19.905,
        'lon': 73.2095, // 0.0005 degrees west of the east side: about 52 m
      });
      expect(far['distance_to_segment_m'], inInclusiveRange(50.0, 56.0));

      final b = await h.call('GET', '/cases/$caseId/boundary', token: gs);
      expect(b['segments_without_landmark'], 2);
      expect((b['segments'] as List).map((s) => s['landmark_count']), [1, 1, 0, 0]);
      expect((b['landmarks'] as List).map((l) => l['segment_seq']), [0, 1]);

      final noSide = await h.fails('POST', '/cases/$caseId/boundary/landmarks',
          token: gs,
          body: {'segment_seq': 4, 'name': 'X', 'kind': 'hill', 'lat': 19.9, 'lon': 73.2});
      expect((noSide.statusCode, noSide.error), (422, 'NO_SUCH_SEGMENT'));
      expect(noSide.details, {'segments': 4});
      final badKind = await h.fails('POST', '/cases/$caseId/boundary/landmarks',
          token: gs,
          body: {'segment_seq': 0, 'name': 'X', 'kind': 'castle', 'lat': 19.9, 'lon': 73.2});
      expect(badKind.error, 'VALIDATION_ERROR');
      final badLat = await h.fails('POST', '/cases/$caseId/boundary/landmarks',
          token: gs,
          body: {'segment_seq': 0, 'name': 'X', 'kind': 'hill', 'lat': 91, 'lon': 73.2});
      expect(badLat.error, 'VALIDATION_ERROR');
      final photo = await h.fails('POST', '/cases/$caseId/boundary/landmarks',
          token: gs,
          body: {
            'segment_seq': 0,
            'name': 'X',
            'kind': 'hill',
            'lat': 19.9,
            'lon': 73.2,
            'photo_media_id': '11111111-2222-4333-8444-555555555555',
          });
      expect((photo.statusCode, photo.error), (422, 'MEDIA_NOT_YOURS'));
      final evidence = await h.fails('POST', '/cases/$caseId/boundary/landmarks',
          token: gs,
          body: {
            'segment_seq': 0,
            'name': 'X',
            'kind': 'hill',
            'lat': 19.9,
            'lon': 73.2,
            'evidence_id': '11111111-2222-4333-8444-555555555555',
          });
      expect((evidence.statusCode, evidence.error), (422, 'EVIDENCE_NOT_IN_CASE'));

      expect(await h.call('DELETE', '/cases/$caseId/boundary/landmarks/${lm['id']}', token: gs), isNull);
      final gone = await h.fails('DELETE', '/cases/$caseId/boundary/landmarks/${lm['id']}', token: gs);
      expect((gone.statusCode, gone.error), (404, 'LANDMARK_NOT_FOUND'));
      final after = await h.call('GET', '/cases/$caseId/boundary', token: gs);
      expect(after['segments_without_landmark'], 3);
    });

    test('landmarks need a boundary first', () async {
      final e = await h.fails('POST', '/cases/$caseId/boundary/landmarks',
          token: gs,
          body: {'segment_seq': 0, 'name': 'X', 'kind': 'hill', 'lat': 19.9, 'lon': 73.2});
      expect((e.statusCode, e.error), (404, 'NO_BOUNDARY'));
    });

    test('use zones: inside, sticking out, never clipped; bad shapes; delete', () async {
      await save();
      final inside = await h.call('POST', '/cases/$caseId/boundary/use-zones', token: gs, body: {
        'use_type': 'grazing',
        'name': 'Gochar',
        'polygon': _poly(_sq(73.203, 19.903, 0.003)),
        'season': 'summer',
        'user_hamlets': ['Pada 1', ' Pada 2 '],
      });
      expect(inside['use_type'], 'grazing');
      expect(inside['within_boundary'], isTrue);
      expect(inside['user_hamlets'], ['Pada 1', 'Pada 2']);
      expect(inside['season'], 'summer');
      expect(double.parse(inside['area_ha'] as String), inInclusiveRange(10.0, 11.5));
      expect(inside['geometry']['type'], 'Polygon');

      final out = await h.call('POST', '/cases/$caseId/boundary/use-zones',
          token: gs, body: {'use_type': 'mfp', 'polygon': _poly(_sq(73.205, 19.905, 0.01))});
      expect(out['within_boundary'], isFalse);
      expect(out['name'], isNull);
      expect(out['user_hamlets'], isEmpty);

      final bow = await h.fails('POST', '/cases/$caseId/boundary/use-zones', token: gs, body: {
        'use_type': 'water',
        'polygon': _poly([
          [73.2, 19.9],
          [73.21, 19.91],
          [73.21, 19.9],
          [73.2, 19.91],
        ]),
      });
      expect((bow.statusCode, bow.error), (422, 'INVALID_GEOMETRY'));
      final badType = await h.fails('POST', '/cases/$caseId/boundary/use-zones',
          token: gs, body: {'use_type': 'mining', 'polygon': _poly(_sq(73.2, 19.9))});
      expect(badType.error, 'VALIDATION_ERROR');

      final b = await h.call('GET', '/cases/$caseId/boundary', token: gs);
      expect((b['use_zones'] as List).length, 2);
      expect(await h.call('DELETE', '/cases/$caseId/boundary/use-zones/${inside['id']}', token: gs), isNull);
      final gone = await h.fails('DELETE', '/cases/$caseId/boundary/use-zones/${inside['id']}', token: gs);
      expect((gone.statusCode, gone.error), (404, 'USE_ZONE_NOT_FOUND'));
    });

    test('a new version keeps the earlier ones and carries landmarks and zones over', () async {
      final v1 = await save(breaks: [0, 1, 2, 3]);
      for (final seq in [0, 3]) {
        await h.call('POST', '/cases/$caseId/boundary/landmarks', token: gs, body: {
          'segment_seq': seq,
          'name': 'L$seq',
          'kind': 'hill',
          'lat': 19.9,
          'lon': 73.2,
        });
      }
      await h.call('POST', '/cases/$caseId/boundary/use-zones',
          token: gs, body: {'use_type': 'fuelwood', 'polygon': _poly(_sq(73.203, 19.903, 0.002))});

      final v2 = await save(breaks: [0, 2], pts: _sq(73.2, 19.9, 0.012)); // two sides only
      expect(v2['version'], 2);
      expect(v2['id'], isNot(v1['id']));
      expect((v2['segments'] as List).length, 2);
      expect((v2['landmarks'] as List).map((l) => l['name']), ['L0']); // L3 lost its side
      expect((v2['use_zones'] as List).length, 1);
      expect(v2['segments_without_landmark'], 1);

      final versions = (await h.call('GET', '/cases/$caseId/boundary/versions', token: gs) as List).cast<Map>();
      expect(versions.map((v) => v['version']), [1, 2]);
      expect(versions.map((v) => v['is_current']), [false, true]);
      expect(versions.first.keys.toSet(),
          {'id', 'version', 'status', 'source', 'area_ha', 'is_current', 'created_at'});
      final current = await h.call('GET', '/cases/$caseId/boundary', token: gs);
      expect(current['id'], v2['id']);
    });

    test('the walk with the elders: record, list in order, the trace length', () async {
      final w = await h.call('POST', '/cases/$caseId/boundary/walks', token: gs, body: {
        'walked_on': '2026-10-10',
        'participants': [
          {'name': 'Ramu Bhoye'},
          {'name': 'Sita', 'role': 'frc'},
        ],
        'trace': {
          'type': 'LineString',
          'coordinates': [
            [73.2, 19.9],
            [73.21, 19.9],
          ],
        },
        'notes': 'Walked clockwise from the shrine.',
      });
      expect(w['walked_on'], '2026-10-10');
      expect((w['participants'] as List).map((p) => p['role']), ['elder', 'frc']);
      expect((w['participants'] as List).first['gs_member_id'], isNull);
      expect(w['trace_length_m'], closeTo(1047.5, 3));
      expect(w['trace']['type'], 'LineString');
      expect(w['notes'], 'Walked clockwise from the shrine.');

      await h.call('POST', '/cases/$caseId/boundary/walks', token: gs, body: {
        'walked_on': '2026-10-01',
        'participants': [
          {'name': 'Ramu Bhoye'},
        ],
      });
      final list = (await h.call('GET', '/cases/$caseId/boundary/walks', token: gs) as List).cast<Map>();
      expect(list.map((x) => x['walked_on']), ['2026-10-01', '2026-10-10']);
      expect(list.first['trace'], isNull);
      expect(list.first['trace_length_m'], isNull);
      expect(list.first['notes'], isNull);
    });

    test('walk: validation and the roster', () async {
      final none = await h.fails('POST', '/cases/$caseId/boundary/walks',
          token: gs, body: {'walked_on': '2026-10-10', 'participants': []});
      expect(none.error, 'VALIDATION_ERROR');
      final date = await h.fails('POST', '/cases/$caseId/boundary/walks', token: gs, body: {
        'walked_on': '10/10/2026',
        'participants': [
          {'name': 'A'},
        ],
      });
      expect(date.error, 'VALIDATION_ERROR');
      final role = await h.fails('POST', '/cases/$caseId/boundary/walks', token: gs, body: {
        'walked_on': '2026-10-10',
        'participants': [
          {'name': 'A', 'role': 'king'},
        ],
      });
      expect(role.error, 'VALIDATION_ERROR');
      final stranger = await h.fails('POST', '/cases/$caseId/boundary/walks', token: gs, body: {
        'walked_on': '2026-10-10',
        'participants': [
          {'name': 'A', 'gs_member_id': '11111111-2222-4333-8444-555555555555'},
        ],
      });
      expect((stranger.statusCode, stranger.error), (422, 'PARTICIPANT_NOT_IN_ROSTER'));
      final trace = await h.fails('POST', '/cases/$caseId/boundary/walks', token: gs, body: {
        'walked_on': '2026-10-10',
        'participants': [
          {'name': 'A'},
        ],
        'trace': {
          'type': 'LineString',
          'coordinates': [
            [73.2, 19.9],
            [200, 19.9],
          ],
        },
      });
      expect((trace.statusCode, trace.messageKey), (422, 'geo.out_of_range'));
    });

    test('who may map, and when', () async {
      // a villager who did not open the claim does not see it at all
      final hidden = await h.fails('GET', '/cases/$caseId/boundary', token: villager);
      expect((hidden.statusCode, hidden.error), (404, 'CASE_NOT_FOUND'));
      expect((await h.fails('GET', '/cases/$caseId/boundary')).statusCode, 401);

      // a village user's own claim: only they map it while it is a draft
      final mine = (await h.call('POST', '/villages/$_v/cases',
          token: villager, body: {'claim_type': 'cfr'}))['id'] as String;
      await save(token: villager, id: mine);
      final other = await h.login(_villager2);
      expect((await h.fails('GET', '/cases/$mine/boundary', token: other)).error, 'CASE_NOT_FOUND');
      // the Gram Sabha cannot see a draft of someone else
      expect((await h.fails('POST', '/cases/$mine/boundary',
              token: gs, body: {'polygon': _poly(_sq(73.2, 19.9))}))
          .error, 'CASE_NOT_FOUND');

      // filed: the claimant can no longer map it, the Gram Sabha can
      await h.call('POST', '/cases/$mine/submit', token: villager);
      final late = await h.fails('POST', '/cases/$mine/boundary',
          token: villager, body: {'polygon': _poly(_sq(73.2, 19.9))});
      expect((late.statusCode, late.error), (403, 'CANNOT_MAP_NOW'));
      expect(late.details, {'state': 'gs_review'});
      final byGs = await save(token: gs, id: mine, pts: _sq(73.2, 19.9, 0.011));
      expect(byGs['version'], 2);

      // reads stay open to the claimant
      final read = await h.call('GET', '/cases/$mine/boundary', token: villager);
      expect(read['version'], 2);
    });

    test('only a Form C claim has a boundary', () async {
      final ifr = (await h.call('POST', '/villages/$_v/cases',
          token: villager, body: {'claim_type': 'ifr'}))['id'] as String;
      final e = await h.fails('GET', '/cases/$ifr/boundary', token: villager);
      expect((e.statusCode, e.error, e.messageKey), (409, 'NOT_A_FORM_C_CASE', 'case.wrong_form'));
      final s = await h.fails('POST', '/cases/$ifr/boundary',
          token: villager, body: {'polygon': _poly(_sq(73.2, 19.9))});
      expect(s.error, 'NOT_A_FORM_C_CASE');
    });

    test('the conflict check is for the Gram Sabha; with no neighbour there is no dispute', () async {
      await save();
      expect(await h.call('POST', '/cases/$caseId/boundary/conflicts/check', token: gs), isEmpty);
      final mine = (await h.call('POST', '/villages/$_v/cases',
          token: villager, body: {'claim_type': 'cfr'}))['id'] as String;
      await save(token: villager, id: mine);
      final e = await h.fails('POST', '/cases/$mine/boundary/conflicts/check', token: villager);
      expect((e.statusCode, e.error), (403, 'NOT_YOUR_LEVEL'));
      final none = await h.fails('POST', '/cases/$caseId/boundary/conflicts/check', token: villager);
      expect(none.statusCode, 404);
    });
  });

  group('overlaps and disputes', () {
    late _Rig rig;
    late String gs;
    late String caseId;
    setUp(() async {
      rig = _Rig();
      gs = await rig.login(_gramSabha);
      caseId = (await rig.call('POST', '/villages/$_v/cases', token: gs, body: {'claim_type': 'cfr'}))['id']
          as String;
    });
    tearDown(() => rig.dispose());

    Future<Map<String, dynamic>> save(List<List<double>> pts) async => Map<String, dynamic>.from(
        await rig.call('POST', '/cases/$caseId/boundary', token: gs, body: {'polygon': _poly(pts)})
            as Map);

    Future<List<Map>> disputes() async =>
        (await rig.call('GET', '/cases/$caseId/disputes', token: gs) as List).cast<Map>();

    test('an overlap with a neighbouring village opens a dispute at once', () async {
      final n = rig.neighbour('a', _sq(73.205, 19.905));
      final b = await save(_sq(73.2, 19.9));
      expect(b['open_disputes'], 1);
      final list = await disputes();
      expect(list.length, 1);
      final d = list.single;
      expect(d['case_id'], caseId);
      expect(d['neighbour_case_id'], n);
      expect(d['neighbour_village'], 'वाडी a (Wadi a)');
      expect(d['is_open'], isTrue);
      expect(d['outcome'], isNull);
      expect(d['detected_on'], '2026-10-14');
      expect(d['joint_meeting_on'], isNull);
      expect(d['sdlc_referral_on'], isNull);
      expect(double.parse(d['overlap_ha'] as String), closeTo(double.parse(b['area_ha'] as String) / 4, 0.1));
      expect(d['overlap']['type'], 'Polygon');
      expect(d.keys.toSet(), {
        'id', 'case_id', 'neighbour_case_id', 'neighbour_village', 'overlap', 'overlap_ha',
        'detected_on', 'joint_meeting_on', 'joint_meeting_findings', 'joint_meeting_media_id',
        'outcome', 'sdlc_referral_on', 'sdlc_referral_ref', 'is_open', //
      });

      // saving again refreshes the one dispute instead of opening another
      await save(_sq(73.2, 19.9, 0.0105));
      expect((await disputes()).length, 1);
    });

    test('a neighbour whose claim is closed, or in the same Gram Sabha, is no dispute', () async {
      rig.neighbour('closed', _sq(73.205, 19.905), state: 'rejected');
      final b = await save(_sq(73.2, 19.9));
      expect(b['open_disputes'], 0);
      expect(await disputes(), isEmpty);
    });

    test('moving the boundary away empties the dispute; the check re-runs the test', () async {
      rig.neighbour('a', _sq(73.205, 19.905));
      await save(_sq(73.2, 19.9));
      final b = await save(_sq(73.3, 19.9)); // far away
      expect(b['open_disputes'], 0);
      final d = (await disputes()).single;
      expect(d['is_open'], isFalse);
      expect(d['overlap_ha'], '0.0000');
      expect(d['overlap'], isEmpty);

      // back to the neighbour: the same dispute opens again
      await save(_sq(73.2, 19.9));
      final checked = (await rig.call('POST', '/cases/$caseId/boundary/conflicts/check', token: gs) as List).cast<Map>();
      expect(checked.length, 1);
      expect(checked.single['is_open'], isTrue);
    });

    test('joint meeting, settled and referred states', () async {
      rig.neighbour('a', _sq(73.205, 19.905));
      rig.neighbour('b', _sq(73.195, 19.895));
      await save(_sq(73.2, 19.9));
      final list = await disputes();
      expect(list.length, 2);
      final a = list.first['id'];
      final b = list.last['id'];

      // dispute A: the meeting agrees to share; nothing is open and the SDLC is not needed
      final met = await rig.call('POST', '/cases/$caseId/disputes/$a/joint-meeting',
          token: gs,
          body: {'held_on': '2026-10-20', 'findings': 'Both villages use it together.', 'outcome': 'agreed_shared'});
      expect(met['outcome'], 'agreed_shared');
      expect(met['joint_meeting_on'], '2026-10-20');
      expect(met['joint_meeting_findings'], 'Both villages use it together.');
      expect(met['is_open'], isFalse);
      final settled = await rig.fails('POST', '/cases/$caseId/disputes/$a/sdlc-referral',
          token: gs, body: {'referred_on': '2026-10-21', 'ref': 'SDLC/1'});
      expect((settled.statusCode, settled.error, settled.messageKey),
          (409, 'DISPUTE_SETTLED', 'dispute.already_settled'));
      final again = await rig.fails('POST', '/cases/$caseId/disputes/$a/joint-meeting',
          token: gs, body: {'held_on': '2026-10-22', 'findings': 'Again', 'outcome': 'not_resolved'});
      expect(again.error, 'DISPUTE_SETTLED');
      expect((await rig.call('GET', '/cases/$caseId/boundary', token: gs))['open_disputes'], 1);

      // dispute B: no meeting and not yet 30 days: the SDLC is refused, with the date
      final early = await rig.fails('POST', '/cases/$caseId/disputes/$b/sdlc-referral',
          token: gs, body: {'referred_on': '2026-10-20', 'ref': 'SDLC/2'});
      expect((early.statusCode, early.error, early.rule, early.messageKey),
          (409, 'JOINT_MEETING_FIRST', 'Rule 12(3)', 'dispute.joint_meeting_first'));
      expect(early.details, {'earliest_without_meeting': '2026-11-13'});

      // a meeting that does not resolve it still leaves it open, and opens the way to the SDLC
      final failed = await rig.call('POST', '/cases/$caseId/disputes/$b/joint-meeting',
          token: gs, body: {'held_on': '2026-10-20', 'findings': 'No agreement.', 'outcome': 'not_resolved'});
      expect(failed['is_open'], isTrue);
      final referred = await rig.call('POST', '/cases/$caseId/disputes/$b/sdlc-referral',
          token: gs, body: {'referred_on': '2026-10-21', 'ref': ' SDLC/2 '});
      expect(referred['sdlc_referral_on'], '2026-10-21');
      expect(referred['sdlc_referral_ref'], 'SDLC/2');
      expect(referred['is_open'], isFalse);
      final done = await rig.fails('POST', '/cases/$caseId/disputes/$b/sdlc-referral',
          token: gs, body: {'referred_on': '2026-10-22', 'ref': 'x'});
      expect((done.statusCode, done.error), (409, 'DISPUTE_REFERRED'));
      expect((await rig.call('GET', '/cases/$caseId/boundary', token: gs))['open_disputes'], 0);
    });

    test('after 30 days without a meeting the SDLC may be asked', () async {
      rig.neighbour('a', _sq(73.205, 19.905));
      await save(_sq(73.2, 19.9));
      final id = (await disputes()).single['id'];
      final ok = await rig.call('POST', '/cases/$caseId/disputes/$id/sdlc-referral',
          token: gs, body: {'referred_on': '2026-11-13', 'ref': 'SDLC/9'});
      expect(ok['sdlc_referral_ref'], 'SDLC/9');
    });

    test('dispute actions: role, validation and unknown ids', () async {
      rig.neighbour('a', _sq(73.205, 19.905));
      await save(_sq(73.2, 19.9));
      final id = (await disputes()).single['id'];
      final bad = await rig.fails('POST', '/cases/$caseId/disputes/$id/joint-meeting',
          token: gs, body: {'held_on': '2026-10-20', 'findings': '', 'outcome': 'agreed_shared'});
      expect(bad.error, 'VALIDATION_ERROR');
      final badOutcome = await rig.fails('POST', '/cases/$caseId/disputes/$id/joint-meeting',
          token: gs, body: {'held_on': '2026-10-20', 'findings': 'ok', 'outcome': 'fight'});
      expect(badOutcome.error, 'VALIDATION_ERROR');
      final missing = await rig.fails('POST', '/cases/$caseId/disputes/nope/joint-meeting',
          token: gs, body: {'held_on': '2026-10-20', 'findings': 'ok', 'outcome': 'agreed_shared'});
      expect((missing.statusCode, missing.error), (404, 'DISPUTE_NOT_FOUND'));
      final media = await rig.fails('POST', '/cases/$caseId/disputes/$id/joint-meeting',
          token: gs,
          body: {
            'held_on': '2026-10-20',
            'findings': 'ok',
            'outcome': 'agreed_shared',
            'record_media_id': '11111111-2222-4333-8444-555555555555',
          });
      expect((media.statusCode, media.error), (422, 'MEDIA_NOT_YOURS'));
      final noRef = await rig.fails('POST', '/cases/$caseId/disputes/$id/sdlc-referral',
          token: gs, body: {'referred_on': '2026-11-20'});
      expect(noRef.error, 'VALIDATION_ERROR');
    });

    test('the neighbour sees the same dispute from its side', () async {
      final n = rig.neighbour('a', _sq(73.205, 19.905));
      await save(_sq(73.2, 19.9));
      final nb = (rig.table('dispute').single);
      expect(nb['neighbour_case_id'], n);
      // a closed claim closes the dispute
      rig.table('claim_case').firstWhere((c) => c['id'] == n)['state'] = 'rejected';
      final d = (await disputes()).single;
      expect(d['is_open'], isFalse);
      expect((await rig.call('GET', '/cases/$caseId/boundary', token: gs))['open_disputes'], 0);
    });

    test('a frozen boundary is not edited', () async {
      await save(_sq(73.2, 19.9));
      rig.table('cfr_boundary').last['status'] = 'gs_approved';
      final e = await rig.fails('POST', '/cases/$caseId/boundary/landmarks',
          token: gs,
          body: {'segment_seq': 0, 'name': 'X', 'kind': 'hill', 'lat': 19.9, 'lon': 73.2});
      expect((e.statusCode, e.error), (409, 'BOUNDARY_FROZEN'));
      expect(e.details, {'status': 'gs_approved'});
      final z = await rig.fails('POST', '/cases/$caseId/boundary/use-zones',
          token: gs, body: {'use_type': 'grazing', 'polygon': _poly(_sq(73.201, 19.901, 0.001))});
      expect(z.error, 'BOUNDARY_FROZEN');
      // a new version after approval does not carry the old landmarks and starts as a draft
      final v2 = await save(_sq(73.2, 19.9));
      expect(v2['version'], 2);
      expect(v2['status'], 'draft');
    });
  });

  group('notifications and devices', () {
    late _Rig rig;
    late String villager;
    late String villager2;
    setUp(() async {
      rig = _Rig();
      villager = await rig.login(_villager);
      villager2 = await rig.login(_villager2);
    });
    tearDown(() => rig.dispose());

    void message(String id, String user, String at, {String? readAt, String? caseId}) {
      rig.table('notification').add(<String, dynamic>{
        'id': id,
        'user_id': user,
        'case_id': caseId,
        'kind': 'claim_expired',
        'title_en': 'Title $id',
        'body_en': 'Body $id',
        'title_mr': 'शीर्षक $id',
        'body_mr': 'मजकूर $id',
        'created_at': at,
        'read_at': readAt,
      });
    }

    test('the list is newest first with the unread count, and is private', () async {
      expect(await rig.call('GET', '/notifications', token: villager), {'unread': 0, 'items': []});
      final u1 = DemoAccounts.userIdFor(1);
      final u2 = DemoAccounts.userIdFor(2);
      message('m1', u1, '2026-10-01T06:00:00.000Z');
      message('m2', u1, '2026-10-03T06:00:00.000Z', readAt: '2026-10-04T06:00:00.000Z');
      message('m3', u1, '2026-10-02T06:00:00.000Z', caseId: 'c1');
      message('m4', u2, '2026-10-05T06:00:00.000Z');
      final page = await rig.call('GET', '/notifications', token: villager) as Map;
      expect(page['unread'], 2);
      final items = (page['items'] as List).cast<Map>();
      expect(items.map((i) => i['id']), ['m2', 'm3', 'm1']);
      expect(items.map((i) => i['read']), [true, false, false]);
      expect(items[1]['case_id'], 'c1');
      expect(items.first.keys.toSet(),
          {'id', 'case_id', 'kind', 'title_en', 'body_en', 'title_mr', 'body_mr', 'created_at', 'read'});
      expect((await rig.call('GET', '/notifications', token: villager2) as Map)['unread'], 1);
      expect((await rig.fails('GET', '/notifications')).statusCode, 401);
    });

    test('read one, and a message of someone else is not found', () async {
      message('m1', DemoAccounts.userIdFor(1), '2026-10-01T06:00:00.000Z');
      message('m4', DemoAccounts.userIdFor(2), '2026-10-05T06:00:00.000Z');
      final n = await rig.call('POST', '/notifications/m1/read', token: villager) as Map;
      expect(n['read'], isTrue);
      expect(rig.table('notification').first['read_at'], isNotNull);
      expect((await rig.call('GET', '/notifications', token: villager) as Map)['unread'], 0);
      // reading twice keeps the first time
      final first = rig.table('notification').first['read_at'];
      rig.now = rig.now.add(const Duration(hours: 1));
      await rig.call('POST', '/notifications/m1/read', token: villager);
      expect(rig.table('notification').first['read_at'], first);
      final other = await rig.fails('POST', '/notifications/m4/read', token: villager);
      expect((other.statusCode, other.error, other.messageKey),
          (404, 'NOTIFICATION_NOT_FOUND', 'notification.not_found'));
      expect((await rig.fails('POST', '/notifications/nope/read', token: villager)).statusCode, 404);
    });

    test('read all returns the new page', () async {
      message('m1', DemoAccounts.userIdFor(1), '2026-10-01T06:00:00.000Z');
      message('m2', DemoAccounts.userIdFor(1), '2026-10-02T06:00:00.000Z');
      message('m4', DemoAccounts.userIdFor(2), '2026-10-05T06:00:00.000Z');
      final page = await rig.call('POST', '/notifications/read-all', token: villager) as Map;
      expect(page['unread'], 0);
      expect((page['items'] as List).every((i) => i['read'] == true), isTrue);
      expect((await rig.call('GET', '/notifications', token: villager2) as Map)['unread'], 1);
    });

    test('at most 100 are listed', () async {
      for (var i = 0; i < 105; i++) {
        message('n$i', DemoAccounts.userIdFor(1), '2026-10-01T06:${(i ~/ 60).toString().padLeft(2, '0')}:${(i % 60).toString().padLeft(2, '0')}.000Z');
      }
      final page = await rig.call('GET', '/notifications', token: villager) as Map;
      expect(page['unread'], 105);
      expect((page['items'] as List).length, 100);
      expect(((page['items'] as List).first as Map)['id'], 'n104');
    });

    test('a phone registers, is refreshed, moves to the next user, and is removed', () async {
      const token = 'fcm-token-aaaaaaaaaaaaaaaaaaaa';
      final out = await rig.call('POST', '/devices',
          token: villager, body: {'token': token, 'platform': 'android', 'language': 'en'});
      expect(out, {'token': token, 'platform': 'android', 'language': 'en'});
      expect(rig.table('device_token').single['user_id'], DemoAccounts.userIdFor(1));

      final defaults = await rig.call('POST', '/devices', token: villager, body: {'token': '  $token  '});
      expect(defaults, {'token': token, 'platform': 'android', 'language': 'mr'});
      expect(rig.table('device_token').length, 1);

      await rig.call('POST', '/devices', token: villager2, body: {'token': token, 'platform': 'ios'});
      expect(rig.table('device_token').single['user_id'], DemoAccounts.userIdFor(2));
      expect(rig.table('device_token').single['platform'], 'ios');

      // not the owner: ignored
      expect(await rig.call('DELETE', '/devices/$token', token: villager), isNull);
      expect(rig.table('device_token').length, 1);
      expect(await rig.call('DELETE', '/devices/$token', token: villager2), isNull);
      expect(rig.table('device_token'), isEmpty);
      // unknown tokens are ignored
      expect(await rig.call('DELETE', '/devices/unknown-token', token: villager2), isNull);
    });

    test('a device needs a real token, a known platform and language, and sign-in', () async {
      for (final body in [
        {'token': 'short'},
        {'token': 'fcm-token-aaaaaaaaaaaaaaaaaaaa', 'platform': 'palm'},
        {'token': 'fcm-token-aaaaaaaaaaaaaaaaaaaa', 'language': 'fr'},
        <String, dynamic>{},
      ]) {
        final e = await rig.fails('POST', '/devices', token: villager, body: body);
        expect((e.statusCode, e.error), (422, 'VALIDATION_ERROR'), reason: '$body');
      }
      expect((await rig.fails('POST', '/devices', body: {'token': 'fcm-token-aaaaaaaaaaaaaaaaaaaa'})).statusCode, 401);
      expect((await rig.fails('DELETE', '/devices/x')).statusCode, 401);
    });
  });

  group('title draft', () {
    late _Rig rig;
    late String villager;
    late String gs;
    late String sdo;
    late List<Map<String, dynamic>> Function(DemoDb, Map<String, dynamic>) savedHook;
    setUp(() async {
      rig = _Rig();
      villager = await rig.login(_villager);
      gs = await rig.login(_gramSabha);
      sdo = await rig.login(_sdo);
      savedHook = DemoHooks.approvalMissing;
      DemoHooks.approvalMissing = (_, __) => const [];
    });
    tearDown(() {
      DemoHooks.approvalMissing = savedHook;
      rig.dispose();
    });

    Future<String> newCase(String token, String type) async =>
        (await rig.call('POST', '/villages/$_v/cases', token: token, body: {'claim_type': type}))['id']
            as String;

    Map<String, dynamic> row(String id) => rig.table('claim_case').firstWhere((c) => c['id'] == id);

    Future<void> toDistrict(String id, String filer) async {
      await rig.call('POST', '/cases/$id/submit', token: filer);
      await rig.call('POST', '/cases/$id/approve', token: gs);
      await rig.call('POST', '/cases/$id/approve', token: sdo);
    }

    test('not before the district stage (409), then Annexure IV for Form C', () async {
      final id = await newCase(gs, 'cfr');
      row(id)['form_c'] = <String, dynamic>{
        'resolution_statement': 'We resolve.',
        'area_description': 'From the river to the hill',
        'khasra_compartment_numbers': ['12', '14/2'],
        'landmarks': [
          {'seq': 2, 'side': 'north', 'kind': 'hill', 'name': 'Dongar'},
          {'seq': 1, 'side': 'east', 'kind': 'river', 'name': 'Vaitarna'},
          {'seq': 3, 'side': 'east', 'kind': 'stream', 'name': 'Nala'},
        ],
      };
      for (var step = 0; step < 3; step++) {
        final e = await rig.fails('GET', '/cases/$id/title-draft', token: gs);
        expect((e.statusCode, e.error, e.messageKey), (409, 'TITLE_NOT_AVAILABLE', 'title.not_available'));
        expect(e.details, {'state': ['draft', 'gs_review', 'sdo_review'][step]});
        if (step == 0) await rig.call('POST', '/cases/$id/submit', token: gs);
        if (step == 1) await rig.call('POST', '/cases/$id/approve', token: gs);
      }
      await rig.call('POST', '/cases/$id/approve', token: sdo);

      final t = await rig.call('GET', '/cases/$id/title-draft', token: gs) as Map;
      expect(t.keys.toSet(), {'case_id', 'annexure', 'title', 'status', 'fields', 'declaration', 'signatories', 'note'});
      expect(t['case_id'], id);
      expect(t['annexure'], 'Annexure IV [Rule 8(i)]');
      expect(t['title'], 'Title to Community Forest Resources');
      expect(t['status'], 'draft (to be signed by the district committee)');
      final f = t['fields'] as Map;
      expect(f.keys.toList(), [
        '1_village_gram_sabha', '2_gram_panchayat', '3_tehsil_taluka', '4_district',
        '5_st_otfd_or_both', '6_boundary_description', //
      ]);
      expect(f['1_village_gram_sabha'], 'ओझर (Ozhar)');
      expect(f['3_tehsil_taluka'], 'Jawhar');
      expect(f['4_district'], 'Palghar');
      expect(f['5_st_otfd_or_both'], 'Scheduled Tribe and Other Traditional Forest Dweller');
      final b = f['6_boundary_description'] as Map;
      expect(b['customary_boundary'], 'From the river to the hill');
      expect(b['khasra_compartment_numbers'], ['12', '14/2']);
      expect(b['prominent_landmarks'], {
        'east': ['Vaitarna', 'Nala'],
        'west': [],
        'north': ['Dongar'],
        'south': [],
        'within': [],
      });
      expect((t['signatories'] as List).length, 3);
      expect((t['signatories'] as List).first,
          {'designation': 'Tribal Welfare Divisional Officer (TWDO)', 'role': null, 'name': null, 'signed_at': null});
      expect(t['note'], startsWith('Title draft prepared with VanMitra'));
      expect(t['declaration'], contains('Gram Sabha'));

      // the claimant sees it too; a village user who is not involved does not
      expect((await rig.call('GET', '/cases/$id/title-draft', token: sdo) as Map)['annexure'], isNotNull);
      expect((await rig.fails('GET', '/cases/$id/title-draft', token: villager)).statusCode, 404);
      expect((await rig.fails('GET', '/cases/$id/title-draft')).statusCode, 401);
    });

    test('Annexure II for Form A', () async {
      final id = await newCase(villager, 'ifr');
      row(id)['form_a'] = <String, dynamic>{
        'claimant_names': ['Ramu Bhoye'],
        'spouse_name': 'Sita Bhoye',
        'father_mother_name': 'Gopal Bhoye',
        'address': 'Ozhar pada',
        'is_scheduled_tribe': true,
        'is_otfd': false,
        'family_members': [
          {'seq': 2, 'name': 'Meena'},
          {'seq': 1, 'name': 'Raju', 'age': 7},
        ],
        'claims': [
          {'claim_code': 'habitation', 'extent_ha': 0.5, 'details': 'House and yard'},
          {'claim_code': 'self_cultivation', 'extent_ha': '0.75', 'details': 'Rice plot'},
          {'claim_code': 'other_traditional', 'details': 'Fishing'},
        ],
      };
      await toDistrict(id, villager);
      final t = await rig.call('GET', '/cases/$id/title-draft', token: villager) as Map;
      expect(t['annexure'], 'Annexure II [Rule 8(h)]');
      expect(t['title'], 'Title for forest land under occupation');
      final f = t['fields'] as Map;
      expect(f['1_holders_including_spouse'], ['Ramu Bhoye', 'Sita Bhoye']);
      expect(f['2_father_mother'], 'Gopal Bhoye');
      expect(f['3_dependents'], ['Raju (7)', 'Meena']);
      expect(f['4_address'], 'Ozhar pada');
      expect(f['5_village_gram_sabha'], 'ओझर (Ozhar)');
      expect(f['6_gram_panchayat'], 'Ozhar');
      expect(f['9_st_or_otfd'], 'Scheduled Tribe');
      expect(f['10_area_ha'], 1.25);
      expect(f['11_boundaries'], [
        'Extent of forest land occupied: for habitation: House and yard',
        'Extent of forest land occupied: for self-cultivation, if any: Rice plot',
        'Any other traditional right, if any: Fishing',
      ]);
      expect(t['declaration'], contains('heritable, but not alienable'));
      expect(t['declaration'], contains('Government of Maharashtra'));
    });

    test('Annexure III for Form B; an empty form says "not stated" instead of failing', () async {
      final id = await newCase(villager, 'cr');
      row(id)['form_b'] = <String, dynamic>{
        'claimant_names': ['Ozhar Gram Sabha'],
        'is_fdst_community': true,
        'is_otfd_community': true,
        'rights': [
          {
            'right_code': 'nistar',
            'details': 'Wood for houses',
            'survey_compartment_numbers': ['5'],
            'total_area_ha': 12.5,
            'boundary_east': 'River',
          },
          {'right_code': 'grazing', 'details': 'Cattle'},
        ],
      };
      await toDistrict(id, villager);
      final t = await rig.call('GET', '/cases/$id/title-draft', token: villager) as Map;
      expect(t['annexure'], 'Annexure III [Rule 8(h)]');
      final f = t['fields'] as Map;
      expect(f['1_holders'], ['Ozhar Gram Sabha']);
      expect(f['6_st_or_otfd'], 'Scheduled Tribe and Other Traditional Forest Dweller');
      expect(f['7_nature_of_community_rights'], [
        'Community rights such as nistar, if any [Section 3(1)(b)]: Wood for houses',
        'Community rights: grazing, if any [Section 3(1)(d)]: Cattle',
      ]);
      expect(f['8_conditions'], 'None beyond those in the Act and the Rules');
      expect(f['9_boundaries'], [
        {
          'right': 'Community rights such as nistar, if any',
          'survey_compartment_numbers': ['5'],
          'area_ha': 12.5,
          'east': 'River',
          'west': null,
          'north': null,
          'south': null,
        },
      ]);

      final bare = await newCase(villager, 'cr');
      await toDistrict(bare, villager);
      final tb = await rig.call('GET', '/cases/$bare/title-draft', token: villager) as Map;
      final fb = tb['fields'] as Map;
      expect(fb['6_st_or_otfd'], 'Not stated');
      expect(fb['7_nature_of_community_rights'], isEmpty);
      expect(fb['9_boundaries'], 'As described in the claim and the Gram Sabha resolution');
    });

    test('a case that is a draft or rejected has no title', () async {
      final id = await newCase(villager, 'ifr');
      expect((await rig.fails('GET', '/cases/$id/title-draft', token: villager)).error, 'TITLE_NOT_AVAILABLE');
      await rig.call('POST', '/cases/$id/submit', token: villager);
      await rig.call('POST', '/cases/$id/reject', token: gs, body: {'remarks': 'Not eligible at all'});
      final e = await rig.fails('GET', '/cases/$id/title-draft', token: villager);
      expect(e.statusCode, 409);
      expect(e.details, {'state': 'rejected'});
    });
  });
}
