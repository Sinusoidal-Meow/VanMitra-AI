import '../core/demo_cases.dart';
import '../core/demo_core.dart';

/// Title drafts [Rule 8(h), 8(i)]: Annexure II (Form A), III (Form B), IV (Form C). Field order
/// follows the printed annexures. Signed by three district officers. Ported from
/// backend services/title.py and the GET `/cases/{id}/title-draft` route of api/v1/workflow.py.
///
/// Reads the form embedded in the case (`form_a`, `form_b`, `form_c`, the Python field names) and
/// the Gram Sabha's member sheet (`gs_member`); a form with missing parts gives "Not stated" /
/// empty lists rather than an error.
class DemoTitle {
  DemoTitle._();

  static const List<String> signatories = [
    'Tribal Welfare Divisional Officer (TWDO)',
    'Forest Divisional Officer (FDO)',
    'Deputy Collector',
  ];

  static const String note =
      'Title draft prepared with VanMitra for printing and signature. The signed paper is the '
      'title; this draft is not a government document until signed.';

  /// Form A "Nature of claim on land": code -> (label, section) (domain/form_a.py).
  static const Map<String, (String, String)> claimSpecs = {
    'habitation': ('Extent of forest land occupied: for habitation', 'Section 3(1)(a)'),
    'self_cultivation': (
      'Extent of forest land occupied: for self-cultivation, if any',
      'Section 3(1)(a)',
    ),
    'disputed_land': ('Disputed lands, if any', 'Section 3(1)(f)'),
    'patta_lease_grant': ('Pattas / leases / grants, if any', 'Section 3(1)(g)'),
    'in_situ_rehabilitation': (
      'Land for in situ rehabilitation or alternative land, if any',
      'Section 3(1)(m)',
    ),
    'displaced_without_compensation': (
      'Land from where displaced without land compensation',
      'Section 4(8)',
    ),
    'forest_village': ('Extent of land in forest villages, if any', 'Section 3(1)(h)'),
    'other_traditional': ('Any other traditional right, if any', 'Section 3(1)(l)'),
  };

  /// Form B "Nature of community rights enjoyed": code -> (label, section) (domain/form_b.py).
  static const Map<String, (String, String)> rightSpecs = {
    'nistar': ('Community rights such as nistar, if any', 'Section 3(1)(b)'),
    'minor_forest_produce': ('Rights over minor forest produce, if any', 'Section 3(1)(c)'),
    'water_bodies': (
      'Community rights: uses or entitlements (fish, water bodies), if any',
      'Section 3(1)(d)',
    ),
    'grazing': ('Community rights: grazing, if any', 'Section 3(1)(d)'),
    'nomadic_pastoral_access': (
      'Community rights: traditional resource access for nomadic and pastoralist, if any',
      'Section 3(1)(d)',
    ),
    'habitat': (
      'Community tenures of habitat and habitation for PTGs and pre-agricultural communities, if any',
      'Section 3(1)(e)',
    ),
    'biodiversity_knowledge': (
      'Right to access biodiversity, intellectual property and traditional knowledge, if any',
      'Section 3(1)(k)',
    ),
    'other_traditional': ('Other traditional right, if any', 'Section 3(1)(l)'),
  };

  static String _community(bool st, bool otfd) {
    if (st && otfd) return 'Scheduled Tribe and Other Traditional Forest Dweller';
    if (st) return 'Scheduled Tribe';
    if (otfd) return 'Other Traditional Forest Dweller';
    return 'Not stated';
  }

