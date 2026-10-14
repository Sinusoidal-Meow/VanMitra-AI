import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../core/demo_cases.dart';
import '../core/demo_core.dart';
import 'evidence_validation.dart';
import 'readiness.dart';

/// G-series documents as printable HTML (backend api/v1/documents.py and documents.py): G4
/// acknowledgement, G7 letter, G8 verification sheet, G9 boundary record, G10 map sheet, G12
/// quorum sheet, G13 resolution and G17 joint-meeting record. The content is what the Gram Sabha
/// recorded; nothing is generated that was not entered.
///
/// The real server answers these with `text/html`; here the handler returns the HTML text.
class DemoDocuments {
  DemoDocuments._();

  static const String disclaimer = 'Community record prepared with VanMitra. Not a government document.';
  static const List<String> caseDocuments = ['g4', 'g8', 'g9', 'g10', 'g12', 'g13', 'g17'];

  static const Map<String, Map<String, String>> titles = {
    'g4': {'en': 'Acknowledgement of claim received', 'mr': 'दावा प्राप्त झाल्याची पोच'},
    'g7': {'en': 'Letter of intimation / request', 'mr': 'पत्र / पूर्वसूचना'},
    'g8': {'en': 'Field verification proceeding', 'mr': 'प्रत्यक्ष पडताळणी कार्यवाही'},
    'g9': {'en': 'Participatory boundary delineation record', 'mr': 'सीमा निश्चिती नोंद'},
    'g10': {'en': 'Community forest resource map sheet', 'mr': 'सामूहिक वन संसाधन नकाशा'},
    'g12': {'en': 'Attendance and quorum sheet', 'mr': 'उपस्थिती व गणपूर्ती पत्रक'},
    'g13': {'en': 'Gram Sabha resolution', 'mr': 'ग्रामसभा ठराव'},
    'g17': {
      'en': 'Joint meeting record for conflicting claims',
      'mr': 'परस्परविरोधी दाव्यांची संयुक्त बैठक नोंद',
    },
  };

  static const String _style =
      "body{font-family:'Noto Sans Devanagari','Noto Sans',Arial,sans-serif;margin:2cm;font-size:12pt}"
      'h1{font-size:16pt;text-align:center} h2{font-size:13pt;margin-top:1.2em}'
      'table{border-collapse:collapse;width:100%;margin:.5em 0} '
      'td,th{border:1px solid #444;padding:4px 6px;text-align:left;vertical-align:top}'
      '.meta td{border:none;padding:2px 6px} '
      'footer{margin-top:2em;border-top:1px solid #444;font-size:9pt;color:#333}'
      '.sign{margin-top:2.5em} '
      '.sign span{display:inline-block;width:30%;border-top:1px solid #000;margin-right:3%;text-align:center}';

  // ── helpers ────────────────────────────────────────────────────────────────

  /// HTML-escape a value (the real templates are auto-escaped); null reads as empty.
  static String esc(Object? v) => (v == null ? '' : '$v')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&#34;')
      .replaceAll("'", '&#39;');

  static String _yesNo(Object? v) => v == true ? 'Yes' : 'No';

  /// The whole page: title, village block, [body] and the footer with its SHA-256.
  static String render(DemoDb db, String code, String lang, Map<String, dynamic> village,
      String caseId, String body) {
    final t = titles[code]!;
    final title = lang == 'mr' ? '${t['mr']} / ${t['en']}' : t['en']!;
    final digest = sha256.convert(utf8.encode(body)).toString();
    final n = db.now();
    String two(int x) => x.toString().padLeft(2, '0');
    final generated = '${dateOnly(n)} ${two(n.hour)}:${two(n.minute)} UTC';
    return '<!doctype html>\n<html lang="${esc(lang)}"><head><meta charset="utf-8"><title>${esc(title)}</title>\n'
        '<style>\n$_style</style></head><body>\n'
        '<h1>${esc(title)}</h1>\n'
        '<table class="meta"><tr><td>Village / गाव</td><td>${esc(village['name_mr'])} (${esc(village['name_en'])})</td>\n'
        '<td>Gram Panchayat</td><td>${esc(village['gram_panchayat'])}</td></tr>\n'
        '<tr><td>Taluka</td><td>${esc(village['taluka'])}</td><td>District</td><td>${esc(village['district'])}</td></tr></table>\n'
        '$body\n'
        '<footer>Case ${esc(caseId)} · generated $generated · body SHA-256 $digest<br>$disclaimer</footer>\n'
        '</body></html>';
  }

