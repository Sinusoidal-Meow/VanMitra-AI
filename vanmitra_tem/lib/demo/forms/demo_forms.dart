import 'dart:convert';

import '../core/demo_cases.dart';
import '../core/demo_core.dart';
import 'demo_form_input.dart';
import 'demo_form_rules.dart';

/// Forms A, B and C: the form pages, saving a draft, completeness and the field vocabularies.
/// Ported from the backend (api/v1/form_a.py, form_b.py, form_c.py, _shared.py).
///
/// A form lives inside its case row (table `claim_case`) as the map `form_a`, `form_b` or `form_c`
/// with the backend model's field names; the evidence list of the form is `evidence_entries` on
/// the case row (`{id, seq, rule_ref, description, created_at}`). Rows of the form:
///
///  * form_a: claimant_names, spouse_name, father_mother_name, address, is_scheduled_tribe,
///    is_otfd, spouse_is_scheduled_tribe, other_information, updated_by_user_id,
///    family_members `[{id, seq, name, age, relation}]`, claims `[{id, claim_code, extent_ha,
///    details}]`, created_at, updated_at.
///  * form_b: claimant_names, is_fdst_community, is_otfd_community, other_information,
///    updated_by_user_id, rights `[{id, right_code, details, items, survey_compartment_numbers,
///    total_area_ha, common_use_area_ha, boundary_east/west/north/south, annual_quantity}]`.
///  * form_c: resolution_statement, area_description, approx_area_ha, pastoral_seasonal_use,
///    seasonal_use_details, khasra_compartment_numbers, updated_by_user_id, landmarks `[{id, seq,
///    side, kind, name, description}]`, bordering_villages `[{id, seq, name, shares_resources,
///    sharing_details}]`.
///
/// Items 5-8 (village, panchayat, taluka, district) are read from the village, and the Form C
/// member sheet from the Gram Sabha's `gs_member` rows.
class DemoForms {
  DemoForms._();

  static const String _formAKey = 'form_a';
  static const String _formBKey = 'form_b';
  static const String _formCKey = 'form_c';

  // ── the empty form a new case starts with (api/v1/cases.py create_case) ────────