  static double? _num(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

  static List<Map<String, dynamic>> _maps(Object? v) =>
      ((v as List?) ?? const []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();

  static List<dynamic> _strings(Object? v) => List<dynamic>.from((v as List?) ?? const []);

  static bool _text(Object? v) => v is String && v.isNotEmpty;

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  /// The backend's `TitleDraftOut` for a case the caller may see.
  static Map<String, dynamic> build(DemoDb db, CaseCtx ctx) {
    final c = ctx.theCase;
    final village = ctx.village;
    final stateName = (village['state'] as String?)?.isNotEmpty == true ? village['state'] : 'Maharashtra';
    final signed = [
      for (final label in signatories) {'designation': label, 'role': null, 'name': null, 'signed_at': null},
    ];
    final issued = c['state'] == CaseStates.titleIssued;
    final status = issued ? 'issued' : 'draft (to be signed by the district committee)';
    final place = {
      'village_gram_sabha': '${village['name_mr']} (${village['name_en']})',
      'gram_panchayat': village['gram_panchayat'],
      'tehsil_taluka': village['taluka'],
      'district': village['district'],
    };

    if (c['claim_type'] == ClaimTypes.ifr) {
      final form = (c['form_a'] as Map?)?.cast<String, dynamic>() ?? {};
      final claims = _maps(form['claims']);
      var total = 0.0;
      for (final cl in claims) {
        total += _num(cl['extent_ha']) ?? 0;
      }
      final spouse = form['spouse_name'];
      final holders = [..._strings(form['claimant_names']), if (_text(spouse)) spouse];
      final members = _maps(form['family_members'])
        ..sort((a, b) => ((a['seq'] as num?) ?? 0).compareTo((b['seq'] as num?) ?? 0));
      return {
        'case_id': c['id'],
        'annexure': 'Annexure II [Rule 8(h)]',
        'title': 'Title for forest land under occupation',
        'status': status,
        'fields': <String, dynamic>{
          '1_holders_including_spouse': holders,
          '2_father_mother': form['father_mother_name'],
          '3_dependents': [
            for (final m in members) '${m['name']}${m['age'] != null ? ' (${m['age']})' : ''}',
          ],
          '4_address': form['address'],
          '5_village_gram_sabha': place['village_gram_sabha'],
          '6_gram_panchayat': place['gram_panchayat'],
          '7_tehsil_taluka': place['tehsil_taluka'],
          '8_district': place['district'],
          '9_st_or_otfd': _community(form['is_scheduled_tribe'] == true, form['is_otfd'] == true),
          '10_area_ha': _round2(total),
          '11_boundaries': [
            for (final cl in claims) '${claimSpecs[cl['claim_code']]?.$1 ?? cl['claim_code']}: ${cl['details']}',
          ],
        },
        'declaration':
            'This title is heritable, but not alienable or transferable under sub-section (4) of '
                'Section 4 of the Act. We, the undersigned, hereby, for and on behalf of the '
                'Government of $stateName affix our signatures to confirm the above forest right.',
        'signatories': signed,
        'note': note,
      };
    }

    if (c['claim_type'] == ClaimTypes.cr) {
      final form = (c['form_b'] as Map?)?.cast<String, dynamic>() ?? {};
      final rights = _maps(form['rights']);
      final boundaries = [
        for (final r in rights)
          if (_strings(r['survey_compartment_numbers']).isNotEmpty ||
              r['total_area_ha'] != null ||
              _text(r['boundary_east']) ||
              _text(r['boundary_west']) ||
              _text(r['boundary_north']) ||
              _text(r['boundary_south']))
            {
              'right': rightSpecs[r['right_code']]?.$1 ?? r['right_code'],
              'survey_compartment_numbers': _strings(r['survey_compartment_numbers']),
              'area_ha': _num(r['total_area_ha']),
              'east': r['boundary_east'],
              'west': r['boundary_west'],
              'north': r['boundary_north'],
              'south': r['boundary_south'],
            },
      ];
      return {
        'case_id': c['id'],
        'annexure': 'Annexure III [Rule 8(h)]',
        'title': 'Title to community forest rights',
        'status': status,
        'fields': <String, dynamic>{
          '1_holders': _strings(form['claimant_names']),
          '2_village_gram_sabha': place['village_gram_sabha'],
          '3_gram_panchayat': place['gram_panchayat'],
          '4_tehsil_taluka': place['tehsil_taluka'],
          '5_district': place['district'],
          '6_st_or_otfd': _community(form['is_fdst_community'] == true, form['is_otfd_community'] == true),
          '7_nature_of_community_rights': [
            for (final r in rights)
              '${rightSpecs[r['right_code']]?.$1 ?? r['right_code']} '
                  '[${rightSpecs[r['right_code']]?.$2 ?? ''}]: ${r['details']}',
          ],
          '8_conditions': 'None beyond those in the Act and the Rules',
          '9_boundaries': boundaries.isNotEmpty
              ? boundaries
              : 'As described in the claim and the Gram Sabha resolution',
        },
        'declaration':
            'We, the undersigned, hereby, for and on behalf of the Government of $stateName affix '
                'our signatures to confirm the forest right as mentioned in the Title to the above '
                'mentioned holders of community forest rights.',
        'signatories': signed,
        'note': note,
      };
    }

    final form = (c['form_c'] as Map?)?.cast<String, dynamic>() ?? {};
    final members = db.where(
      'gs_member',
      (m) => m['gram_sabha_id'] == c['gram_sabha_id'] && m['active'] != false,
    );
    final st = members.where((m) => m['category'] == 'st').length;
    final otfd = members.where((m) => m['category'] == 'otfd').length;
    final landmarks = _maps(form['landmarks'])
      ..sort((a, b) => ((a['seq'] as num?) ?? 0).compareTo((b['seq'] as num?) ?? 0));
    final bySide = <String, List<dynamic>>{};
    for (final lm in landmarks) {
      bySide.putIfAbsent('${lm['side']}', () => []).add(lm['name']);
    }
    return {
      'case_id': c['id'],
      'annexure': 'Annexure IV [Rule 8(i)]',
      'title': 'Title to Community Forest Resources',
      'status': status,
      'fields': <String, dynamic>{
        '1_village_gram_sabha': place['village_gram_sabha'],
        '2_gram_panchayat': place['gram_panchayat'],
        '3_tehsil_taluka': place['tehsil_taluka'],
        '4_district': place['district'],
        '5_st_otfd_or_both': _community(st > 0, otfd > 0),
        '6_boundary_description': {
          'customary_boundary': form['area_description'],
          'prominent_landmarks': {
            for (final side in const ['east', 'west', 'north', 'south', 'within']) side: bySide[side] ?? <dynamic>[],
          },
          'khasra_compartment_numbers': _strings(form['khasra_compartment_numbers']),
        },
      },
      'declaration':
          'We, the undersigned, hereby, for and on behalf of the Government affix our signatures '
              'to confirm the community forest resource. The title is held by the Gram Sabha; no '
              'conditions are imposed beyond those in the Act and the Rules.',
      'signatories': signed,
      'note': note,
    };
  }

  static void register(DemoRouter r) {
    // Annexure II / III / IV draft, available once the case reaches the district.
    r.get('/cases/{case_id}/title-draft', (req) {
      final db = req.db;
      final ctx = DemoCases.load(db, req.who, req.params['case_id']!);
      if (ctx.state != CaseStates.districtReview && ctx.state != CaseStates.titleIssued) {
        throw DemoError(409, 'TITLE_NOT_AVAILABLE', 'title.not_available', details: {'state': ctx.state});
      }
      return build(db, ctx);
    });
  }
}