  static List<Map<String, dynamic>> _maps(Object? v) =>
      [for (final x in (v as List?) ?? const []) Map<String, dynamic>.from(x as Map)];

  static String _sign(List<String> labels) =>
      '<div class="sign">${labels.map((l) => '<span>$l</span>').join()}</div>';

  /// "<name_mr> (<name_en>)" of a village.
  static String villageLabel(Map<String, dynamic> v) => '${v['name_mr']} (${v['name_en']})';

  /// The lines of the acknowledgement: current evidence recorded on or before the filing day.
  static List<String> documentsReceived(DemoDb db, Map<String, dynamic> c) {
    final filed = c['acknowledged_on'] as String;
    return [
      for (final e in CaseFacts.currentEvidence(db, c['id'] as String))
        if ('${e['created_at']}'.substring(0, 10).compareTo(filed) <= 0)
          '${e['rule_ref']}: ${e['description']}',
    ];
  }

  // ── G4 ─────────────────────────────────────────────────────────────────────

  static String g4(DemoDb db, CaseCtx ctx, String lang) {
    final c = ctx.theCase;
    if (c['ack_serial'] == null || c['acknowledged_on'] == null) {
      throw DemoError(409, 'NOT_YET_FILED', 'acknowledgement.not_yet_filed');
    }
    final window = c['filed_within_window'];
    final within = window == true ? 'Yes' : (window == false ? 'No' : 'No call recorded');
    final docs = documentsReceived(db, c);
    final body = '\n<p>Serial: <b>${esc(c['ack_serial'])}</b> · Date: ${esc(c['acknowledged_on'])} · '
        'Form ${esc('${c['claim_type']}'.toUpperCase())}</p>\n'
        '<p>Claimant: ${esc(DemoCases.claimantLabel(c, ctx.village))}</p>\n'
        '<p>Received within the call for claims: $within</p>\n'
        '<h2>Documents received</h2>\n'
        '<ol>${docs.isEmpty ? '<li>None listed</li>' : docs.map((d) => '<li>${esc(d)}</li>').join()}</ol>\n'
        '${_sign(['Received by', 'Gram Panchayat seal'])}';
    return render(db, 'g4', lang, ctx.village, '${c['id']}', body);
  }

  // ── G8 ─────────────────────────────────────────────────────────────────────

  static String _signature(Map<String, dynamic> p, String dept) {
    if (p['${dept}_signed'] == true) return 'Signed';
    if (p['${dept}_absence_recorded'] == true) return 'Absent despite intimation';
    return 'Pending';
  }

  static String g8(DemoDb db, CaseCtx ctx, String lang) {
    final c = ctx.theCase;
    final rows = db.where('verification_proceeding', (v) => v['case_id'] == c['id']).toList()
      ..sort((a, b) => ((a['attempt_no'] as num?) ?? 0).compareTo((b['attempt_no'] as num?) ?? 0));
    final b = StringBuffer('\n');
    if (rows.isEmpty) b.write('<p>No visit recorded yet.</p>');
    for (final p in rows) {
      b.write('\n<h2>Visit ${esc(p['attempt_no'])}: ${esc(p['visit_on'])}</h2>\n'
          '<p>${esc(p['observations'])}</p>\n'
          '<table><tr><th>Name</th><th>Designation</th><th>Department</th></tr>\n');
      for (final x in _maps(p['presence'])) {
        b.write('<tr><td>${esc(x['name'])}</td><td>${esc(x['designation'])}</td>'
            '<td>${esc(x['department'])}</td></tr>');
      }
      b.write('</table>\n'
          '<table><tr><th>Department</th><th>Signature</th></tr>\n'
          '<tr><td>Forest</td><td>${_signature(p, 'forest')}</td></tr>\n'
          '<tr><td>Revenue</td><td>${_signature(p, 'revenue')}</td></tr></table>\n');
      if (CaseFacts.finalityNote(p)) {
        b.write('<p><b>Note:</b> the officials were absent on the second visit; '
            'the Gram Sabha decision stands [Rule 12A(2)].</p>');
      }
    }
    b.write('\n${_sign(['Forest Department', 'Revenue Department', 'FRC Chairperson'])}');
    return render(db, 'g8', lang, ctx.village, '${c['id']}', b.toString());
  }