  static Map<String, dynamic> newForm(String claimType, String userId) {
    switch (claimType) {
      case ClaimTypes.ifr:
        return {
          'claimant_names': <dynamic>[],
          'spouse_name': null,
          'father_mother_name': null,
          'address': null,
          'is_scheduled_tribe': null,
          'is_otfd': null,
          'spouse_is_scheduled_tribe': null,
          'other_information': null,
          'updated_by_user_id': userId,
          'family_members': <dynamic>[],
          'claims': <dynamic>[],
        };
      case ClaimTypes.cr:
        return {
          'claimant_names': <dynamic>[],
          'is_fdst_community': null,
          'is_otfd_community': null,
          'other_information': null,
          'updated_by_user_id': userId,
          'rights': <dynamic>[],
        };
      default:
        return {
          'resolution_statement': defaultResolutionStatement,
          'area_description': null,
          'approx_area_ha': null,
          'pastoral_seasonal_use': false,
          'seasonal_use_details': null,
          'khasra_compartment_numbers': <dynamic>[],
          'updated_by_user_id': userId,
          'landmarks': <dynamic>[],
          'bordering_villages': <dynamic>[],
        };
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _rows(Object? raw) =>
      raw is List ? raw.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];

  static List<String> _strings(Object? raw) => raw is List ? raw.cast<String>() : <String>[];

  /// The form map of the case (made when a case row has none), with its two timestamps.
  static Map<String, dynamic> _formOf(CaseCtx ctx, String key, String claimType) {
    final c = ctx.theCase;
    final existing = c[key];
    final Map<String, dynamic> form;
    if (existing is Map<String, dynamic>) {
      form = existing;
    } else {
      form = newForm(claimType, '${c['created_by_user_id']}');
      c[key] = form;
    }
    form.putIfAbsent('created_at', () => c['created_at']);
    form.putIfAbsent('updated_at', () => form['created_at']);
    return form;
  }

  static double _round2(double x) => double.parse(x.toStringAsFixed(2));

  static double? _dec(Object? x) => x == null ? null : _round2((x as num).toDouble());

  static double? _asDouble(Object? x) => x == null ? null : (x as num).toDouble();

  static List<Map<String, dynamic>> _bySeq(Object? raw) =>
      _rows(raw).toList()..sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));

  static List<Map<String, dynamic>> _evidenceOf(Map<String, dynamic> theCase) =>
      _bySeq(theCase['evidence_entries']);

  static List<Map<String, dynamic>> _evidenceOut(List<Map<String, dynamic>> evidence) => [
        for (final e in evidence)
          {'seq': e['seq'], 'rule_ref': e['rule_ref'], 'description': e['description']},
      ];

  static List<String> _evidenceRules(List<Map<String, dynamic>> evidence) =>
      [for (final e in evidence) e['rule_ref'] as String];

  static void _setEvidence(DemoDb db, Map<String, dynamic> theCase, List<Map<String, dynamic>> given) {
    final now = db.nowIso();
    theCase['evidence_entries'] = [
      for (var i = 0; i < given.length; i++)
        {
          'id': db.newId(),
          'seq': i + 1,
          'rule_ref': given[i]['rule_ref'],
          'description': given[i]['description'],
          'created_at': now,
        },
    ];
  }

  static List<String?> _villageFields(Map<String, dynamic> v) => [
        v['name_mr'] as String?,
        v['gram_panchayat'] as String?,
        v['taluka'] as String?,
        v['district'] as String?,
      ];

  /// `village_header` of api/v1/_shared.py.
  static Map<String, dynamic> _header(Map<String, dynamic> v) => {
        'village_id': v['id'],
        'village_name_mr': v['name_mr'],
        'village_name_en': v['name_en'],
        'gram_panchayat': v['gram_panchayat'],
        'taluka': v['taluka'],
        'district': v['district'],
      };

  /// The case if the caller may see it, on the right kind of form. The path id is checked first,
  /// as the real server does.
  static CaseCtx _open(DemoRequest req, String claimType, String wrongFormError) {
    final id = parseUuidPath('case_id', req.params['case_id']!);
    final ctx = DemoCases.load(req.db, req.who, id);
    DemoCases.ensureClaimType(ctx, claimType, wrongFormError);
    return ctx;
  }

  /// A saved change moves the case's own `updated_at`.
  static String _snapshot(Map<String, dynamic> theCase, String formKey) =>
      jsonEncode([theCase[formKey], theCase['evidence_entries'] ?? const <dynamic>[]]);

  // ── Form A ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> formAOut(CaseCtx ctx) {
    final c = ctx.theCase;
    final form = _formOf(ctx, _formAKey, ClaimTypes.ifr);
    final claimedRows = _rows(form['claims']);
    final claimed = {for (final cl in claimedRows) cl['claim_code'] as String: cl};
    final evidence = _evidenceOf(c);
    final total = _round2(
        claimedRows.fold<double>(0, (sum, cl) => sum + ((cl['extent_ha'] as num?)?.toDouble() ?? 0)));
    final claimantNames = _strings(form['claimant_names']);
    final completeness = formACompleteness(
      villageFields: _villageFields(ctx.village),
      claimantNames: claimantNames,
      address: form['address'] as String?,
      isScheduledTribe: form['is_scheduled_tribe'] as bool?,
      isOtfd: form['is_otfd'] as bool?,
      claimed: claimed.keys,
      evidenceRulesGiven: _evidenceRules(evidence),
    );
    return {
      'case_id': c['id'],
      'state': c['state'],
      'editable': ctx.editable,
      'header': _header(ctx.village),
      'claimant_names': List<String>.of(claimantNames),
      'spouse_name': form['spouse_name'],
      'father_mother_name': form['father_mother_name'],
      'address': form['address'],
      'is_scheduled_tribe': form['is_scheduled_tribe'],
      'is_otfd': form['is_otfd'],
      'spouse_is_scheduled_tribe': form['spouse_is_scheduled_tribe'],
      'family_members': [
        for (final m in _bySeq(form['family_members']))
          {'seq': m['seq'], 'name': m['name'], 'age': m['age'], 'relation': m['relation']},
      ],
      'claims': [
        for (final spec in formAClaims)
          {
            'code': spec.code,
            'form_item': spec.formItem,
            'label_en': spec.labelEn,
            'section': spec.section,
            'claimed': claimed.containsKey(spec.code),
            'extent_ha': claimed.containsKey(spec.code) ? _asDouble(claimed[spec.code]!['extent_ha']) : null,
            'details': claimed.containsKey(spec.code) ? claimed[spec.code]!['details'] : null,
          },
      ],
      'total_extent_ha': total,
      'extent_note': total > maxRecognisableHa
          ? 'Recognition is limited to land under actual occupation and cannot exceed '
              '4 ha [Section 4(6)].'
          : null,
      'evidence': _evidenceOut(evidence),
      'other_information': form['other_information'],
      'completeness': completeness.toJson(),
      'updated_at': form['updated_at'],
    };
  }

  static Map<String, dynamic> _putFormA(DemoRequest req) {
    final p = req.who;
    final id = parseUuidPath('case_id', req.params['case_id']!);
    final body = parseFormAInput(req.body);
    final db = req.db;
    final ctx = DemoCases.load(db, p, id);
    DemoCases.ensureClaimType(ctx, ClaimTypes.ifr, 'NOT_A_FORM_A_CASE');
    DemoCases.ensureEditable(ctx);
    final c = ctx.theCase;
    final form = _formOf(ctx, _formAKey, ClaimTypes.ifr);
    final before = _snapshot(c, _formAKey);

    form['claimant_names'] = List<String>.of(body['claimant_names'] as List<String>);
    form['spouse_name'] = body['spouse_name'];
    form['father_mother_name'] = body['father_mother_name'];
    form['address'] = body['address'];
    form['is_scheduled_tribe'] = body['is_scheduled_tribe'];
    form['is_otfd'] = body['is_otfd'];
    form['spouse_is_scheduled_tribe'] = body['spouse_is_scheduled_tribe'];
    form['other_information'] = body['other_information'];
    form['updated_by_user_id'] = p.userId;

    final members = body['family_members'] as List<Map<String, dynamic>>;
    form['family_members'] = [
      for (var i = 0; i < members.length; i++)
        {
          'id': db.newId(),
          'seq': i + 1,
          'name': members[i]['name'],
          'age': members[i]['age'],
          'relation': members[i]['relation'],
        },
    ];
    final claims = (body['claims'] as Map<String, Map<String, dynamic>>).entries.toList()
      ..sort((a, b) => formAClaimOrder[a.key]!.compareTo(formAClaimOrder[b.key]!));
    form['claims'] = [
      for (final e in claims)
        {
          'id': db.newId(),
          'claim_code': e.key,
          'extent_ha': _dec(e.value['extent_ha']),
          'details': e.value['details'],
        },
    ];
    _setEvidence(db, c, body['evidence'] as List<Map<String, dynamic>>);
    if (_snapshot(c, _formAKey) != before) db.touch(c);
    return formAOut(ctx);
  }

  // ── Form B ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _rightOut(RightSpec spec, Map<String, dynamic>? row) {
    if (row == null) {
      return {
        'code': spec.code,
        'form_item': spec.formItem,
        'label_en': spec.labelEn,
        'section': spec.section,
        'claimed': false,
        'details': null,
        'items': <String>[],
        'survey_compartment_numbers': <String>[],
        'total_area_ha': null,
        'common_use_area_ha': null,
        'boundaries': null,
        'annual_quantity': null,
      };
    }
    final sides = [
      row['boundary_east'],
      row['boundary_west'],
      row['boundary_north'],
      row['boundary_south'],
    ];
    return {
      'code': spec.code,
      'form_item': spec.formItem,
      'label_en': spec.labelEn,
      'section': spec.section,
      'claimed': true,
      'details': row['details'],
      'items': List<String>.of(_strings(row['items'])),
      'survey_compartment_numbers': List<String>.of(_strings(row['survey_compartment_numbers'])),
      'total_area_ha': _asDouble(row['total_area_ha']),
      'common_use_area_ha': _asDouble(row['common_use_area_ha']),
      'boundaries': sides.any((s) => s != null && '$s'.isNotEmpty)
          ? {
              'east': row['boundary_east'],
              'west': row['boundary_west'],
              'north': row['boundary_north'],
              'south': row['boundary_south'],
            }
          : null,
      'annual_quantity': row['annual_quantity'],
    };
  }

  static Map<String, dynamic> formBOut(CaseCtx ctx) {
    final c = ctx.theCase;
    final form = _formOf(ctx, _formBKey, ClaimTypes.cr);
    final claimed = {for (final r in _rows(form['rights'])) r['right_code'] as String: r};
    final evidence = _evidenceOf(c);
    final claimantNames = _strings(form['claimant_names']);
    final completeness = formBCompleteness(
      villageFields: _villageFields(ctx.village),
      claimantNames: claimantNames,
      isFdstCommunity: form['is_fdst_community'] as bool?,
      isOtfdCommunity: form['is_otfd_community'] as bool?,
      claimedRights: claimed.keys,
      evidenceRulesGiven: _evidenceRules(evidence),
    );
    return {
      'case_id': c['id'],
      'state': c['state'],
      'editable': ctx.editable,
      'header': _header(ctx.village),
      'claimant_names': List<String>.of(claimantNames),
      'is_fdst_community': form['is_fdst_community'],
      'is_otfd_community': form['is_otfd_community'],
      'rights': [for (final spec in formBRights) _rightOut(spec, claimed[spec.code])],
      'evidence': _evidenceOut(evidence),
      'other_information': form['other_information'],
      'completeness': completeness.toJson(),
      'updated_at': form['updated_at'],
    };
  }

  static Map<String, dynamic> _putFormB(DemoRequest req) {
    final p = req.who;
    final id = parseUuidPath('case_id', req.params['case_id']!);
    final body = parseFormBInput(req.body);
    final db = req.db;
    final ctx = DemoCases.load(db, p, id);
    DemoCases.ensureClaimType(ctx, ClaimTypes.cr, 'NOT_A_FORM_B_CASE');
    DemoCases.ensureEditable(ctx);
    final c = ctx.theCase;
    final form = _formOf(ctx, _formBKey, ClaimTypes.cr);
    final before = _snapshot(c, _formBKey);

    form['claimant_names'] = List<String>.of(body['claimant_names'] as List<String>);
    form['is_fdst_community'] = body['is_fdst_community'];
    form['is_otfd_community'] = body['is_otfd_community'];
    form['other_information'] = body['other_information'];
    form['updated_by_user_id'] = p.userId;

    final rights = (body['rights'] as Map<String, Map<String, dynamic>>).entries.toList()
      ..sort((a, b) => formBRightOrder[a.key]!.compareTo(formBRightOrder[b.key]!));
    form['rights'] = [
      for (final e in rights)
        {
          'id': db.newId(),
          'right_code': e.key,
          'details': e.value['details'],
          'items': List<String>.of(e.value['items'] as List<String>),
          // duplicates dropped, first one kept (dict.fromkeys)
          'survey_compartment_numbers':
              (e.value['survey_compartment_numbers'] as List<String>).toSet().toList(),
          'total_area_ha': _dec(e.value['total_area_ha']),
          'common_use_area_ha': _dec(e.value['common_use_area_ha']),
          'boundary_east': (e.value['boundaries'] as Map?)?['east'],
          'boundary_west': (e.value['boundaries'] as Map?)?['west'],
          'boundary_north': (e.value['boundaries'] as Map?)?['north'],
          'boundary_south': (e.value['boundaries'] as Map?)?['south'],
          'annual_quantity': e.value['annual_quantity'],
        },
    ];
    _setEvidence(db, c, body['evidence'] as List<Map<String, dynamic>>);
    if (_snapshot(c, _formBKey) != before) db.touch(c);
    return formBOut(ctx);
  }

  // ── Form C ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> formCOut(DemoDb db, CaseCtx ctx) {
    final c = ctx.theCase;
    final form = _formOf(ctx, _formCKey, ClaimTypes.cfr);
    final members = db
        .where('gs_member', (m) => m['gram_sabha_id'] == c['gram_sabha_id'] && m['active'] == true)
        .toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    final counts = memberSheetCounts([for (final m in members) m['category'] as String]);
    final evidence = _evidenceOf(c);
    final landmarks = _bySeq(form['landmarks']);
    final bordering = _bySeq(form['bordering_villages']);
    final completeness = formCCompleteness(
      villageFields: _villageFields(ctx.village),
      members: counts,
      resolutionStatement: form['resolution_statement'] as String?,
      areaDescription: form['area_description'] as String?,
      landmarkSides: [for (final lm in landmarks) lm['side'] as String],
      borderingVillageCount: bordering.length,
      evidenceRulesGiven: _evidenceRules(evidence),
    );
    return {
      'case_id': c['id'],
      'state': c['state'],
      'editable': ctx.editable,
      'header': _header(ctx.village),
      'member_sheet': {
        'total': counts.total,
        'st': counts.st,
        'otfd': counts.otfd,
        'members': [
          for (final m in members) {'name': m['name'], 'category': m['category']},
        ],
      },
      'resolution_statement': form['resolution_statement'],
      'area_description': form['area_description'],
      'approx_area_ha': _asDouble(form['approx_area_ha']),
      'pastoral_seasonal_use': form['pastoral_seasonal_use'] ?? false,
      'seasonal_use_details': form['seasonal_use_details'],
      'landmarks': [
        for (final lm in landmarks)
          {
            'seq': lm['seq'],
            'side': lm['side'],
            'kind': lm['kind'],
            'name': lm['name'],
            'description': lm['description'],
          },
      ],
      'khasra_compartment_numbers': List<String>.of(_strings(form['khasra_compartment_numbers'])),
      'bordering_villages': [
        for (final b in bordering)
          {
            'seq': b['seq'],
            'name': b['name'],
            'shares_resources': b['shares_resources'] ?? false,
            'sharing_details': b['sharing_details'],
          },
      ],
      'evidence': _evidenceOut(evidence),
      'completeness': completeness.toJson(),
      'updated_at': form['updated_at'],
    };
  }

  static Map<String, dynamic> _putFormC(DemoRequest req) {
    final p = req.who;
    final id = parseUuidPath('case_id', req.params['case_id']!);
    final body = parseFormCInput(req.body);
    final db = req.db;
    final ctx = DemoCases.load(db, p, id);
    DemoCases.ensureClaimType(ctx, ClaimTypes.cfr, 'NOT_A_FORM_C_CASE');
    DemoCases.ensureEditable(ctx);
    final c = ctx.theCase;
    final form = _formOf(ctx, _formCKey, ClaimTypes.cfr);
    final before = _snapshot(c, _formCKey);

    // `resolution_statement or DEFAULT`: left out keeps the printed statement
    form['resolution_statement'] = body['resolution_statement'] ?? defaultResolutionStatement;
    form['area_description'] = body['area_description'];
    form['approx_area_ha'] = _dec(body['approx_area_ha']);
    form['pastoral_seasonal_use'] = body['pastoral_seasonal_use'];
    form['seasonal_use_details'] = body['seasonal_use_details'];
    form['khasra_compartment_numbers'] =
        (body['khasra_compartment_numbers'] as List<String>).toSet().toList();
    form['updated_by_user_id'] = p.userId;

    final landmarks = body['landmarks'] as List<Map<String, dynamic>>;
    form['landmarks'] = [
      for (var i = 0; i < landmarks.length; i++)
        {
          'id': db.newId(),
          'seq': i + 1,
          'side': landmarks[i]['side'],
          'kind': landmarks[i]['kind'],
          'name': landmarks[i]['name'],
          'description': landmarks[i]['description'],
        },
    ];
    final bordering = body['bordering_villages'] as List<Map<String, dynamic>>;
    form['bordering_villages'] = [
      for (var i = 0; i < bordering.length; i++)
        {
          'id': db.newId(),
          'seq': i + 1,
          'name': bordering[i]['name'],
          'shares_resources': bordering[i]['shares_resources'],
          'sharing_details': bordering[i]['sharing_details'],
        },
    ];
    _setEvidence(db, c, body['evidence'] as List<Map<String, dynamic>>);
    if (_snapshot(c, _formCKey) != before) db.touch(c);
    return formCOut(db, ctx);
  }

  // ── routes ─────────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    DemoHooks.newForm = newForm;

    // Form B's rights with their provisions, and the Rule 13 evidence tags
    r.get('/forms/form-b/fields', (req) {
      req.who;
      return {
        'form': 'Form B: Claim Form for Community Rights',
        'rule': 'Rule 11(1)(a) and (4)',
        'rights': [
          for (final s in formBRights)
            {
              'code': s.code,
              'form_item': s.formItem,
              'label_en': s.labelEn,
              'section': s.section,
            },
        ],
        'evidence_rules': List<String>.of(evidenceRules),
        'min_evidence_items': minEvidenceItems,
      };
    });

    // Form C vocabularies: boundary sides, landmark kinds, Rule 13 tags, default statement
    r.get('/forms/form-c/fields', (req) {
      req.who;
      return {
        'form': 'Form C: Claim Form for Rights to Community Forest Resource',
        'rule': 'Section 3(1)(i); Rule 11(1) and (4)',
        'default_resolution_statement': defaultResolutionStatement,
        'boundary_sides': List<String>.of(boundarySides),
        'landmark_kinds': List<String>.of(landmarkKinds),
        'evidence_rules': List<String>.of(evidenceRules),
        'min_general_evidence': minGeneralEvidence,
        'min_cfr_evidence': minCfrEvidence,
      };
    });

    r.get('/cases/{case_id}/form-a', (req) {
      req.who;
      return formAOut(_open(req, ClaimTypes.ifr, 'NOT_A_FORM_A_CASE'));
    });
    r.put('/cases/{case_id}/form-a', _putFormA);

    r.get('/cases/{case_id}/form-b', (req) {
      req.who;
      return formBOut(_open(req, ClaimTypes.cr, 'NOT_A_FORM_B_CASE'));
    });
    r.put('/cases/{case_id}/form-b', _putFormB);

    r.get('/cases/{case_id}/form-c', (req) {
      req.who;
      return formCOut(req.db, _open(req, ClaimTypes.cfr, 'NOT_A_FORM_C_CASE'));
    });
    r.put('/cases/{case_id}/form-c', _putFormC);
  }
}
