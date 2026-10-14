import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/demo_cases.dart';
import '../core/demo_core.dart';
import 'demo_geo.dart';
import 'demo_input.dart';

/// Boundary mapping for a claim: versions with segments, landmarks per segment, customary use
/// zones, the boundary walk with the elders, overlaps with neighbouring claims and the disputes
/// they open (backend api/v1/boundary.py, services/boundary.py, schemas/boundary.py).
///
/// Tables (the Python models' COLLECTION names and field names):
///  * `cfr_boundary`: one row per version of a case's boundary, with its `segments`, `landmarks`
///    and `use_zones` embedded; areas are numbers (hectares, 4 places) and dates `YYYY-MM-DD`;
///  * `boundary_walk`, `dispute`.
/// Answers carry the backend's `Decimal` areas as strings, like Pydantic does ("12.3457").
///
/// Other slices may use [currentBoundary], [segmentsWithoutLandmark], [openDisputes],
/// [disputeIsOpen] and [seal].
class DemoBoundary {
  DemoBoundary._();

  static const double gpsLimitM = 15.0; // B-14
  static const double minOverlapHa = 0.0001; // 1 m2: below this it is GPS noise along an edge
  static const int jointSolutionDays = 30; // time for a mutual solution before the SDLC [Rule 14(7)]
  static const Set<String> closedStates = {CaseStates.rejected, CaseStates.expired};

  static const Set<String> landmarkKinds = {
    'river', 'stream', 'spring', 'pond', 'sacred_place', 'sacred_grove', 'burial_ground', //
    'well', 'road', 'compartment_pillar', 'hill', 'other',
  };
  static const Set<String> useZoneTypes = {
    'grazing', 'mfp', 'water', 'fishing', 'fuelwood', 'sacred', 'shifting_cultivation', //
    'habitat', 'other',
  };
  static const Set<String> outcomes = {'agreed_shared', 'agreed_adjusted', 'not_resolved'};
  static const Set<String> sources = {'gps_walk', 'sketch_digitised', 'imported'};
  static const Set<String> participantRoles = {'elder', 'frc', 'member', 'other'};

  // ── small helpers ───────────────────────────────────────────────────────────

  /// Hectares as the backend sends a Decimal with 4 places.
  static String dec4(num v) => v.toDouble().toStringAsFixed(4);