  // ── boundary documents ─────────────────────────────────────────────────────

  static Map<String, dynamic> _boundary(DemoDb db, CaseCtx ctx) {
    DemoCases.ensureClaimType(ctx, ClaimTypes.cfr, 'NOT_A_FORM_C_CASE');
    final b = CaseFacts.currentBoundary(db, '${ctx.theCase['id']}');
    if (b == null) throw DemoError(404, 'NO_BOUNDARY', 'boundary.none');
    return b;
  }

  static List<Map<String, dynamic>> _sortedLandmarks(Map<String, dynamic> b) {
    final lms = _maps(b['landmarks']);
    int seq(Map<String, dynamic> m) => ((m['segment_seq'] as num?) ?? 0).toInt();
    lms.sort((x, y) {
      final s = seq(x).compareTo(seq(y));
      return s != 0 ? s : '${x['created_at']}'.compareTo('${y['created_at']}');
    });
    return lms;
  }

  /// (lon, lat) of a landmark's GeoJSON point.
  static (double, double) _lonLat(Map<String, dynamic> lm) {
    final p = lm['point'];
    final coords = p is Map ? p['coordinates'] as List? : null;
    if (coords == null || coords.length < 2) return (lm['lon'] is num ? (lm['lon'] as num).toDouble() : 0, lm['lat'] is num ? (lm['lat'] as num).toDouble() : 0);
    return ((coords[0] as num).toDouble(), (coords[1] as num).toDouble());
  }

  static String g9(DemoDb db, CaseCtx ctx, String lang) {
    final c = ctx.theCase;
    final b = _boundary(db, ctx);
    final walks = db.where('boundary_walk', (w) => w['case_id'] == c['id']).toList()
      ..sort((x, y) => '${x['walked_on']}'.compareTo('${y['walked_on']}'));
    final segments = _maps(b['segments'])
      ..sort((x, y) => ((x['seq'] as num?) ?? 0).compareTo((y['seq'] as num?) ?? 0));
    final landmarks = _sortedLandmarks(b);
    final out = StringBuffer('\n');
    if (walks.isEmpty) out.write('<p>No walk recorded yet.</p>');
    for (final w in walks) {
      out.write('\n<h2>Walk of ${esc(w['walked_on'])}</h2>\n'
          '<table><tr><th>Participant</th><th>Role</th></tr>\n');
      for (final p in _maps(w['participants'])) {
        out.write('<tr><td>${esc(p['name'])}</td><td>${esc(p['role'])}</td></tr>');
      }
      out.write('</table>\n');
      final notes = w['notes'];
      if (notes != null && '$notes'.isNotEmpty) out.write('<p>${esc(notes)}</p>');
    }
    out.write('\n<h2>Segments and landmarks</h2>\n'
        '<table><tr><th>Segment</th><th>Length (m)</th><th>Landmarks</th></tr>\n');
    for (final s in segments) {
      final here = [
        for (final l in landmarks)
          if (l['segment_seq'] == s['seq']) '${esc(l['name'])} (${esc(l['kind'])})',
      ];
      out.write('<tr><td>${((s['seq'] as num?) ?? 0).toInt() + 1}</td><td>${esc(s['length_m'])}</td>'
          '<td>${here.join(', ')}</td></tr>');
    }
    out.write('</table>\n${_sign(['Elders', 'FRC', 'Gram Sabha'])}');
    return render(db, 'g9', lang, ctx.village, '${c['id']}', out.toString());
  }

  static String g10(DemoDb db, CaseCtx ctx, String lang) {
    final c = ctx.theCase;
    final b = _boundary(db, ctx);
    if (CaseFacts.segmentsWithoutLandmark(b) > 0) {
      throw DemoError(409, 'LANDMARK_PER_SEGMENT', 'boundary.landmark_per_segment',
          rule: 'Rule 12(1)(g)');
    }
    final landmarks = _sortedLandmarks(b);
    final zones = _maps(b['use_zones'])
      ..sort((x, y) => '${x['created_at']}'.compareTo('${y['created_at']}'));
    final resolution = CaseFacts.currentResolution(db, '${c['id']}');
    final formC = c['form_c'];
    final bordering = [
      if (formC is Map)
        for (final x in _maps(formC['bordering_villages'])) '${x['name']}',
    ];
    final sealed = b['sealed_hash'];
    final svg = mapSvg(
      b['geom'] is Map ? Map<String, dynamic>.from(b['geom'] as Map) : null,
      [for (final l in landmarks) _lonLat(l)],
      [for (final z in zones) if (z['geom'] is Map) Map<String, dynamic>.from(z['geom'] as Map)],
    );
    final body = StringBuffer('\n<p>Area: ${esc(b['area_ha'])} ha · Boundary version ${esc(b['version'])} '
        '(${esc(b['status'])})'
        '${sealed != null && '$sealed'.isNotEmpty ? ' · sealed ${esc('$sealed'.substring(0, math.min(16, '$sealed'.length)))}…' : ''}</p>\n'
        '$svg\n'
        '<h2>Landmarks</h2>\n'
        '<table><tr><th>No.</th><th>Segment</th><th>Name</th><th>Kind</th><th>Position (lat, lon)</th></tr>\n');
    var n = 1;
    for (final l in landmarks) {
      final (lon, lat) = _lonLat(l);
      body.write('<tr><td>${n++}</td><td>${((l['segment_seq'] as num?) ?? 0).toInt() + 1}</td>'
          '<td>${esc(l['name'])}</td><td>${esc(l['kind'])}</td>'
          '<td>${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}</td></tr>');
    }
    body.write('</table>\n<h2>Bordering villages</h2>\n'
        '<p>${bordering.isEmpty ? 'None listed' : bordering.map(esc).join(', ')}</p>\n'
        '<h2>Use zones</h2>\n'
        '<table><tr><th>Use</th><th>Name</th><th>Season</th><th>Area (ha)</th></tr>\n');
    if (zones.isEmpty) body.write('<tr><td colspan="4">None</td></tr>');
    for (final z in zones) {
      body.write('<tr><td>${esc(z['use_type'])}</td><td>${esc(z['name'])}</td>'
          '<td>${esc(z['season'])}</td><td>${esc(z['area_ha'])}</td></tr>');
    }
    body.write('</table>\n<p>Resolution: ${esc(resolution?['number'] ?? 'not yet passed')}. '
        'North is up; the polygon is not clipped to forest or legal boundaries.</p>');
    return render(db, 'g10', lang, ctx.village, '${c['id']}', body.toString());
  }