  static List<T> _stable<T>(Iterable<T> items, int Function(T, T) compare) {
    final indexed = [for (var i = 0; i < items.length; i++) (i, items.elementAt(i))];
    indexed.sort((a, b) {
      final c = compare(a.$2, b.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  static DemoError _geoError(GeoError e) =>
      DemoError(422, 'INVALID_GEOMETRY', e.key, details: {'reason': e.detail});

  static List<Map<String, dynamic>> _list(Map<String, dynamic> b, String key) =>
      ((b[key] as List?) ?? const []).cast<Map<String, dynamic>>();

  // ── the boundary of a case ──────────────────────────────────────────────────

  /// The current version of the case's boundary, or null.
  static Map<String, dynamic>? currentBoundary(DemoDb db, String caseId) => db.findOne(
        'cfr_boundary',
        (b) => b['case_id'] == caseId && b['is_current'] == true,
      );

  /// How many sides still have no landmark (BR-08).
  static int segmentsWithoutLandmark(Map<String, dynamic> b) {
    final marked = {for (final lm in _list(b, 'landmarks')) lm['segment_seq']};
    return _list(b, 'segments').where((s) => !marked.contains(s['seq'])).length;
  }

  /// Freeze the version the Gram Sabha approved: a hash of its geometry and landmarks.
  static void seal(Map<String, dynamic> b, String today) {
    final marks = _stable(
      _list(b, 'landmarks'),
      (x, y) {
        final c = (x['segment_seq'] as int).compareTo(y['segment_seq'] as int);
        return c != 0 ? c : (x['name'] as String).compareTo(y['name'] as String);
      },
    );
    final payload = _canonicalJson([
      b['geom'],
      [
        for (final lm in marks) [lm['segment_seq'], lm['name'], lm['point']],
      ],
    ]);
    b['sealed_hash'] = sha256.convert(utf8.encode(payload)).toString();
    b['status'] = 'gs_approved';
    b['approved_on'] = today;
  }

  /// `json.dumps(x, separators=(",", ":"), sort_keys=True)` (non-ASCII escaped).
  static String _canonicalJson(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      return '{${keys.map((k) => '${_canonicalJson(k)}:${_canonicalJson(v[k])}').join(',')}}';
    }
    if (v is List) return '[${v.map(_canonicalJson).join(',')}]';
    if (v is String) {
      final sb = StringBuffer('"');
      for (final u in v.codeUnits) {
        if (u == 0x22) {
          sb.write(r'\"');
        } else if (u == 0x5c) {
          sb.write(r'\\');
        } else if (u == 0x0a) {
          sb.write(r'\n');
        } else if (u == 0x0d) {
          sb.write(r'\r');
        } else if (u == 0x09) {
          sb.write(r'\t');
        } else if (u < 0x20 || u > 0x7e) {
          sb.write('\\u${u.toRadixString(16).padLeft(4, '0')}');
        } else {
          sb.writeCharCode(u);
        }
      }
      return (sb..write('"')).toString();
    }
    if (v == null) return 'null';
    return '$v';
  }

  // ── output ──────────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> segmentsOut(Map<String, dynamic> b) {
    final counts = <int, int>{};
    for (final lm in _list(b, 'landmarks')) {
      counts[lm['segment_seq'] as int] = (counts[lm['segment_seq'] as int] ?? 0) + 1;
    }
    return [
      for (final s in _stable(_list(b, 'segments'), (x, y) => (x['seq'] as int).compareTo(y['seq'] as int)))
        {
          'seq': s['seq'],
          'geometry': s['geom'],
          'length_m': s['length_m'],
          'landmark_count': counts[s['seq']] ?? 0,
        },
    ];
  }

  static Map<String, dynamic> landmarkOut(Map<String, dynamic> b, Map<String, dynamic> lm) {
    Map<String, dynamic>? seg;
    for (final s in _list(b, 'segments')) {
      if (s['seq'] == lm['segment_seq']) seg = s;
    }
    final coords = (lm['point'] as Map)['coordinates'] as List;
    final lon = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();
    var dist = 0.0;
    if (seg != null) {
      dist = roundTo(
        distanceToLineM((lon, lat), lineFromJson((seg['geom'] as Map).cast<String, dynamic>())),
        1,
      );
    }
    return {
      'id': lm['id'],
      'segment_seq': lm['segment_seq'],
      'name': lm['name'],
      'kind': lm['kind'],
      'lon': lon,
      'lat': lat,
      'distance_to_segment_m': dist,
      'photo_media_id': lm['photo_media_id'],
      'evidence_id': lm['evidence_id'],
    };
  }

  static List<Map<String, dynamic>> landmarksOut(Map<String, dynamic> b) => [
        for (final lm in _stable(_list(b, 'landmarks'), (x, y) {
          final c = (x['segment_seq'] as int).compareTo(y['segment_seq'] as int);
          return c != 0 ? c : '${x['created_at']}'.compareTo('${y['created_at']}');
        }))
          landmarkOut(b, lm),
      ];

  static Map<String, dynamic> useZoneOut(Map<String, dynamic> b, Map<String, dynamic> z) {
    final boundary = polygonRings((b['geom'] as Map).cast<String, dynamic>());
    final zone = polygonRings((z['geom'] as Map).cast<String, dynamic>());
    return {
      'id': z['id'],
      'use_type': z['use_type'],
      'name': z['name'],
      'geometry': z['geom'],
      'area_ha': dec4(z['area_ha'] as num),
      'season': z['season'],
      'user_hamlets': List<dynamic>.from((z['user_hamlets'] as List?) ?? const []),
      'within_boundary': polygonCovers(boundary, zone),
    };
  }

  static List<Map<String, dynamic>> useZonesOut(Map<String, dynamic> b) => [
        for (final z in _stable(_list(b, 'use_zones'), (x, y) => '${x['created_at']}'.compareTo('${y['created_at']}')))
          useZoneOut(b, z),
      ];

  /// The backend's `BoundaryOut`.
  static Map<String, dynamic> boundaryOut(DemoDb db, Map<String, dynamic> b) => {
        'id': b['id'],
        'case_id': b['case_id'],
        'version': b['version'],
        'status': b['status'],
        'source': b['source'],
        'geometry': b['geom'],
        'area_ha': dec4(b['area_ha'] as num),
        'accuracy_stats': b['accuracy_stats'],
        'sealed_hash': b['sealed_hash'],
        'approved_on': b['approved_on'],
        'segments': segmentsOut(b),
        'landmarks': landmarksOut(b),
        'use_zones': useZonesOut(b),
        'segments_without_landmark': segmentsWithoutLandmark(b),
        'open_disputes': openDisputes(db, b['case_id'] as String),
        'created_at': b['created_at'],
      };

  // ── disputes ────────────────────────────────────────────────────────────────

  /// Open while the claims still overlap and neither BR-09 exit is on record.
  static bool disputeIsOpen(Map<String, dynamic> d) {
    if (d['sdlc_referral_on'] != null || (d['overlap_ha'] as num) <= 0) return false;
    return d['outcome'] == null || d['outcome'] == 'not_resolved';
  }

  static List<Map<String, dynamic>> _disputesOf(DemoDb db, String caseId) => db.where(
        'dispute',
        (d) => d['case_id'] == caseId || d['neighbour_case_id'] == caseId,
      );

  /// Open overlaps of this claim with a neighbour's claim that still stands.
  static int openDisputes(DemoDb db, String caseId) {
    var count = 0;
    for (final d in _disputesOf(db, caseId)) {
      if (!disputeIsOpen(d)) continue;
      final c1 = db.byId('claim_case', d['case_id'] as String?);
      final c2 = db.byId('claim_case', d['neighbour_case_id'] as String?);
      if (c1 != null && !closedStates.contains(c1['state']) && c2 != null && !closedStates.contains(c2['state'])) {
        count++;
      }
    }
    return count;
  }

  /// Compare the boundary with every current CFR boundary of another Gram Sabha. Each overlap
  /// opens (or refreshes) a dispute; open disputes whose overlap has gone are emptied. Settled
  /// disputes are left as they were.
  static void detectOverlaps(DemoDb db, Map<String, dynamic> theCase, Map<String, dynamic> boundary) {
    final today = db.todayIst();
    final mine = polygonRings((boundary['geom'] as Map).cast<String, dynamic>());
    final overlapping = <String>{};

    final others = db.where(
      'cfr_boundary',
      (o) => o['is_current'] == true && o['case_id'] != theCase['id'],
    );
    for (final other in others) {
      final otherCase = db.byId('claim_case', other['case_id'] as String?);
      if (otherCase == null) continue;
      if (otherCase['claim_type'] != ClaimTypes.cfr) continue;
      if (closedStates.contains(otherCase['state'])) continue;
      if (otherCase['gram_sabha_id'] == theCase['gram_sabha_id']) continue;

      final ov = overlapOf(mine, polygonRings((other['geom'] as Map).cast<String, dynamic>()));
      if (ov == null || ov.ha < minOverlapHa) continue;

      overlapping.add(otherCase['id'] as String);
      final existing = db.findOne(
        'dispute',
        (d) =>
            (d['case_id'] == theCase['id'] && d['neighbour_case_id'] == otherCase['id']) ||
            (d['case_id'] == otherCase['id'] && d['neighbour_case_id'] == theCase['id']),
      );
      if (existing == null) {
        db.add('dispute', {
          'case_id': theCase['id'],
          'neighbour_case_id': otherCase['id'],
          'neighbour_gram_sabha_id': otherCase['gram_sabha_id'],
          'overlap_geom': ov.geojson,
          'overlap_ha': ov.ha,
          'detected_on': today,
          'joint_meeting_on': null,
          'joint_meeting_findings': null,
          'joint_meeting_media_id': null,
          'outcome': null,
          'sdlc_referral_on': null,
          'sdlc_referral_ref': null,
        });
      } else if (existing['sdlc_referral_on'] == null &&
          (existing['outcome'] == null || existing['outcome'] == 'not_resolved')) {
        existing['overlap_geom'] = ov.geojson;
        existing['overlap_ha'] = ov.ha;
      }
    }

    for (final d in _disputesOf(db, theCase['id'] as String)) {
      if (!disputeIsOpen(d)) continue;
      final otherId = d['case_id'] == theCase['id'] ? d['neighbour_case_id'] : d['case_id'];
      if (!overlapping.contains(otherId)) {
        d['overlap_geom'] = null;
        d['overlap_ha'] = 0.0;
      }
    }
  }

  static Map<String, dynamic> _disputeOut(DemoDb db, String caseId, Map<String, dynamic> d, bool thisClosed) {
    final neighbourId = (d['case_id'] == caseId ? d['neighbour_case_id'] : d['case_id']) as String;
    final neighbour = db.byId('claim_case', neighbourId);
    final neighbourClosed = neighbour != null && closedStates.contains(neighbour['state']);
    var village = '';
    if (neighbour != null) {
      final gs = db.byId('gram_sabha', neighbour['gram_sabha_id'] as String?);
      final v = gs == null ? null : db.byId('village', gs['village_id'] as String?);
      if (v != null) village = '${v['name_mr']} (${v['name_en']})';
    }
    return {
      'id': d['id'],
      'case_id': caseId,
      'neighbour_case_id': neighbourId,
      'neighbour_village': village,
      'overlap': d['overlap_geom'] ?? <String, dynamic>{},
      'overlap_ha': dec4(d['overlap_ha'] as num),
      'detected_on': d['detected_on'],
      'joint_meeting_on': d['joint_meeting_on'],
      'joint_meeting_findings': d['joint_meeting_findings'],
      'joint_meeting_media_id': d['joint_meeting_media_id'],
      'outcome': d['outcome'],
      'sdlc_referral_on': d['sdlc_referral_on'],
      'sdlc_referral_ref': d['sdlc_referral_ref'],
      'is_open': disputeIsOpen(d) && !(thisClosed || neighbourClosed),
    };
  }

  /// The backend's list of `DisputeOut` for a case, oldest first.
  static List<Map<String, dynamic>> disputesOut(DemoDb db, String caseId) {
    final thisCase = db.byId('claim_case', caseId);
    final thisClosed = thisCase != null && closedStates.contains(thisCase['state']);
    return [
      for (final d in _stable(_disputesOf(db, caseId), (x, y) => '${x['created_at']}'.compareTo('${y['created_at']}')))
        _disputeOut(db, caseId, d, thisClosed),
    ];
  }

  // ── guards ──────────────────────────────────────────────────────────────────

  /// Claimant (the Gram Sabha) while drafting; the Gram Sabha while it reviews.
  static void _ensureCanMap(CaseCtx ctx) {
    DemoCases.ensureClaimType(ctx, ClaimTypes.cfr, 'NOT_A_FORM_C_CASE');
    final state = ctx.state;
    if (state == CaseStates.draft && ctx.isCreator) return;
    if (state == CaseStates.gsReview && ctx.roles.contains(Roles.gramSabha)) return;
    throw DemoError(403, 'CANNOT_MAP_NOW', 'boundary.cannot_map_now', details: {'state': state});
  }

  static Map<String, dynamic> _currentOr404(DemoDb db, CaseCtx ctx) {
    final b = currentBoundary(db, ctx.theCase['id'] as String);
    if (b == null) throw DemoError(404, 'NO_BOUNDARY', 'boundary.none');
    return b;
  }

  static Map<String, dynamic> _editable(DemoDb db, CaseCtx ctx) {
    _ensureCanMap(ctx);
    final b = _currentOr404(db, ctx);
    if (b['status'] != 'draft') {
      throw DemoError(409, 'BOUNDARY_FROZEN', 'boundary.frozen', details: {'status': b['status']});
    }
    return b;
  }

  /// A polygon from GeoJSON numbers: closed rings, checked for validity.
  static (Map<String, dynamic>, List<Ring>) _polygon(List<List<List<num>>> coords) {
    try {
      final rings = [for (final r in coords) ring(r)];
      final reason = explainInvalid(rings);
      if (reason != null) throw GeoError('geo.invalid_polygon', reason);
      return ({'type': 'Polygon', 'coordinates': [for (final r in rings) ringJson(r)]}, rings);
    } on GeoError catch (e) {
      throw _geoError(e);
    }
  }

  static void _ownMedia(DemoDb db, Principal p, String? mediaId) {
    if (mediaId == null) return;
    final media = db.byId('media', mediaId);
    if (media == null || media['uploaded_by_user_id'] != p.userId) {
      throw DemoError(422, 'MEDIA_NOT_YOURS', 'evidence.media_not_yours', details: {'media_id': mediaId});
    }
  }

  // ── routes ──────────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    // Save the mapped boundary as a new version (previous versions are kept). Landmarks and use
    // zones of the previous draft carry over where their segment still exists.
    r.post('/cases/{case_id}/boundary', (req) {
      final db = req.db;
      final p = req.who;
      final c = Check(req.body);
      final body = c.root ?? <String, dynamic>{};
      final polygon = c.polygon(body, 'polygon');
      final source = c.choice(body, 'source', sources, fallback: 'gps_walk');
      final breaks = <int>[];
      final rawBreaks = c.list(body, 'segment_breaks', max: 200);
      if (rawBreaks == null) {
        breaks.add(0);
      } else {
        for (var i = 0; i < rawBreaks.length; i++) {
          final v = rawBreaks[i];
          if (v is int && v >= 0) {
            breaks.add(v);
          } else {
            c.fail(['segment_breaks', i], v is int ? 'greater_than_equal' : 'int_type',
                v is int ? 'Input should be greater than or equal to 0' : 'Input should be a valid integer', v);
          }
        }
      }
      List<double?>? accuracy;
      final rawAcc = c.list(body, 'vertex_accuracy_m');
      if (rawAcc != null) {
        accuracy = [];
        for (var i = 0; i < rawAcc.length; i++) {
          final v = rawAcc[i];
          if (v == null) {
            accuracy.add(null);
          } else if (v is num && v >= 0) {
            accuracy.add(v.toDouble());
          } else {
            c.fail(['vertex_accuracy_m', i], v is num ? 'greater_than_equal' : 'float_type',
                v is num ? 'Input should be greater than or equal to 0' : 'Input should be a valid number', v);
          }
        }
      }
      c.done();

      final ctx = DemoCases.load(db, p, req.params['case_id']!);
      _ensureCanMap(ctx);
      final (geojson, rings) = _polygon(polygon!);
      final outer = rings.first;
      if (accuracy != null && accuracy.length != outer.length - 1) {
        throw DemoError(422, 'ACCURACY_LENGTH', 'boundary.accuracy_length',
            details: {'vertices': outer.length - 1});
      }
      final List<Ring> pieces;
      try {
        pieces = splitRing(outer, breaks);
      } on GeoError catch (e) {
        throw _geoError(e);
      }

      final caseId = ctx.theCase['id'] as String;
      final previous = currentBoundary(db, caseId);
      var latest = 0;
      for (final b in db.where('cfr_boundary', (b) => b['case_id'] == caseId)) {
        if ((b['version'] as int) > latest) latest = b['version'] as int;
      }

      final now = db.nowIso();
      final segments = [
        for (var seq = 0; seq < pieces.length; seq++)
          {
            'id': db.newId(),
            'seq': seq,
            'geom': {'type': 'LineString', 'coordinates': ringJson(pieces[seq])},
            'length_m': lengthM(pieces[seq]),
          },
      ];
      final b = <String, dynamic>{
        'id': db.newId(),
        'case_id': caseId,
        'version': latest + 1,
        'geom': geojson,
        'source': source,
        'status': 'draft',
        'area_ha': areaHa(rings),
        'accuracy_stats': accuracyStats(accuracy, outer.length - 1, gpsLimitM),
        'is_current': true,
        'sealed_hash': null,
        'approved_on': null,
        'created_by_user_id': p.userId,
        'created_at': now,
        'segments': segments,
        'landmarks': <Map<String, dynamic>>[],
        'use_zones': <Map<String, dynamic>>[],
      };
      if (previous != null) {
        previous['is_current'] = false;
        if (previous['status'] == 'draft') _carryOver(db, previous, b, segments.length);
      }
      db.table('cfr_boundary').add(b);
      detectOverlaps(db, ctx.theCase, b);
      return boundaryOut(db, b);
    });

    r.get('/cases/{case_id}/boundary', (req) {
      final db = req.db;
      final ctx = DemoCases.load(db, req.who, req.params['case_id']!);
      DemoCases.ensureClaimType(ctx, ClaimTypes.cfr, 'NOT_A_FORM_C_CASE');
      return boundaryOut(db, _currentOr404(db, ctx));
    });

    r.get('/cases/{case_id}/boundary/versions', (req) {
      final db = req.db;
      DemoCases.load(db, req.who, req.params['case_id']!);
      final rows = _stable(
        db.where('cfr_boundary', (b) => b['case_id'] == req.params['case_id']),
        (x, y) => (x['version'] as int).compareTo(y['version'] as int),
      );
      return [
        for (final b in rows)
          {
            'id': b['id'],
            'version': b['version'],
            'status': b['status'],
            'source': b['source'],
            'area_ha': dec4(b['area_ha'] as num),
            'is_current': b['is_current'],
            'created_at': b['created_at'],
          },
      ];
    });

    // A landmark fixing a segment on the ground; every segment needs one (BR-08).
    r.post('/cases/{case_id}/boundary/landmarks', (req) {
      final db = req.db;
      final p = req.who;
      final c = Check(req.body);
      final body = c.root ?? <String, dynamic>{};
      final segmentSeq = c.integer(body, 'segment_seq', required: true, ge: 0);
      final name = c.text(body, 'name', required: true, min: 1, max: 200);
      final kind = c.choice(body, 'kind', landmarkKinds, required: true);
      final lat = c.number(body, 'lat', required: true, ge: -90, le: 90);
      final lon = c.number(body, 'lon', required: true, ge: -180, le: 180);
      final photo = c.uuid(body, 'photo_media_id');
      final evidence = c.uuid(body, 'evidence_id');
      c.done();

      final ctx = DemoCases.load(db, p, req.params['case_id']!);
      final b = _editable(db, ctx);
      final segments = _list(b, 'segments');
      if (segmentSeq! >= segments.length) {
        throw DemoError(422, 'NO_SUCH_SEGMENT', 'boundary.no_such_segment',
            details: {'segments': segments.length});
      }
      _ownMedia(db, p, photo);
      if (evidence != null) {
        final ev = db.byId('evidence', evidence);
        if (ev == null || ev['case_id'] != ctx.theCase['id']) {
          throw DemoError(422, 'EVIDENCE_NOT_IN_CASE', 'boundary.evidence_not_in_case');
        }
      }
      final lm = <String, dynamic>{
        'id': db.newId(),
        'segment_seq': segmentSeq,
        'name': name,
        'kind': kind,
        'point': {'type': 'Point', 'coordinates': [lon, lat]},
        'photo_media_id': photo,
        'evidence_id': evidence,
        'created_at': db.nowIso(),
      };
      (b['landmarks'] as List).add(lm);
      return landmarkOut(b, lm);
    });

    r.delete('/cases/{case_id}/boundary/landmarks/{landmark_id}', (req) {
      final db = req.db;
      final ctx = DemoCases.load(db, req.who, req.params['case_id']!);
      final b = _editable(db, ctx);
      final landmarks = b['landmarks'] as List;
      final before = landmarks.length;
      landmarks.removeWhere((lm) => (lm as Map)['id'] == req.params['landmark_id']);
      if (landmarks.length == before) {
        throw DemoError(404, 'LANDMARK_NOT_FOUND', 'boundary.landmark_not_found');
      }
      return null;
    });

    // An area of customary use [Rule 13(2)(b)]. Never clipped; `within_boundary` tells.
    r.post('/cases/{case_id}/boundary/use-zones', (req) {
      final db = req.db;
      final p = req.who;
      final c = Check(req.body);
      final body = c.root ?? <String, dynamic>{};
      final useType = c.choice(body, 'use_type', useZoneTypes, required: true);
      final name = c.text(body, 'name', min: 1, max: 200);
      final polygon = c.polygon(body, 'polygon');
      final season = c.text(body, 'season', max: 100);
      final hamlets = <String>[];
      final rawHamlets = c.list(body, 'user_hamlets', max: 50);
      if (rawHamlets != null) {
        for (var i = 0; i < rawHamlets.length; i++) {
          final h = c.text({'h': rawHamlets[i]}, 'h', loc: ['user_hamlets', i], required: true, min: 1, max: 200);
          if (h != null) hamlets.add(h);
        }
      }
      c.done();

      final ctx = DemoCases.load(db, p, req.params['case_id']!);
      final b = _editable(db, ctx);
      final (geojson, rings) = _polygon(polygon!);
      final zone = <String, dynamic>{
        'id': db.newId(),
        'use_type': useType,
        'name': name,
        'geom': geojson,
        'area_ha': areaHa(rings),
        'season': season,
        'user_hamlets': hamlets,
        'created_at': db.nowIso(),
      };
      (b['use_zones'] as List).add(zone);
      return useZoneOut(b, zone);
    });

    r.delete('/cases/{case_id}/boundary/use-zones/{zone_id}', (req) {
      final db = req.db;
      final ctx = DemoCases.load(db, req.who, req.params['case_id']!);
      final b = _editable(db, ctx);
      final zones = b['use_zones'] as List;
      final before = zones.length;
      zones.removeWhere((z) => (z as Map)['id'] == req.params['zone_id']);
      if (zones.length == before) {
        throw DemoError(404, 'USE_ZONE_NOT_FOUND', 'boundary.use_zone_not_found');
      }
      return null;
    });

    // Who walked the customary boundary, and when, with the GPS trace [Rule 12(1)(f)].
    r.post('/cases/{case_id}/boundary/walks', (req) {
      final db = req.db;
      final p = req.who;
      final c = Check(req.body);
      final body = c.root ?? <String, dynamic>{};
      final walkedOn = c.date(body, 'walked_on');
      final participants = <Map<String, dynamic>>[];
      final rawParts = c.list(body, 'participants', required: true, min: 1, max: 200);
      if (rawParts != null) {
        for (var i = 0; i < rawParts.length; i++) {
          final item = rawParts[i];
          if (item is! Map) {
            c.fail(['participants', i], 'model_type', 'Input should be a valid dictionary or object', item);
            continue;
          }
          final m = Map<String, dynamic>.from(item);
          final loc = <Object>['participants', i];
          final name = c.text(m, 'name', loc: loc, required: true, min: 1, max: 200);
          final member = c.uuid(m, 'gs_member_id', loc: loc);
          final role = c.choice(m, 'role', participantRoles, loc: loc, fallback: 'elder');
          participants.add({'name': name, 'gs_member_id': member, 'role': role});
        }
      }
      final trace = c.lineString(body, 'trace');
      final notes = c.text(body, 'notes', min: 1, max: 4000);
      c.done();

      final ctx = DemoCases.load(db, p, req.params['case_id']!);
      _ensureCanMap(ctx);
      final memberIds = [for (final x in participants) if (x['gs_member_id'] != null) x['gs_member_id'] as String];
      if (memberIds.isNotEmpty) {
        final found = db
            .where(
              'gs_member',
              (m) => memberIds.contains(m['id']) && m['gram_sabha_id'] == ctx.theCase['gram_sabha_id'],
            )
            .length;
        if (found != memberIds.length) {
          throw DemoError(422, 'PARTICIPANT_NOT_IN_ROSTER', 'boundary.participant_not_in_roster');
        }
      }
      Map<String, dynamic>? traceJson;
      double? traceLength;
      if (trace != null) {
        try {
          final pts = [for (final pt in trace) position(pt)];
          traceJson = {'type': 'LineString', 'coordinates': ringJson(pts)};
          traceLength = lengthM(pts);
        } on GeoError catch (e) {
          throw _geoError(e);
        }
      }
      final walk = db.add('boundary_walk', {
        'case_id': ctx.theCase['id'],
        'walked_on': walkedOn,
        'participants': participants,
        'trace': traceJson,
        'trace_length_m': traceLength,
        'notes': notes,
        'created_by_user_id': p.userId,
      });
      return _walkOut(walk);
    });

    r.get('/cases/{case_id}/boundary/walks', (req) {
      final db = req.db;
      DemoCases.load(db, req.who, req.params['case_id']!);
      final walks = _stable(
        db.where('boundary_walk', (w) => w['case_id'] == req.params['case_id']),
        (x, y) {
          final c = '${x['walked_on']}'.compareTo('${y['walked_on']}');
          return c != 0 ? c : '${x['created_at']}'.compareTo('${y['created_at']}');
        },
      );
      return [for (final w in walks) _walkOut(w)];
    });

    // Re-run the overlap test against neighbours' current boundaries (BR-09).
    r.post('/cases/{case_id}/boundary/conflicts/check', (req) {
      final db = req.db;
      final ctx = DemoCases.load(db, req.who, req.params['case_id']!);
      DemoCases.ensureClaimType(ctx, ClaimTypes.cfr, 'NOT_A_FORM_C_CASE');
      if (!ctx.roles.contains(Roles.gramSabha)) {
        throw DemoError(403, 'NOT_YOUR_LEVEL', 'workflow.not_your_level');
      }
      detectOverlaps(db, ctx.theCase, _currentOr404(db, ctx));
      return disputesOut(db, ctx.theCase['id'] as String);
    });

    r.get('/cases/{case_id}/disputes', (req) {
      final db = req.db;
      DemoCases.load(db, req.who, req.params['case_id']!);
      return disputesOut(db, req.params['case_id']!);
    });

    // G17: the joint meeting of the Gram Sabhas / FRCs concerned and its outcome.
    r.post('/cases/{case_id}/disputes/{dispute_id}/joint-meeting', (req) {
      final db = req.db;
      final p = req.who;
      final c = Check(req.body);
      final body = c.root ?? <String, dynamic>{};
      final heldOn = c.date(body, 'held_on');
      final findings = c.text(body, 'findings', required: true, min: 1, max: 4000);
      final outcome = c.choice(body, 'outcome', outcomes, required: true);
      final media = c.uuid(body, 'record_media_id');
      c.done();

      final ctx = DemoCases.load(db, p, req.params['case_id']!);
      final d = _disputeForGs(db, ctx, req.params['dispute_id']!);
      if (d['outcome'] != null && d['outcome'] != 'not_resolved') {
        throw DemoError(409, 'DISPUTE_SETTLED', 'dispute.already_settled');
      }
      _ownMedia(db, p, media);
      d['joint_meeting_on'] = heldOn;
      d['joint_meeting_findings'] = findings;
      d['joint_meeting_media_id'] = media;
      d['outcome'] = outcome;
      return _one(db, ctx.theCase['id'] as String, d['id'] as String);
    });

    // Refer an unresolved overlap to the SDLC: after a joint meeting that did not resolve it, or
    // once the time for a mutual solution has passed [Rule 12(3), 14(7)].
    r.post('/cases/{case_id}/disputes/{dispute_id}/sdlc-referral', (req) {
      final db = req.db;
      final p = req.who;
      final c = Check(req.body);
      final body = c.root ?? <String, dynamic>{};
      final referredOn = c.date(body, 'referred_on');
      final ref = c.text(body, 'ref', required: true, min: 1, max: 200);
      c.done();

      final ctx = DemoCases.load(db, p, req.params['case_id']!);
      final d = _disputeForGs(db, ctx, req.params['dispute_id']!);
      if (d['outcome'] != null && d['outcome'] != 'not_resolved') {
        throw DemoError(409, 'DISPUTE_SETTLED', 'dispute.already_settled');
      }
      final earliest = dateOnly(parseDate(d['detected_on'] as String).add(const Duration(days: jointSolutionDays)));
      final waited = referredOn!.compareTo(earliest) >= 0;
      if (d['outcome'] != 'not_resolved' && !waited) {
        throw DemoError(409, 'JOINT_MEETING_FIRST', 'dispute.joint_meeting_first',
            rule: 'Rule 12(3)', details: {'earliest_without_meeting': earliest});
      }
      d['sdlc_referral_on'] = referredOn;
      d['sdlc_referral_ref'] = ref;
      return _one(db, ctx.theCase['id'] as String, d['id'] as String);
    });
  }

  static Map<String, dynamic> _disputeForGs(DemoDb db, CaseCtx ctx, String disputeId) {
    if (!ctx.roles.contains(Roles.gramSabha)) {
      throw DemoError(403, 'NOT_YOUR_LEVEL', 'workflow.not_your_level');
    }
    final d = db.byId('dispute', disputeId);
    if (d == null || (d['case_id'] != ctx.theCase['id'] && d['neighbour_case_id'] != ctx.theCase['id'])) {
      throw DemoError(404, 'DISPUTE_NOT_FOUND', 'dispute.not_found');
    }
    if (d['sdlc_referral_on'] != null) {
      throw DemoError(409, 'DISPUTE_REFERRED', 'dispute.already_referred');
    }
    return d;
  }

  static Map<String, dynamic> _one(DemoDb db, String caseId, String disputeId) =>
      disputesOut(db, caseId).firstWhere((d) => d['id'] == disputeId);

  static Map<String, dynamic> _walkOut(Map<String, dynamic> w) {
    final trace = w['trace'] as Map?;
    return {
      'id': w['id'],
      'walked_on': w['walked_on'],
      'participants': [
        for (final x in (w['participants'] as List).cast<Map>())
          {'name': x['name'], 'gs_member_id': x['gs_member_id'], 'role': x['role'] ?? 'elder'},
      ],
      'trace': trace,
      'trace_length_m': trace == null ? null : lengthM(lineFromJson(trace.cast<String, dynamic>())),
      'notes': w['notes'],
      'created_at': w['created_at'],
    };
  }

  /// A new version starts from the draft before it: its landmarks and use zones where the
  /// segment still exists.
  static void _carryOver(DemoDb db, Map<String, dynamic> old, Map<String, dynamic> next, int segments) {
    final now = db.nowIso();
    for (final lm in _list(old, 'landmarks')) {
      if ((lm['segment_seq'] as int) < segments) {
        (next['landmarks'] as List).add({
          'id': db.newId(),
          'segment_seq': lm['segment_seq'],
          'name': lm['name'],
          'kind': lm['kind'],
          'point': lm['point'],
          'photo_media_id': lm['photo_media_id'],
          'evidence_id': lm['evidence_id'],
          'created_at': now,
        });
      }
    }
    for (final z in _list(old, 'use_zones')) {
      (next['use_zones'] as List).add({
        'id': db.newId(),
        'use_type': z['use_type'],
        'name': z['name'],
        'geom': z['geom'],
        'area_ha': z['area_ha'],
        'season': z['season'],
        'user_hamlets': List<dynamic>.from((z['user_hamlets'] as List?) ?? const []),
        'created_at': now,
      });
    }
  }
}