  /// The boundary, use zones and numbered landmarks as an SVG (equirectangular, north up).
  static String mapSvg(
    Map<String, dynamic>? outline,
    List<(double, double)> landmarks,
    List<Map<String, dynamic>> zones, {
    int size = 520,
  }) {
    List<List<double>> ring(Map<String, dynamic> geometry) => [
          for (final p in ((geometry['coordinates'] as List?)?.firstOrNull as List?) ?? const [])
            [((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()],
        ];
    final outer = outline == null ? <List<double>>[] : ring(outline);
    if (outer.isEmpty) return '';
    final lons = [for (final p in outer) p[0]];
    final lats = [for (final p in outer) p[1]];
    final minLon = lons.reduce(math.min), maxLon = lons.reduce(math.max);
    final minLat = lats.reduce(math.min), maxLat = lats.reduce(math.max);
    final midLat = (minLat + maxLat) / 2 * math.pi / 180;
    final widthM = math.max((maxLon - minLon) * math.cos(midLat), 1e-9);
    final heightM = math.max(maxLat - minLat, 1e-9);
    final scale = (size - 40) / math.max(widthM, heightM);
    (double, double) xy(double lon, double lat) => (
          20 + (lon - minLon) * math.cos(midLat) * scale,
          size - 20 - (lat - minLat) * scale,
        );
    String path(List<List<double>> r) => r.map((p) {
          final (x, y) = xy(p[0], p[1]);
          return '${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}';
        }).join(' ');
    final parts = StringBuffer(
        '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" viewBox="0 0 $size $size">');
    parts.write('<rect width="$size" height="$size" fill="#fff" stroke="#999"/>');
    for (final z in zones) {
      if (z['type'] == 'Polygon') {
        parts.write('<polygon points="${path(ring(z))}" fill="#9ccc65" fill-opacity=".35" stroke="#558b2f"/>');
      }
    }
    parts.write('<polygon points="${path(outer)}" fill="none" stroke="#b71c1c" stroke-width="2"/>');
    var n = 1;
    for (final (lon, lat) in landmarks) {
      final (x, y) = xy(lon, lat);
      parts.write('<circle cx="${x.toStringAsFixed(1)}" cy="${y.toStringAsFixed(1)}" r="5" fill="#1565c0"/>'
          '<text x="${(x + 7).toStringAsFixed(1)}" y="${(y - 5).toStringAsFixed(1)}" font-size="12">${n++}</text>');
    }
    parts.write('<text x="${size - 30}" y="30" font-size="14">N ↑</text></svg>');
    return parts.toString();
  }

  // ── G12 quorum sheet ───────────────────────────────────────────────────────

  /// The three quorum tests of Rule 4(2) for a meeting, computed now (domain/quorum.py).
  static Map<String, dynamic> quorum({
    required int registered,
    required int present,
    required int womenPresent,
    int claimantsTotal = 0,
    int claimantsPresent = 0,
  }) {
    final requiredPresent = (registered / 2).ceil();
    final requiredWomen = (present / 3).ceil();
    final requiredClaimants = (claimantsTotal / 2).ceil();
    final t1 = registered > 0 && present >= requiredPresent;
    final t2 = present > 0 && womenPresent >= requiredWomen;
    final t3 = claimantsPresent >= requiredClaimants;
    return {
      'registered': registered,
      'present': present,
      'women_present': womenPresent,
      'claimants_total': claimantsTotal,
      'claimants_present': claimantsPresent,
      'required_present': requiredPresent,
      'required_women': requiredWomen,
      'required_claimants': requiredClaimants,
      't1': t1,
      't2': t2,
      't3': t3,
      'passed': t1 && t2 && t3,
      'failures': [
        if (!t1) 'quorum.t1_present',
        if (!t2) 'quorum.t2_women',
        if (!t3) 'quorum.t3_claimants',
      ],
    };
  }

  static String g12(DemoDb db, CaseCtx ctx, String lang, String? meetingId) {
    final c = ctx.theCase;
    if (meetingId == null) {
      throw DemoError(422, 'MEETING_REQUIRED', 'document.meeting_required');
    }
    final meeting = db.byId('gs_meeting', meetingId);
    if (meeting == null || meeting['gram_sabha_id'] != c['gram_sabha_id']) {
      throw DemoError(404, 'MEETING_NOT_FOUND', 'meeting.not_found');
    }
    final attendance = _maps(meeting['attendance']);
    final presentIds = {for (final a in attendance) if (a['present'] == true) a['gs_member_id']};
    final women = db
        .where('gs_member', (m) => presentIds.contains(m['id']) && m['gender'] == 'female')
        .length;
    final claimants = CaseFacts.claimantMemberIds(db, '${c['id']}');
    final q = quorum(
      registered: ((meeting['registered_count'] as num?) ?? 0).toInt(),
      present: presentIds.length,
      womenPresent: women,
      claimantsTotal: claimants.length,
      claimantsPresent: claimants.intersection(presentIds.map((e) => '$e').toSet()).length,
    );
    final rows = <({String name, bool present})>[];
    for (final a in attendance) {
      final m = db.byId('gs_member', a['gs_member_id'] as String?);
      if (m != null) rows.add((name: '${m['name']}', present: a['present'] == true));
    }
    rows.sort((x, y) => x.name.compareTo(y.name));
    String met(Object? ok) => ok == true ? 'Met' : 'Not met';
    final b = StringBuffer('\n<p>Meeting of ${esc(meeting['held_on'])} at ${esc(meeting['place'])}. '
        'Agenda: ${esc(meeting['agenda'])}</p>\n'
        '<table><tr><th>Test</th><th>Required</th><th>Actual</th><th>Result</th></tr>\n'
        '<tr><td>Members present</td><td>${q['required_present']} of ${q['registered']}</td><td>${q['present']}</td><td>${met(q['t1'])}</td></tr>\n'
        '<tr><td>Women present</td><td>${q['required_women']}</td><td>${q['women_present']}</td><td>${met(q['t2'])}</td></tr>\n'
        '<tr><td>Claimants present</td><td>${q['required_claimants']} of ${q['claimants_total']}</td><td>${q['claimants_present']}</td><td>${met(q['t3'])}</td></tr></table>\n'
        '<p><b>Quorum ${q['passed'] == true ? 'complete' : 'NOT complete'}</b> [Rule 4(2)].</p>\n'
        '<h2>Attendance</h2>\n'
        '<table><tr><th>No.</th><th>Name</th><th>Present</th></tr>\n');
    var n = 1;
    for (final r in rows) {
      b.write('<tr><td>${n++}</td><td>${esc(r.name)}</td><td>${_yesNo(r.present)}</td></tr>');
    }
    b.write('</table>');
    return render(db, 'g12', lang, ctx.village, '${c['id']}', b.toString());
  }

  // ── G13 resolution ─────────────────────────────────────────────────────────

  static String g13(DemoDb db, CaseCtx ctx, String lang) {
    final c = ctx.theCase;
    final r = CaseFacts.currentResolution(db, '${c['id']}');
    if (r == null) throw DemoError(404, 'NO_RESOLUTION', 'resolution.none');
    final meeting = db.byId('gs_meeting', r['meeting_id'] as String?);
    final sealedBoundary = db.byId('cfr_boundary', r['boundary_id'] as String?);
    final sealed = sealedBoundary?['sealed_hash'];
    final qRaw = r['quorum_proof'];
    final q = qRaw is Map ? Map<String, dynamic>.from(qRaw) : <String, dynamic>{};
    final body = '\n<p>Resolution no. <b>${esc(r['number'])}</b> · Meeting of ${esc(meeting?['held_on'])} '
        'at ${esc(meeting?['place'])}</p>\n'
        '<p>Agenda: ${esc(meeting?['agenda'])}</p>\n'
        '<h2>Decision</h2><p>${esc(r['decision_text'])}</p>\n'
        '<p>Votes for: ${esc(r['votes_for'])} · against: ${esc(r['votes_against'])} · '
        'present: ${esc(q['present'])} of ${esc(q['registered'])} (${esc(q['women_present'])} women; '
        '${esc(q['claimants_present'])} of ${esc(q['claimants_total'])} claimants)</p>\n'
        '<p>Quorum ${q['passed'] == true ? 'complete' : 'NOT complete'} [Rule 4(2)].'
        '${sealed != null && '$sealed'.isNotEmpty ? ' Approves the boundary sealed as ${esc('$sealed'.substring(0, math.min(16, '$sealed'.length)))}… [Rule 12(1)(g)].' : ''}</p>\n'
        '${_sign(['Chairperson', 'Secretary', 'Gram Sabha members'])}';
    return render(db, 'g13', lang, ctx.village, '${c['id']}', body);
  }

  // ── G17 joint meeting ──────────────────────────────────────────────────────

  static String g17(DemoDb db, CaseCtx ctx, String lang, String? disputeId) {
    final c = ctx.theCase;
    if (disputeId == null) {
      throw DemoError(422, 'DISPUTE_REQUIRED', 'document.dispute_required');
    }
    final d = db.findOne(
      'dispute',
      (x) =>
          x['id'] == disputeId && (x['case_id'] == c['id'] || x['neighbour_case_id'] == c['id']),
    );
    if (d == null) throw DemoError(404, 'DISPUTE_NOT_FOUND', 'dispute.not_found');
    final neighbourCaseId = d['case_id'] == c['id'] ? d['neighbour_case_id'] : d['case_id'];
    final nc = db.byId('claim_case', neighbourCaseId as String?);
    final gs = db.byId('gram_sabha', nc?['gram_sabha_id'] as String?);
    final nv = db.byId('village', gs?['village_id'] as String?);
    final neighbour = nv == null ? '' : villageLabel(nv);
    final own = '${ctx.village['name_en']}';
    final b = StringBuffer('\n<p>Overlap of about ${esc(d['overlap_ha'])} ha between the claim of ${esc(own)} '
        'and the claim of ${esc(neighbour)}. Detected on ${esc(d['detected_on'])}.</p>\n');
    final meetingOn = d['joint_meeting_on'];
    if (meetingOn != null && '$meetingOn'.isNotEmpty) {
      b.write('<h2>Joint meeting of ${esc(meetingOn)}</h2><p>${esc(d['joint_meeting_findings'])}</p>\n'
          '<p>Outcome: ${esc(d['outcome'])}</p>');
    } else {
      b.write('<p>No joint meeting recorded yet.</p>');
    }
    if (d['sdlc_referral_on'] != null) {
      b.write('\n<p>Referred to the SDLC on ${esc(d['sdlc_referral_on'])} '
          '(ref. ${esc(d['sdlc_referral_ref'])}) [Rule 12(3)].</p>');
    }
    b.write('\n${_sign(['FRC of ${esc(own)}', 'FRC of ${esc(neighbour)}'])}');
    return render(db, 'g17', lang, ctx.village, '${c['id']}', b.toString());
  }

  // ── G7 (a tracked letter) ──────────────────────────────────────────────────

  static String g7(DemoDb db, Map<String, dynamic> village, Map<String, dynamic> letter,
      String lang) {
    final body = letter['body'];
    final records = ((letter['records_requested'] as List?) ?? const []).map((x) => '$x').toList();
    final neighbour = letter['neighbour_village'];
    final dispatched = letter['dispatched_on'];
    final b = StringBuffer('\n<p>To: ${esc(letter['addressee'])}</p><p>Subject: ${esc(letter['subject'])}</p>\n');
    if (body != null && '$body'.isNotEmpty) b.write('<p>${esc(body)}</p>\n');
    if (neighbour != null && '$neighbour'.isNotEmpty) {
      b.write('<p>Adjoining village: ${esc(neighbour)}</p>\n');
    }
    if (records.isNotEmpty) {
      b.write('<p>Records requested:</p><ul>${records.map((r) => '<li>${esc(r)}</li>').join()}</ul>\n');
    }
    b.write('<p>Dispatched on: ${esc(dispatched ?? 'not yet dispatched')}</p>\n'
        '${_sign(['Chairperson, FRC', 'Secretary, FRC'])}');
    return render(db, 'g7', lang, village, '${letter['case_id'] ?? ''}', b.toString());
  }

  // ── routes ──────────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    r.get('/cases/{case_id}/documents/{code}', (req) {
      final p = req.who;
      final caseId = pathUuid(req, 'case_id');
      final lang = req.q('lang') ?? 'en';
      if (lang != 'en' && lang != 'mr') {
        throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid', details: {
          'errors': [
            {
              'type': 'literal_error',
              'loc': ['query', 'lang'],
              'msg': "Input should be 'en' or 'mr'",
              'input': lang,
            },
          ],
        });
      }
      final meetingId = queryUuid(req, 'meeting_id');
      final disputeId = queryUuid(req, 'dispute_id');
      final code = req.params['code']!.toLowerCase();
      if (!caseDocuments.contains(code)) {
        throw DemoError(404, 'UNKNOWN_DOCUMENT', 'document.unknown',
            details: {'available': caseDocuments});
      }
      final ctx = DemoCases.load(req.db, p, caseId);
      return switch (code) {
        'g4' => g4(req.db, ctx, lang),
        'g8' => g8(req.db, ctx, lang),
        'g9' => g9(req.db, ctx, lang),
        'g10' => g10(req.db, ctx, lang),
        'g12' => g12(req.db, ctx, lang, meetingId),
        'g13' => g13(req.db, ctx, lang),
        _ => g17(req.db, ctx, lang, disputeId),
      };
    });

    r.get('/letters/{letter_id}/document', (req) {
      final p = req.who;
      final letterId = pathUuid(req, 'letter_id');
      final lang = req.q('lang') ?? 'en';
      if (lang != 'en' && lang != 'mr') {
        throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid', details: {
          'errors': [
            {
              'type': 'literal_error',
              'loc': ['query', 'lang'],
              'msg': "Input should be 'en' or 'mr'",
              'input': lang,
            },
          ],
        });
      }
      final db = req.db;
      final letter = db.byId('correspondence', letterId);
      if (letter == null) throw DemoError(404, 'LETTER_NOT_FOUND', 'letter.not_found');
      final gs = db.byId('gram_sabha', letter['gram_sabha_id'] as String?);
      final village = gs == null ? null : db.byId('village', gs['village_id'] as String?);
      if (village == null || !p.has(village)) {
        throw DemoError(404, 'LETTER_NOT_FOUND', 'letter.not_found');
      }
      return g7(db, village, letter, lang);
    });
  }
}
